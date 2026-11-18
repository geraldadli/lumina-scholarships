import { getDb } from './firebase';
import { COLLECTIONS, type Scholarship, type Source } from './schema';

// Membaca ulang katalog & sumber untuk memastikan data tersimpan sesuai kontrak.
async function verify() {
  const db = getDb();

  const scholarships = await db.collection(COLLECTIONS.scholarships).get();
  console.log(`scholarships: ${scholarships.size} dokumen`);
  for (const doc of scholarships.docs) {
    const s = doc.data() as Scholarship;
    const deadline = s.deadline?.toDate().toISOString().slice(0, 10) ?? '-';
    const source = s.contentHash ? 'json' : 'seed-lama';
    console.log(
      `  - ${doc.id}  [${s.status}${s.isUrgent ? ', urgent' : ''}] deadline=${deadline} ` +
        `verifikasi=${s.verificationStatus ?? '-'} requirements=${s.requirements?.length ?? 0} asal=${source}`,
    );
  }

  const sources = await db.collection(COLLECTIONS.sources).get();
  console.log(`sources: ${sources.size} dokumen`);
  for (const doc of sources.docs) {
    const s = doc.data() as Source;
    console.log(`  - ${doc.id}  [${s.lastRunStatus ?? '-'}${s.needsReview ? ', PERLU REVIEW' : ''}] ${s.url}`);
  }
}

verify()
  .then(() => process.exit(0))
  .catch((err: unknown) => {
    console.error('Gagal verifikasi:', err instanceof Error ? err.message : err);
    process.exit(1);
  });
