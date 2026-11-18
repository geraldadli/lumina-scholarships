import { createHash } from 'node:crypto';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { getDb, isDryRun } from './firebase';
import {
  COLLECTIONS,
  VERIFICATION_PENDING,
  type ImportSummary,
  type Requirement,
  type ResearchScholarship,
  type Scholarship,
  type Source,
} from './schema';

/**
 * Importer katalog: backend/data/scholarships.json (format tim Research) → Firestore.
 *
 *   npm run seed                 tulis ke Firestore
 *   npm run seed -- --dry-run    baca Firestore & tampilkan rencana, tanpa menulis
 *   npm run validate:data        validasi JSON saja (tanpa kredensial, dipakai CI)
 *
 * Idempoten: hanya menulis record yang berubah (dibandingkan lewat hash), selalu `merge: true`.
 * `updatedAt` hanya naik jika field yang dilihat user berubah, jadi badge "Ada pembaruan" tidak muncul palsu.
 * Dokumen di Firestore yang tidak ada di JSON TIDAK dihapus, hanya dilaporkan.
 */

export const DATA_PATH = path.join(__dirname, '..', 'data', 'scholarships.json');

const WIB = '+07:00';
const ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const COUNTRY_PATTERN = /^[A-Z]{2}$/;
const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;
const ISO_WITH_TZ = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$/;
const LEVELS = ['undergraduate', 'masters', 'phd'];
/** Field metadata riset: perubahannya tidak dianggap "pembaruan" bagi user. */
const METADATA_KEYS = new Set(['lastVerified', 'verifiedBy', 'notes', 'changeSummary']);

// ───────────────────────── Validasi ─────────────────────────

function parseDate(value: string, endOfDay: boolean): Date | null {
  let d: Date;
  if (DATE_ONLY.test(value)) d = new Date(`${value}T${endOfDay ? '23:59:59' : '00:00:00'}${WIB}`);
  else if (ISO_WITH_TZ.test(value)) d = new Date(value);
  else return null;
  return Number.isNaN(d.getTime()) ? null : d;
}

const isStringArray = (v: unknown): v is string[] => Array.isArray(v) && v.every((x) => typeof x === 'string');
const isNonEmptyString = (v: unknown): v is string => typeof v === 'string' && v.trim().length > 0;

