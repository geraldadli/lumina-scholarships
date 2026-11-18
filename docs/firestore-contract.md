# Lumina — Kontrak Data Firestore & Remote Config (v1)

> Pemilik: Backend & Data Engineer. Sumber kebenaran untuk tim Flutter, Hybrid AI (Kotlin/Pigeon), dan Research/QA.
> Perubahan nama field / tipe **wajib** lewat backend dulu, karena Security Rules ikut memvalidasi.
> Tipe TypeScript yang setara ada di `backend/src/schema.ts`; aturan aksesnya di `firestore.rules`.

## Konvensi umum

| Hal | Aturan |
|---|---|
| Kode negara | ISO 3166-1 alpha-2, huruf besar: `ID`, `JP`, `KR`, `DE`, `GB`, `US`, `AU`, `SG`, `NL`. Sentinel `GLOBAL` = semua negara. |
| Jenjang (`EducationLevel`) | `undergraduate` \| `masters` \| `phd` |
| Bidang studi | String bebas (judul kapital, mis. `Computer Science`). Sentinel `ALL` = semua bidang. |
| Waktu | Selalu Firestore `Timestamp` (UTC). Jangan simpan tanggal sebagai string. |
| IPK | `number` skala 4.0 |
| Skor kecocokan | `number` 0.0–1.0 (dibandingkan dengan Remote Config `min_match_score_threshold`) |
| ID dokumen beasiswa | slug `<program>-<tahun>`, mis. `mext-scholarship-2027`. ID yang sama dipakai di `sources/` dan `saved_scholarships/`. |

> ⚠️ Data seed lama memakai `UK` untuk Chevening. Kontrak memakai `GB`; seed akan dikoreksi di S1. Sampai saat itu, perlakukan `UK` = `GB` di sisi klien.

---

## 1. `scholarships/{scholarshipId}` — katalog (Find → View details → Ask AI)

Akses: **baca** = user yang sudah login. **Tulis** = hanya backend (Admin SDK).

| Field | Tipe | Keterangan |
|---|---|---|
| `title` | string | |
| `provider` | string | |
| `description` | string | Ringkasan 1–2 kalimat |
| `fundingType` | `"full"` \| `"partial"` | |
| `educationLevels` | array\<EducationLevel\> | Jenjang yang **dibiayai** |
| `eligibleCitizenships` | array\<string\> | ISO alpha-2 atau `GLOBAL` |
| `hostCountries` | array\<string\> | Negara tujuan studi |
| `fieldsOfStudy` | array\<string\> | `["ALL"]` = semua bidang. **`[]` = bidang belum diumumkan → jangan dipakai untuk menyaring** (tetap tampilkan beasiswanya). |
| `minGpa` | number \| null | |
| `languageRequirement` | string \| null | Teks bebas, mis. `IELTS 6.5 / TOEFL iBT 80` |
| `openDate` | Timestamp \| null | Pendaftaran dibuka (untuk label "Segera dibuka") |
| `deadline` | Timestamp | |
| `status` | `"active"` \| `"closed"` | Diubah otomatis ke `closed` oleh `process-deadlines` saat deadline lewat |
| `isUrgent` | boolean | `true` jika sisa waktu ≤ 14 hari (diatur backend) |
| `requirements` | array\<{ `id`: string, `label`: string }\> | Sumber checklist "Prepare". `id` stabil (mis. `ielts`, `cv`, `motivation-letter`). *(diisi mulai S1)* |
| `benefits` | array\<string\> | *(diisi mulai S1)* |
| `sourceUrl` | string | Halaman resmi untuk tombol "Apply on the official website" & sitasi jawaban AI |
| `notes` | string \| null | Catatan riset (konteks tambahan untuk grounding AI, bukan untuk ditampilkan mentah) |
| `verificationStatus` | `"verified"` \| `"pending"` | `pending` = belum dicek manusia → tampilkan label "Belum diverifikasi" |
| `verifiedBy` | string \| null | |
| `lastVerifiedAt` | Timestamp \| null | |
| `lastChangeSummary` | string \| null | Ringkasan perubahan terakhir untuk "Track updates" |
| `updatedAt` | Timestamp | Naik **hanya** saat ada perubahan yang perlu diketahui user (konten terverifikasi berubah / status jadi `closed`). |
| `lastCheckedAt` | Timestamp | Kapan backend terakhir mengecek sumber resmi (sinyal "terakhir dicek X jam lalu") |
| `createdAt` | Timestamp | |
| `contentHash`, `recordHash` | string | Internal backend, abaikan di klien |

