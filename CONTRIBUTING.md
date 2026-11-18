# Panduan Kontribusi Lumina

Tujuan: history `main` yang linear dan mudah dibaca juri maupun tim, serta tidak ada kredensial yang bocor (repo ini **publik**).

## Branch

`main` selalu bisa di-build. Semua perubahan lewat branch + Pull Request.

| Prefix | Untuk | Contoh |
|---|---|---|
| `feat/<area>-<topik>` | fitur baru | `feat/ai-pigeon-bridge`, `feat/app-onboarding` |
| `fix/<area>-<topik>` | perbaikan bug | `fix/backend-deadline-timezone` |
| `data/<topik>` | update `backend/data/scholarships.json` | `data/add-gks-2027` |
| `docs/…`, `ci/…`, `chore/…` | dokumentasi, workflow, perawatan | `ci/cache-emulators` |

Area: `app` (Flutter), `ai` (Kotlin/Pigeon/AI Logic), `backend`, `rules`, `data`.

## Commit: [Conventional Commits](https://www.conventionalcommits.org/)

```
<type>(<scope>): <ringkasan singkat, huruf kecil, tanpa titik>
```

- **type:** `feat`, `fix`, `docs`, `test`, `ci`, `chore`, `refactor`
- **scope:** `app`, `ai`, `backend`, `rules`, `data`, `ci`, `docs`
- Satu commit = satu perubahan logis. Commit harus lolos `npm run typecheck` (backend) / `flutter analyze` (app).

Contoh: `feat(ai): add pigeon contract for hybrid inference`, `fix(rules): allow empty checklist`, `feat(data): add GKS 2027`.

## Alur Pull Request

```powershell
git switch main
git pull --ff-only
git switch -c feat/ai-pigeon-bridge
# ...kerja + commit kecil-kecil...
git fetch origin
git rebase origin/main        # rebase, bukan merge, supaya history tetap linear
git push -u origin feat/ai-pigeon-bridge
```

Buka PR ke `main`, isi template, tunggu CI hijau dan 1 review.

**Cara merge:**
- **Squash and merge** (default): PR dengan banyak commit kecil/"wip" → jadi 1 commit rapi di `main`.
- **Rebase and merge**: PR yang commit-nya sudah dirapikan dan masing-masing bermakna.
- Hindari "Create a merge commit".

Hapus branch setelah merge.

## Jangan pernah commit

`serviceAccountKey.json`, `google-services.json`, `.env*`, API key, token, keystore (`*.jks`, `*.keystore`).
Sudah tercantum di `.gitignore`; tetap cek `git status` sebelum commit.

File pribadi (laporan, draf pesan, salinan kredensial) simpan di folder **`_local/`** di root repo. Folder itu diabaikan Git, jadi root repo tetap bersih. Jika terlanjur ter-push: **segera kabari Backend Engineer** untuk rotate kunci. Menghapus file di commit berikutnya tidak cukup.