export function validateRecords(raw: unknown, now = new Date()): { errors: string[]; warnings: string[] } {
  const errors: string[] = [];
  const warnings: string[] = [];
  if (!Array.isArray(raw)) return { errors: ['Root JSON harus berupa array.'], warnings };

  const seen = new Set<string>();
  raw.forEach((r: Record<string, unknown>, i) => {
    const at = `[${i}] ${typeof r?.id === 'string' ? r.id : '(tanpa id)'}`;
    const err = (msg: string) => errors.push(`${at}: ${msg}`);

    if (typeof r !== 'object' || r === null) return err('record harus object');
    if (!isNonEmptyString(r.id) || !ID_PATTERN.test(r.id)) err('`id` wajib slug huruf kecil, mis. "mext-scholarship-2027"');
    else if (seen.has(r.id)) err('`id` duplikat');
    else seen.add(r.id);

    for (const key of ['title', 'provider', 'description', 'sourceUrl'] as const) {
      if (!isNonEmptyString(r[key])) err(`\`${key}\` wajib diisi`);
    }
    if (isNonEmptyString(r.sourceUrl) && !/^https:\/\//.test(r.sourceUrl)) err('`sourceUrl` harus https://');
    if (!['full', 'partial'].includes(r.fundingType as string)) err('`fundingType` harus "full" atau "partial"');
    if (!['active', 'closed'].includes(r.status as string)) err('`status` harus "active" atau "closed"');

    if (!isStringArray(r.educationLevels) || r.educationLevels.length === 0) err('`educationLevels` wajib array, min. 1');
    else if (r.educationLevels.some((l) => !LEVELS.includes(l))) err(`\`educationLevels\` hanya boleh ${LEVELS.join('/')}`);

    for (const key of ['eligibleCitizenships', 'hostCountries'] as const) {
      const v = r[key];
      if (!isStringArray(v) || v.length === 0) {
        err(`\`${key}\` wajib array, min. 1`);
        continue;
      }
      for (const c of v) {
        if (c === 'UK') err(`\`${key}\`: pakai "GB" (ISO), bukan "UK"`);
        else if (c !== 'GLOBAL' && !COUNTRY_PATTERN.test(c)) err(`\`${key}\`: "${c}" bukan kode ISO alpha-2 / GLOBAL`);
      }
    }

    if (!isStringArray(r.fieldsOfStudy)) err('`fieldsOfStudy` wajib array (boleh kosong)');
    else if (r.fieldsOfStudy.length === 0) warnings.push(`${at}: fieldsOfStudy kosong → dianggap "belum diumumkan"`);

    if (r.minGpa != null && (typeof r.minGpa !== 'number' || r.minGpa < 0 || r.minGpa > 4)) err('`minGpa` harus angka 0–4 atau null');
    for (const key of ['requirements', 'benefits'] as const) {
      if (r[key] != null && !isStringArray(r[key])) err(`\`${key}\` harus array string`);
    }

    const deadline = typeof r.deadline === 'string' ? parseDate(r.deadline, true) : null;
    if (!deadline) err('`deadline` wajib "YYYY-MM-DD" atau ISO 8601 dengan zona waktu');
    let openDate: Date | null = null;
    if (r.openDate != null) {
      openDate = typeof r.openDate === 'string' ? parseDate(r.openDate, false) : null;
      if (!openDate) err('`openDate` harus "YYYY-MM-DD" atau ISO 8601 dengan zona waktu');
    }
    if (r.lastVerified != null && !(typeof r.lastVerified === 'string' && parseDate(r.lastVerified, false))) {
      err('`lastVerified` harus "YYYY-MM-DD"');
    }
    if (deadline && openDate && openDate > deadline) err('`openDate` lebih lambat dari `deadline`');

    if (deadline && r.status === 'active' && deadline < now) {
      warnings.push(`${at}: status "active" tapi deadline sudah lewat → akan ditutup oleh process-deadlines`);
    }
    if (r.verifiedBy === VERIFICATION_PENDING || r.verifiedBy == null) {
      warnings.push(`${at}: belum diverifikasi manusia (verificationStatus = pending)`);
    }
  });

  return { errors, warnings };
}

export function loadResearchData(): { records: ResearchScholarship[]; warnings: string[] } {
  if (!fs.existsSync(DATA_PATH)) throw new Error(`File data tidak ditemukan: ${DATA_PATH}`);
  let raw: unknown;
  try {
    raw = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));
  } catch (e) {
    throw new Error(`scholarships.json bukan JSON valid: ${e instanceof Error ? e.message : e}`);
  }
  const { errors, warnings } = validateRecords(raw);
  if (errors.length > 0) {
    throw new Error(`Validasi scholarships.json gagal (${errors.length} error):\n  - ${errors.join('\n  - ')}`);
  }
  return { records: raw as ResearchScholarship[], warnings };
}

// ───────────────────────── Transformasi ─────────────────────────

function slugify(label: string): string {
  return (
    label
      .toLowerCase()
      .normalize('NFKD')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 40)
      .replace(/-+$/, '') || 'item'
  );
}

/** Ubah daftar string jadi `{id, label}` dengan id stabil (dari label) dan unik. */
export function toRequirements(labels: string[] = []): Requirement[] {
  const used = new Map<string, number>();
  return labels.map((label) => {
    const base = slugify(label);
    const n = (used.get(base) ?? 0) + 1;
    used.set(base, n);
    return { id: n === 1 ? base : `${base}-${n}`, label: label.trim() };
  });
}