**Sumber data:** `backend/data/scholarships.json` (format tim Research, lihat bagian 5). Katalog di Firestore hanya diubah oleh importer.

**Catatan query Flutter:** Firestore hanya mengizinkan satu `array-contains`/`array-contains-any` per query. Katalog kecil (< 100 dokumen), jadi query utamanya:

```dart
FirebaseFirestore.instance.collection('scholarships')
  .where('status', isEqualTo: 'active')
  .orderBy('deadline')          // composite index (status, deadline) sudah disiapkan di firestore.indexes.json
```

lalu filter negara/jenjang/bidang/IPK di sisi klien. Butuh kombinasi query lain? Kabari backend untuk dibuatkan index baru.

---

## 2. `users/{uid}` — profil & preferensi (Set preferences)

Akses: baca/tulis/hapus **hanya pemilik** (`request.auth.uid == uid`).

| Field | Tipe | Keterangan |
|---|---|---|
| `displayName` | string | |
| `educationLevel` | EducationLevel | Jenjang yang **ingin ditempuh** (dicocokkan dengan `scholarships.educationLevels`) |
| `currentEducationLevel` | `"high_school"` \| EducationLevel | opsional |
| `citizenship` | string | ISO alpha-2 (dicocokkan dengan `eligibleCitizenships`) |
| `targetCountries` | array\<string\> | ISO alpha-2 (dicocokkan dengan `hostCountries`), maks 30 |
| `fieldsOfStudy` | array\<string\> | maks 20 |
| `gpa` | number | 0–4 |
| `languageScores` | map | Kunci tetap: `ielts` (number), `toeflIbt` (number), `duolingo` (number), `jlpt` (`"N1"`–`"N5"`), `topik` (number 1–6). Semua opsional. |
| `fundingPreference` | `"full"` \| `"partial"` \| `"any"` | opsional |
| `cvSummary` | map \| null | Hasil ekstraksi CV: `{ skills: string[], experienceYears: number, extractedBy: "on_device" \| "cloud", extractedAt: Timestamp }`. **Teks CV mentah TIDAK disimpan di Firestore.** |
| `privacy` | map | `{ cloudAiAllowed: boolean }`. `false` = mode privat (hanya Gemini Nano, tanpa cloud fallback). |
| `onboardingCompleted` | boolean | |
| `createdAt`, `updatedAt` | Timestamp | Isi dengan `FieldValue.serverTimestamp()` |

---

## 3. `users/{uid}/saved_scholarships/{scholarshipId}` — Save → Prepare → Apply → Track updates

Akses: **hanya pemilik**. ID dokumen = ID beasiswa. Saat create, rules memastikan `scholarships/{scholarshipId}` memang ada.

| Field | Tipe | Keterangan |
|---|---|---|
| `scholarshipId` | string | **Wajib** sama dengan ID dokumen |
| `status` | `"saved"` \| `"preparing"` \| `"applied"` | **Wajib** |
| `matchScore` | number \| null | 0–1, dari Hybrid AI |
| `checklist` | array\<{ `id`: string, `label`: string, `done`: boolean }\> | Disalin dari `scholarships.requirements` saat user mulai "Prepare". Maks 50 item. |
| `notes` | string | Maks 5000 karakter |
| `lastSeenUpdatedAt` | Timestamp \| null | Set = `scholarships.updatedAt` saat user membuka detail |
| `savedAt`, `updatedAt` | Timestamp | |

**Logika badge "Ada pembaruan":** tampilkan jika `scholarship.updatedAt > saved.lastSeenUpdatedAt`, lalu tampilkan `scholarship.lastChangeSummary`. Setelah user membuka detail, tulis ulang `lastSeenUpdatedAt`.

