import { initializeApp, cert, getApps, type ServiceAccount } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import * as fs from 'node:fs';
import * as path from 'node:path';

/**
 * Sumber kredensial Admin SDK (urutan prioritas):
 * 1. env `FIREBASE_SERVICE_ACCOUNT`: isi JSON service account (dipakai GitHub Actions via Secret)
 * 2. file lokal `backend/serviceAccountKey.json` (development, di-.gitignore)
 *
 * Kredensial hanya ada di memori dan TIDAK PERNAH dicetak. Error JSON.parse
 * sengaja tidak diteruskan karena pesan aslinya bisa memuat potongan isi kunci.
 */
function loadServiceAccount(): ServiceAccount {
  const fromEnv = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (fromEnv) {
    try {
      return JSON.parse(fromEnv) as ServiceAccount;
    } catch {
      throw new Error('FIREBASE_SERVICE_ACCOUNT bukan JSON yang valid (isi tidak ditampilkan demi keamanan).');
    }
  }

  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(
      'Kredensial tidak ditemukan. Set env FIREBASE_SERVICE_ACCOUNT atau taruh serviceAccountKey.json di folder backend/.',
    );
  }
  try {
    return JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8')) as ServiceAccount;
  } catch {
    throw new Error('serviceAccountKey.json bukan JSON yang valid (isi tidak ditampilkan demi keamanan).');
  }
}

export function getDb(): Firestore {
  if (getApps().length === 0) {
    initializeApp({ credential: cert(loadServiceAccount()) });
  }
  return getFirestore();
}

/** `--dry-run`: baca & hitung saja, tanpa menulis ke Firestore. */
export const isDryRun = process.argv.includes('--dry-run');
