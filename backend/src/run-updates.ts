import { FieldValue } from 'firebase-admin/firestore';
import { checkSources } from './check-sources';
import { getDb, isDryRun } from './firebase';
import { processDeadlines } from './process-deadlines';
import { COLLECTIONS, type DeadlineSummary, type ImportSummary, type SourceCheckSummary, type SyncStatus } from './schema';
import { importScholarships } from './seed';

/**
 * Entry point cron GitHub Actions (`npm run sync:scholarships`). Sesuai diagram arsitektur:
 *   1) import   — publish data yang sudah direview (backend/data/scholarships.json) → "Authorized backend publisher"
 *   2) check    — cek perubahan halaman resmi, tandai needsReview          → "Scheduled source checks"
 *   3) deadline — tutup beasiswa yang lewat deadline, set isUrgent
 *   4) log      — satu dokumen ringkasan di `sync_logs`
 * Tiap langkah berdiri sendiri: kegagalan satu langkah tidak menghentikan yang lain.
 * Exit code 1 hanya jika semua langkah gagal.
 */
async function step<T>(name: string, errors: string[], fn: () => Promise<T>): Promise<T | null> {
  try {
    return await fn();
  } catch (err) {
    errors.push(`${name}: ${err instanceof Error ? err.message : String(err)}`);
    return null;
  }
}

async function main(): Promise<SyncStatus> {
  const db = getDb();
  const startedAt = new Date();
  const errors: string[] = [];

  const imported: ImportSummary | null = await step('import', errors, () => importScholarships(db, { dryRun: isDryRun }));
  const sources: SourceCheckSummary | null = await step('check-sources', errors, () => checkSources(db, { dryRun: isDryRun }));
  const deadlines: DeadlineSummary | null = await step('process-deadlines', errors, () =>
    processDeadlines(db, { dryRun: isDryRun }),
  );

  const status: SyncStatus =
    !imported && !sources && !deadlines
      ? 'failed'
      : errors.length > 0 || (sources?.errors ?? 0) > 0
        ? 'partial'
        : 'success';

  const log = {
    startedAt,
    finishedAt: new Date(),
    trigger: process.env.GITHUB_EVENT_NAME ?? 'manual',
    runId: process.env.GITHUB_RUN_ID ?? null,
    commitSha: process.env.GITHUB_SHA ?? null,
    status,
    import: imported,
    sources,
    deadlines,
    changedSourceIds: sources?.changedSourceIds ?? [],
    errors,
  };

  console.log(`${isDryRun ? '[DRY RUN] ' : ''}Hasil run-updates:`, JSON.stringify(log, null, 2));
  if (!isDryRun) {
    await db.collection(COLLECTIONS.syncLogs).add({ ...log, createdAt: FieldValue.serverTimestamp() });
  }

  // Ringkasan untuk halaman run GitHub Actions.
  if (process.env.GITHUB_STEP_SUMMARY) {
    const { appendFileSync } = await import('node:fs');
    appendFileSync(
      process.env.GITHUB_STEP_SUMMARY,
      [
        `### Lumina sync: ${status}${isDryRun ? ' (dry run)' : ''}`,
        `- Import: ${imported ? `${imported.created.length} baru, ${imported.contentUpdated.length} diperbarui, ${imported.unchanged.length} tetap` : 'gagal'}`,
        `- Sumber: ${sources ? `${sources.checked} dicek, ${sources.updated} berubah (perlu review), ${sources.errors} error` : 'gagal'}`,
        `- Deadline: ${deadlines ? `${deadlines.closed.length} ditutup, ${deadlines.urgentOn.length} jadi mendesak` : 'gagal'}`,
        ...(sources?.changedSourceIds.length ? [`- Perlu review: ${sources.changedSourceIds.join(', ')}`] : []),
        ...errors.map((e) => `- ❌ ${e}`),
        '',
      ].join('\n'),
    );
  }
  return status;
}

main()
  .then((status) => process.exit(status === 'failed' ? 1 : 0))
  .catch((err: unknown) => {
    console.error('run-updates gagal:', err instanceof Error ? err.message : err);
    process.exit(1);
  });