> Koleksi `matches/{id}` yang ada di rules lama **diganti** dengan `saved_scholarships/{id}`. Skor untuk beasiswa yang belum disimpan dihitung on-device dan tidak perlu disimpan.

---

## 4. Koleksi khusus backend (klien tidak bisa akses)

**`sources/{sourceId}`** (ID = ID beasiswa): `scholarshipId`, `name`, `url`, `ignorePatterns?` (array regex untuk teks dinamis), `lastContentHash` (SHA-256), `previousContentHash`, `lastRunStatus` (`seeded` \| `baseline` \| `unchanged` \| `updated` \| `error`), `needsReview` (boolean), `lastChangedAt`, `lastRunAt`, `lastHttpStatus`, `lastError`, `consecutiveErrors`.

**`sync_logs/{logId}`**: satu dokumen per run sinkronisasi: `startedAt`, `finishedAt`, `trigger`, `runId`, `status` (`success` \| `partial` \| `failed`), ringkasan `sources` & `deadlines`, `changedSourceIds`, `errors`.

**Alur perubahan sumber** (sesuai diagram "Scheduled source checks → Validate and review → Authorized backend publisher"): `check-sources` hanya **menandai** `sources.needsReview = true` ketika hash halaman berubah. Isi `scholarships` baru diubah setelah Research & Quality Lead memverifikasi perubahan; saat itulah `lastChangeSummary` dan `updatedAt` diperbarui. Dengan begitu user tidak melihat "pembaruan" palsu akibat banner/iklan di halaman sumber.

---

## 5. Format `backend/data/scholarships.json` (diisi tim Research via Pull Request)

Satu array of object. Divalidasi otomatis di CI (`npm run validate:data`) sebelum PR boleh di-merge, lalu dipublish ke Firestore saat merge ke `main`.

| Field JSON | Wajib | Format | Jadi di Firestore |
|---|---|---|---|
| `id` | ✔ | slug huruf kecil `program-tahun` | ID dokumen |
| `title`, `provider`, `description`, `sourceUrl` (https) | ✔ | string | sama |
| `fundingType` | ✔ | `full` \| `partial` | sama |
| `educationLevels` | ✔ | array, min. 1 | sama |
| `eligibleCitizenships`, `hostCountries` | ✔ | ISO alpha-2 (`GB`, bukan `UK`) atau `GLOBAL` | sama |
| `fieldsOfStudy` | ✔ | array (boleh `[]`) | sama |
| `deadline` | ✔ | `YYYY-MM-DD` → 23:59:59 WIB, atau ISO 8601 dengan zona waktu | Timestamp |
| `openDate` | | `YYYY-MM-DD` → 00:00 WIB | Timestamp |
| `status` | ✔ | `active` \| `closed` | sama (lalu dikelola `process-deadlines`) |
| `minGpa` | | number 0–4 atau `null` | sama |
| `requirements` | | array string | array `{id, label}` (`id` dibuat otomatis dari label) |
| `benefits` | | array string | sama |
| `lastVerified` | | `YYYY-MM-DD` | `lastVerifiedAt` |
| `verifiedBy` | | nama, atau `pending-human-review` | `verifiedBy` + `verificationStatus` |
| `notes` | | string | sama |
| `changeSummary` | | 1 kalimat, isi **saat mengubah** record yang sudah ada | `lastChangeSummary` |

`updatedAt` hanya naik jika field yang dilihat user berubah. Mengubah `notes`, `lastVerified`, atau `verifiedBy` saja **tidak** memicu badge "Ada pembaruan".

---

## 6. Remote Config

| Key | Tipe | Default (samakan di `setDefaults` app) | Fungsi |
|---|---|---|---|
| `ai_inference_mode` | String | `PREFER_ON_DEVICE` | Mode inferensi hybrid Firebase AI Logic |
| `cloud_fallback_model` | String | `gemini-2.5-flash` | Model cloud saat on-device tidak siap |
| `min_match_score_threshold` | Number | `0.65` | Batas minimum `matchScore` untuk ditampilkan sebagai "cocok" |

Selalu panggil `setDefaults` dengan nilai di atas supaya app tetap jalan saat offline / fetch gagal.
