# Lumina Backend

Node.js + TypeScript + `firebase-admin` (modular). Mengelola katalog beasiswa di Firestore, memantau halaman resmi, dan memproses deadline. Kontrak data: [`docs/firestore-contract.md`](../docs/firestore-contract.md).

## Alur data

```
Tim Research ── PR ──▶ backend/data/scholarships.json ── CI: validate:data ──▶ merge ke main
                                                                                   │
GitHub Actions (tiap 6 jam / saat data di-merge) ── npm run sync:scholarships ◀────┘
   1. import          JSON yang sudah direview → scholarships + sources
   2. check-sources   hash SHA-256 halaman resmi → tandai sources.needsReview jika berubah
   3. deadlines       status → closed jika lewat, isUrgent jika ≤ 14 hari
   4. sync_logs       satu dokumen ringkasan per run
```

## Perintah

| Perintah | Fungsi | Butuh kredensial |
|---|---|---|
| `npm run typecheck` | Cek tipe TypeScript | – |
| `npm run validate:data` | Validasi `data/scholarships.json` | – |
| `npm run seed` | Import JSON ke Firestore (`-- --dry-run` untuk simulasi) | ✔ |
| `npm run verify:seed` | Tampilkan isi katalog & status sumber | ✔ |
| `npm run check:sources` | Cek perubahan halaman resmi saja | ✔ |
| `npm run process:deadlines` | Proses deadline saja | ✔ |
| `npm run sync:scholarships` | Jalankan semua langkah (dipakai cron) | ✔ |
| `npm run sync:dry` | Semua langkah tanpa menulis | ✔ |
| `npm run test:rules` | Uji `firestore.rules` di Firestore Emulator (butuh Java 11+) | – |

Index Firestore (`firestore.indexes.json`) dan rules (`firestore.rules`) ada di root repo.

## Kredensial (jangan pernah di-commit, repo ini publik)

Admin SDK membaca, berurutan:
1. env `FIREBASE_SERVICE_ACCOUNT` (isi JSON service account), dipakai GitHub Actions. Disimpan di **Settings → Secrets and variables → Actions → Repository secrets**; workflow sync hanya berjalan dari branch `main`
2. file `backend/serviceAccountKey.json`, untuk development lokal (sudah di `.gitignore`)

Minta service account ke Backend Engineer; jangan kirim lewat grup chat.

## Menambah / mengubah beasiswa (tim Research)

1. Edit `backend/data/scholarships.json` di branch baru (format: kontrak bagian 5).
2. Saat mengubah record yang sudah ada, isi `changeSummary` (1 kalimat) untuk ditampilkan di "Track updates".
3. Buka PR. CI akan memvalidasi; setelah di-merge ke `main`, data otomatis dipublish ke Firestore.
