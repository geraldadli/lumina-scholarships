/**
 * Uji Firestore Security Rules (../firestore.rules) di Firestore Emulator.
 * Jalankan: `npm run test:rules` (butuh Java 11+). Tidak menyentuh project Firebase asli.
 */
import { after, before, beforeEach, describe, test } from 'node:test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, getDocs, collection, setDoc, setLogLevel, updateDoc, Timestamp } from 'firebase/firestore';

// PERMISSION_DENIED memang diharapkan pada kasus assertFails; jangan penuhi log.
setLogLevel('silent');

let env: RulesTestEnvironment;

const ALICE = 'alice';
const BOB = 'bob';
const SCHOLARSHIP_ID = 'mext-scholarship-2027';

const validProfile = {
  displayName: 'Alice',
  educationLevel: 'masters',
  citizenship: 'ID',
  targetCountries: ['JP', 'DE'],
  fieldsOfStudy: ['Computer Science'],
  gpa: 3.6,
  languageScores: { ielts: 7 },
  privacy: { cloudAiAllowed: true },
  onboardingCompleted: true,
};

const validSaved = {
  scholarshipId: SCHOLARSHIP_ID,
  status: 'saved',
  matchScore: 0.8,
  checklist: [{ id: 'cv', label: 'CV', done: false }],
  notes: '',
  lastSeenUpdatedAt: null,
};

const db = (uid?: string) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-lumina',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    await setDoc(doc(admin, 'scholarships', SCHOLARSHIP_ID), { title: 'MEXT', status: 'active' });
    await setDoc(doc(admin, 'sources', SCHOLARSHIP_ID), { url: 'https://example.org' });
    await setDoc(doc(admin, 'sync_logs', 'run-1'), { status: 'success' });
    await setDoc(doc(admin, 'users', BOB), validProfile);
  });
});

after(async () => {
  await env.cleanup();
});

describe('scholarships (katalog)', () => {
  test('user login boleh membaca', async () => {
    await assertSucceeds(getDoc(doc(db(ALICE), 'scholarships', SCHOLARSHIP_ID)));
    await assertSucceeds(getDocs(collection(db(ALICE), 'scholarships')));
  });
  test('tamu (belum login) tidak boleh membaca', async () => {
    await assertFails(getDoc(doc(db(), 'scholarships', SCHOLARSHIP_ID)));
  });
  test('klien tidak boleh menulis', async () => {
    await assertFails(setDoc(doc(db(ALICE), 'scholarships', 'palsu-2027'), { title: 'x' }));
    await assertFails(updateDoc(doc(db(ALICE), 'scholarships', SCHOLARSHIP_ID), { status: 'closed' }));
    await assertFails(deleteDoc(doc(db(ALICE), 'scholarships', SCHOLARSHIP_ID)));
  });
});

describe('sources & sync_logs (khusus backend)', () => {
  test('tertutup total untuk klien', async () => {
    await assertFails(getDoc(doc(db(ALICE), 'sources', SCHOLARSHIP_ID)));
    await assertFails(getDoc(doc(db(ALICE), 'sync_logs', 'run-1')));
    await assertFails(setDoc(doc(db(ALICE), 'sources', 'x'), { url: 'https://evil' }));
  });
});

describe('users/{uid} (Set preferences)', () => {
  test('pemilik boleh membuat, membaca, mengubah, menghapus profilnya', async () => {
    const ref = doc(db(ALICE), 'users', ALICE);
    await assertSucceeds(setDoc(ref, validProfile));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(updateDoc(ref, { gpa: 3.8 }));
    await assertSucceeds(deleteDoc(ref));
  });
  test('profil minimal (onboarding belum selesai) diterima', async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), 'users', ALICE), { onboardingCompleted: false }));
  });
  test('user lain tidak boleh membaca / menulis', async () => {
    await assertFails(getDoc(doc(db(ALICE), 'users', BOB)));
    await assertFails(updateDoc(doc(db(ALICE), 'users', BOB), { gpa: 1 }));
    await assertFails(getDoc(doc(db(), 'users', BOB)));
  });
  test('data tidak valid ditolak', async () => {
    const ref = doc(db(ALICE), 'users', ALICE);
    await assertFails(setDoc(ref, { ...validProfile, gpa: 5 }));
    await assertFails(setDoc(ref, { ...validProfile, educationLevel: 'bachelor' }));
    await assertFails(setDoc(ref, { ...validProfile, citizenship: 'IDN' }));
    await assertFails(setDoc(ref, { ...validProfile, targetCountries: 'JP' }));
    await assertFails(setDoc(ref, { ...validProfile, fundingPreference: 'gratis' }));
  });
});

describe('users/{uid}/saved_scholarships (Save → Prepare → Apply → Track)', () => {
  const savedRef = (uid: string, owner = uid, id = SCHOLARSHIP_ID) =>
    doc(db(uid), 'users', owner, 'saved_scholarships', id);

  test('pemilik boleh menyimpan beasiswa yang ada', async () => {
    await assertSucceeds(setDoc(savedRef(ALICE), validSaved));
  });
  test('alur status saved → preparing → applied + checklist + lastSeenUpdatedAt', async () => {
    const ref = savedRef(ALICE);
    await assertSucceeds(setDoc(ref, validSaved));
    await assertSucceeds(updateDoc(ref, { status: 'preparing', checklist: [{ id: 'cv', label: 'CV', done: true }] }));
    await assertSucceeds(updateDoc(ref, { status: 'applied', lastSeenUpdatedAt: Timestamp.now() }));
  });
  test('pemilik boleh unsave (hapus)', async () => {
    await assertSucceeds(setDoc(savedRef(ALICE), validSaved));
    await assertSucceeds(deleteDoc(savedRef(ALICE)));
  });
  test('menyimpan beasiswa yang tidak ada ditolak', async () => {
    await assertFails(setDoc(savedRef(ALICE, ALICE, 'tidak-ada-2027'), { ...validSaved, scholarshipId: 'tidak-ada-2027' }));
  });
  test('scholarshipId harus sama dengan ID dokumen', async () => {
    await assertFails(setDoc(savedRef(ALICE), { ...validSaved, scholarshipId: 'lain-2027' }));
  });
  test('nilai tidak valid ditolak', async () => {
    await assertFails(setDoc(savedRef(ALICE), { ...validSaved, status: 'won' }));
    await assertFails(setDoc(savedRef(ALICE), { ...validSaved, matchScore: 1.5 }));
    await assertFails(setDoc(savedRef(ALICE), { ...validSaved, notes: 'x'.repeat(5001) }));
    await assertFails(setDoc(savedRef(ALICE), { ...validSaved, lastSeenUpdatedAt: '2026-11-18' }));
  });
  test('user lain tidak boleh membaca / menulis bookmark orang lain', async () => {
    await assertSucceeds(setDoc(savedRef(ALICE), validSaved));
    await assertFails(getDoc(savedRef(BOB, ALICE)));
    await assertFails(setDoc(savedRef(BOB, ALICE), validSaved));
  });
  test('subkoleksi lama `matches` sudah tidak diizinkan', async () => {
    await assertFails(setDoc(doc(db(ALICE), 'users', ALICE, 'matches', SCHOLARSHIP_ID), { matchScore: 0.9 }));
  });
});