/** JSON stabil (key terurut) supaya hash tidak berubah hanya karena urutan key. */
function stableStringify(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  if (value && typeof value === 'object') {
    const obj = value as Record<string, unknown>;
    return `{${Object.keys(obj)
      .sort()
      .filter((k) => obj[k] !== undefined)
      .map((k) => `${JSON.stringify(k)}:${stableStringify(obj[k])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}

const hashOf = (value: unknown) => createHash('sha256').update(stableStringify(value)).digest('hex');

export function computeHashes(r: ResearchScholarship): { contentHash: string; recordHash: string } {
  const content = Object.fromEntries(Object.entries(r).filter(([k]) => !METADATA_KEYS.has(k)));
  const { changeSummary: _ignored, ...record } = r;
  return { contentHash: hashOf(content), recordHash: hashOf(record) };
}

export function toFirestoreDoc(r: ResearchScholarship): Omit<Scholarship, 'createdAt' | 'updatedAt' | 'lastCheckedAt'> {
  const { contentHash, recordHash } = computeHashes(r);
  const openDate = r.openDate ? parseDate(r.openDate, false) : null;
  const lastVerified = r.lastVerified ? parseDate(r.lastVerified, false) : null;
  return {
    title: r.title.trim(),
    provider: r.provider.trim(),
    description: r.description.trim(),
    fundingType: r.fundingType,
    educationLevels: r.educationLevels,
    eligibleCitizenships: r.eligibleCitizenships,
    hostCountries: r.hostCountries,
    fieldsOfStudy: r.fieldsOfStudy,
    minGpa: r.minGpa ?? null,
    languageRequirement: r.languageRequirement ?? null,
    openDate: openDate ? Timestamp.fromDate(openDate) : null,
    deadline: Timestamp.fromDate(parseDate(r.deadline, true)!),
    status: r.status,
    sourceUrl: r.sourceUrl.trim(),
    requirements: toRequirements(r.requirements),
    benefits: r.benefits ?? [],
    notes: r.notes ?? null,
    verifiedBy: r.verifiedBy ?? null,
    verificationStatus: r.verifiedBy && r.verifiedBy !== VERIFICATION_PENDING ? 'verified' : 'pending',
    lastVerifiedAt: lastVerified ? Timestamp.fromDate(lastVerified) : null,
    contentHash,
    recordHash,
  };
}

// ───────────────────────── Import ─────────────────────────

export async function importScholarships(db: Firestore, opts: { dryRun?: boolean } = {}): Promise<ImportSummary> {
  const { records, warnings } = loadResearchData();
  const summary: ImportSummary = {
    total: records.length,
    created: [],
    contentUpdated: [],
    metadataUpdated: [],
    unchanged: [],
    notInJson: [],
    warnings,
  };

  const scholarshipsCol = db.collection(COLLECTIONS.scholarships);
  const sourcesCol = db.collection(COLLECTIONS.sources);
  const existingSnap = await scholarshipsCol.get();
  const existing = new Map(existingSnap.docs.map((d) => [d.id, d.data() as Scholarship]));
  const sourceSnaps = records.length ? await db.getAll(...records.map((r) => sourcesCol.doc(r.id))) : [];
  const existingSources = new Map(sourceSnaps.map((s) => [s.id, s.exists ? (s.data() as Source) : null]));

  const ids = new Set(records.map((r) => r.id));
  summary.notInJson = [...existing.keys()].filter((id) => !ids.has(id));

  const batch = db.batch();
  let writes = 0;

  for (const r of records) {
    const doc = toFirestoreDoc(r);
    const prev = existing.get(r.id);
    const ref = scholarshipsCol.doc(r.id);

    if (!prev) {
      summary.created.push(r.id);
      batch.set(
        ref,
        {
          ...doc,
          isUrgent: false,
          lastChangeSummary: null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } else if (prev.contentHash !== doc.contentHash) {
      summary.contentUpdated.push(r.id);
      batch.set(
        ref,
        {
          ...doc,
          lastChangeSummary: r.changeSummary?.trim() || 'Informasi beasiswa diperbarui oleh tim Lumina.',
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } else if (prev.recordHash !== doc.recordHash) {
      // Hanya metadata riset (notes/verifikasi) yang berubah: jangan naikkan updatedAt.
      summary.metadataUpdated.push(r.id);
      batch.set(ref, doc, { merge: true });
    } else {
      summary.unchanged.push(r.id);
      continue;
    }
    writes++;

    // Sinkronkan sumber pemantauan. Jika URL berganti, reset hash agar run berikutnya jadi baseline baru.
    const prevSource = existingSources.get(r.id);
    const urlChanged = prevSource != null && prevSource.url !== doc.sourceUrl;
    batch.set(
      sourcesCol.doc(r.id),
      {
        scholarshipId: r.id,
        name: doc.title,
        url: doc.sourceUrl,
        // Data baru sudah direview tim Research → tanda review untuk sumber ini selesai.
        needsReview: false,
        ...(prevSource == null || urlChanged
          ? { lastContentHash: FieldValue.delete(), lastRunStatus: 'seeded', lastRunAt: FieldValue.serverTimestamp() }
          : {}),
      },
      { merge: true },
    );
  }

  if (!opts.dryRun && writes > 0) await batch.commit();
  return summary;
}

// ───────────────────────── CLI ─────────────────────────

if (require.main === module) {
  const validateOnly = process.argv.includes('--validate-only');
  const run = async () => {
    if (validateOnly) {
      const { records, warnings } = loadResearchData();
      console.log(`✔ scholarships.json valid: ${records.length} record.`);
      for (const w of warnings) console.log(`  ⚠ ${w}`);
      return;
    }
    const summary = await importScholarships(getDb(), { dryRun: isDryRun });
    console.log(`${isDryRun ? '[DRY RUN] ' : ''}Import katalog:`, JSON.stringify(summary, null, 2));
    if (summary.notInJson.length) {
      console.log(`ℹ ${summary.notInJson.length} dokumen di Firestore tidak ada di JSON (tidak dihapus).`);
    }
  };
  run()
    .then(() => process.exit(0))
    .catch((err: unknown) => {
      console.error(err instanceof Error ? err.message : err);
      process.exit(1);
    });
}
