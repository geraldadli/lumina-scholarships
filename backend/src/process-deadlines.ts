import { FieldValue, Timestamp, type DocumentReference, type Firestore } from 'firebase-admin/firestore';
import { getDb, isDryRun } from './firebase';
import { COLLECTIONS, URGENT_WINDOW_DAYS, type DeadlineSummary, type Scholarship } from './schema';

const DAY_MS = 24 * 60 * 60 * 1000;
const BATCH_LIMIT = 400; // di bawah batas 500 operasi per batch Firestore

function formatDateId(ts: Timestamp): string {
  return ts.toDate().toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'Asia/Jakarta',
  });
}

/**
 * Mengevaluasi deadline semua beasiswa:
 * - status `active` dan deadline sudah lewat → `closed` (+ lastChangeSummary, updatedAt naik → badge "Track updates")
 * - sisa waktu <= 14 hari → isUrgent: true (tanpa menaikkan updatedAt; ini bukan perubahan konten)
 * Beasiswa `closed` tidak pernah dibuka ulang otomatis; itu keputusan Research & Quality Lead.
 */
export async function processDeadlines(
  db: Firestore,
  opts: { now?: Date; dryRun?: boolean } = {},
): Promise<DeadlineSummary> {
  const now = opts.now ?? new Date();
  const summary: DeadlineSummary = { scanned: 0, closed: [], urgentOn: [], urgentOff: [], skippedNoDeadline: [] };
  const updates: { ref: DocumentReference; data: Record<string, unknown> }[] = [];

  const snap = await db.collection(COLLECTIONS.scholarships).get();
  for (const doc of snap.docs) {
    summary.scanned++;
    const s = doc.data() as Scholarship;

    if (!(s.deadline instanceof Timestamp)) {
      summary.skippedNoDeadline.push(doc.id);
      continue;
    }
    if (s.status !== 'active') continue;

    const remainingMs = s.deadline.toMillis() - now.getTime();

    if (remainingMs <= 0) {
      summary.closed.push(doc.id);
      updates.push({
        ref: doc.ref,
        data: {
          status: 'closed',
          isUrgent: false,
          lastChangeSummary: `Pendaftaran ditutup: tenggat ${formatDateId(s.deadline)} telah lewat.`,
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
      continue;
    }

    const shouldBeUrgent = remainingMs <= URGENT_WINDOW_DAYS * DAY_MS;
    if ((s.isUrgent ?? false) !== shouldBeUrgent) {
      (shouldBeUrgent ? summary.urgentOn : summary.urgentOff).push(doc.id);
      updates.push({ ref: doc.ref, data: { isUrgent: shouldBeUrgent } });
    }
  }

  if (!opts.dryRun) {
    for (let i = 0; i < updates.length; i += BATCH_LIMIT) {
      const batch = db.batch();
      for (const u of updates.slice(i, i + BATCH_LIMIT)) batch.update(u.ref, u.data);
      await batch.commit();
    }
  }
  return summary;
}

if (require.main === module) {
  processDeadlines(getDb(), { dryRun: isDryRun })
    .then((summary) => {
      console.log(`${isDryRun ? '[DRY RUN] ' : ''}Deadline diproses:`, JSON.stringify(summary, null, 2));
      process.exit(0);
    })
    .catch((err: unknown) => {
      console.error('Gagal memproses deadline:', err instanceof Error ? err.message : err);
      process.exit(1);
    });
}
