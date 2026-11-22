import { createHash } from 'node:crypto';
import { FieldValue, type Firestore, type QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { getDb, isDryRun } from './firebase';
import { COLLECTIONS, type Source, type SourceCheckSummary, type SourceRunStatus } from './schema';

// Beberapa situs resmi lambat dari IP datacenter (GitHub runner): beri waktu lebih + 1x coba ulang.
const FETCH_TIMEOUT_MS = 45_000;
const FETCH_ATTEMPTS = 2;
const CONCURRENCY = 4;
// Identitas klien generik: tanpa nama/email pribadi.
const USER_AGENT = 'LuminaScholarshipMonitor/1.0 (nonprofit student scholarship app)';

/**
 * Ubah HTML jadi teks stabil supaya hash tidak berubah karena script, style,
 * token CSRF, atau spasi. `ignorePatterns` per sumber membuang teks dinamis lainnya.
 */
export function normalizeHtml(html: string, ignorePatterns: string[] = []): string {
  let text = html
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/<(script|style|noscript|svg|template|iframe)\b[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;|&#160;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'");
  for (const pattern of ignorePatterns) {
    text = text.replace(new RegExp(pattern, 'gi'), ' ');
  }
  return text.replace(/\s+/g, ' ').trim();
}

export function sha256(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

interface CheckResult {
  sourceId: string;
  status: Exclude<SourceRunStatus, 'seeded'>;
  hash?: string;
  httpStatus?: number;
  error?: string;
}

/** Coba ulang hanya untuk error jaringan/timeout dan HTTP 5xx; 4xx dikembalikan apa adanya. */
async function fetchWithRetry(url: string): Promise<Response> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= FETCH_ATTEMPTS; attempt++) {
    try {
      const res = await fetch(url, {
        headers: { 'User-Agent': USER_AGENT, Accept: 'text/html,application/xhtml+xml' },
        redirect: 'follow',
        signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      });
      if (res.status < 500 || attempt === FETCH_ATTEMPTS) return res;
    } catch (err) {
      lastError = err;
      if (attempt === FETCH_ATTEMPTS) throw err;
    }
  }
  throw lastError;
}

async function checkOne(doc: QueryDocumentSnapshot): Promise<CheckResult> {
  const source = doc.data() as Source;
  try {
    const res = await fetchWithRetry(source.url);
    if (!res.ok) {
      return { sourceId: doc.id, status: 'error', httpStatus: res.status, error: `HTTP ${res.status}` };
    }
    const text = normalizeHtml(await res.text(), source.ignorePatterns);
    if (text.length < 50) {
      // Halaman kosong / dirender JS: jangan simpan hash yang tidak bermakna.
      return { sourceId: doc.id, status: 'error', httpStatus: res.status, error: 'Page content is too short' };
    }
    const hash = sha256(text);
    const status = !source.lastContentHash ? 'baseline' : source.lastContentHash === hash ? 'unchanged' : 'updated';
    return { sourceId: doc.id, status, hash, httpStatus: res.status };
  } catch (err) {
    // `fetch failed` terlalu umum; sertakan kode penyebab (ENOTFOUND, ETIMEDOUT, CERT_*, dll).
    const cause = err instanceof Error ? (err.cause as { code?: string } | undefined)?.code : undefined;
    const message = err instanceof Error ? err.message : String(err);
    return { sourceId: doc.id, status: 'error', error: (cause ? `${message} (${cause})` : message).slice(0, 300) };
  }
}

function buildUpdate(result: CheckResult, source: Source): Record<string, unknown> {
  const base = {
    lastRunStatus: result.status,
    lastRunAt: FieldValue.serverTimestamp(),
    lastHttpStatus: result.httpStatus ?? null,
  };
  if (result.status === 'error') {
    return { ...base, lastError: result.error ?? 'unknown', consecutiveErrors: FieldValue.increment(1) };
  }
  const ok = { ...base, lastError: null, consecutiveErrors: 0, lastContentHash: result.hash };
  if (result.status === 'updated') {
    // Hanya menandai untuk direview; isi `scholarships` diubah setelah diverifikasi Research & Quality Lead.
    return {
      ...ok,
      previousContentHash: source.lastContentHash ?? null,
      needsReview: true,
      lastChangedAt: FieldValue.serverTimestamp(),
    };
  }
  return ok;
}

/**
 * Mengecek setiap URL di `sources`, menghitung SHA-256 teks halaman, dan
 * menandai `needsReview` jika berubah. Juga memperbarui `scholarships.lastCheckedAt`
 * (tanpa menaikkan `updatedAt`) sebagai sinyal "terakhir dicek".
 */
export async function checkSources(db: Firestore, opts: { dryRun?: boolean } = {}): Promise<SourceCheckSummary> {
  const snap = await db.collection(COLLECTIONS.sources).get();
  const results: CheckResult[] = [];

  // Batasi paralelisme agar sopan terhadap situs sumber.
  for (let i = 0; i < snap.docs.length; i += CONCURRENCY) {
    results.push(...(await Promise.all(snap.docs.slice(i, i + CONCURRENCY).map(checkOne))));
  }

  const summary: SourceCheckSummary = {
    checked: results.length,
    baseline: 0,
    unchanged: 0,
    updated: 0,
    errors: 0,
    changedSourceIds: [],
    errorDetails: [],
  };

  // Hanya sentuh beasiswa yang benar-benar ada, supaya tidak tercipta dokumen "kosong" di katalog.
  const existingScholarships = new Set(
    (await db.collection(COLLECTIONS.scholarships).select().get()).docs.map((d) => d.id),
  );

  const batch = db.batch();
  for (const [i, result] of results.entries()) {
    const doc = snap.docs[i]!;
    const source = doc.data() as Source;

    if (result.status === 'error') {
      summary.errors++;
      summary.errorDetails.push({ sourceId: result.sourceId, message: result.error ?? 'unknown' });
    } else {
      summary[result.status]++;
      if (result.status === 'updated') summary.changedSourceIds.push(result.sourceId);
    }

    batch.update(doc.ref, buildUpdate(result, source));
    const scholarshipId = source.scholarshipId ?? doc.id;
    if (result.status !== 'error' && existingScholarships.has(scholarshipId)) {
      batch.update(db.collection(COLLECTIONS.scholarships).doc(scholarshipId), {
        lastCheckedAt: FieldValue.serverTimestamp(),
      });
    }
  }
  if (!opts.dryRun && results.length > 0) await batch.commit();

  return summary;
}

if (require.main === module) {
  checkSources(getDb(), { dryRun: isDryRun })
    .then((summary) => {
      console.log(`${isDryRun ? '[DRY RUN] ' : ''}Pengecekan sumber:`, JSON.stringify(summary, null, 2));
      process.exit(0);
    })
    .catch((err: unknown) => {
      console.error('Gagal mengecek sumber:', err instanceof Error ? err.message : err);
      process.exit(1);
    });
}
