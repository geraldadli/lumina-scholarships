# Lumina — Firestore Data Contract & Remote Config (v1)

> Owner: Backend & Data Engineer. Source of truth for the Flutter team, Hybrid AI (Kotlin/Pigeon), and Research/QA.
> Changes to field names / types **must** go through the backend first, because the Security Rules also validate them.
> The equivalent TypeScript types are in `backend/src/schema.ts`; the access rules are in `firestore.rules`.

## General conventions

| Topic | Rule |
|---|---|
| Country codes | ISO 3166-1 alpha-2, uppercase: `ID`, `JP`, `KR`, `DE`, `GB`, `US`, `AU`, `SG`, `NL`. The sentinel `GLOBAL` = all countries. |
| Education level (`EducationLevel`) | `undergraduate` \| `masters` \| `phd` |
| Field of study | Free string (title case, e.g. `Computer Science`). The sentinel `ALL` = all fields. |
| Time | Always a Firestore `Timestamp` (UTC). Never store dates as strings. |
| GPA | `number` on a 4.0 scale |
| Match score | `number` 0.0–1.0 (compared with Remote Config `min_match_score_threshold`) |
| Scholarship document ID | slug `<program>-<year>`, e.g. `mext-scholarship-2027`. The same ID is used in `sources/` and `saved_scholarships/`. |
| Language | All text shown to students (`title`, `description`, `requirements`, `benefits`, `lastChangeSummary` / `changeSummary`) is written in English. |

> ℹ️ Legacy sample data used `UK` for Chevening. That data was removed from Firestore on 20 Nov 2026, and all current data uses `GB`, as this contract requires. Clients may still treat `UK` as `GB` defensively.

---

## 1. `scholarships/{scholarshipId}` — catalog (Find → View details → Ask AI)

Access: **read** = any signed-in user. **Write** = backend only (Admin SDK).

| Field | Type | Notes |
|---|---|---|
| `title` | string | |
| `provider` | string | |
| `description` | string | A 1–2 sentence summary |
| `fundingType` | `"full"` \| `"partial"` | |
| `educationLevels` | array\<EducationLevel\> | The levels that are **funded** |
| `eligibleCitizenships` | array\<string\> | ISO alpha-2 or `GLOBAL` |
| `hostCountries` | array\<string\> | Countries where the study takes place |
| `fieldsOfStudy` | array\<string\> | `["ALL"]` = all fields. **`[]` = fields not announced yet → do not use it for filtering** (still show the scholarship). |
| `minGpa` | number \| null | |
| `languageRequirement` | string \| null | Free text, e.g. `IELTS 6.5 / TOEFL iBT 80` |
| `openDate` | Timestamp \| null | When applications open (for the "Opening soon" label) |
| `deadline` | Timestamp | |
| `status` | `"active"` \| `"closed"` | Changed automatically to `closed` by `process-deadlines` once the deadline has passed |
| `isUrgent` | boolean | `true` when 14 days or less remain (set by the backend) |
| `requirements` | array\<{ `id`: string, `label`: string }\> | Source of the "Prepare" checklist. `id` is stable (e.g. `ielts`, `cv`, `motivation-letter`). *(populated from S1 onward)* |
| `benefits` | array\<string\> | *(populated from S1 onward)* |
| `sourceUrl` | string | The official page, for the "Apply on the official website" button and for AI answer citations |
| `notes` | string \| null | Research notes (extra context for grounding the AI, not meant to be shown raw) |
| `verificationStatus` | `"verified"` \| `"pending"` | `pending` = not yet checked by a human → show the "Not yet verified" label |
| `verifiedBy` | string \| null | |
| `lastVerifiedAt` | Timestamp \| null | |
| `lastChangeSummary` | string \| null | Summary of the latest change, for "Track updates" |
| `updatedAt` | Timestamp | Goes up **only** when there is a change the user should know about (verified content changed / status became `closed`). |
| `lastCheckedAt` | Timestamp | When the backend last checked the official source (the "last checked X hours ago" signal) |
| `createdAt` | Timestamp | |
| `contentHash`, `recordHash` | string | Backend internals, ignore them on the client |

**Data source:** `backend/data/scholarships.json` (the Research team's format, see section 5). The catalog in Firestore is only changed by the importer.

**Flutter query note:** Firestore allows only one `array-contains` / `array-contains-any` per query. The catalog is small (< 100 documents), so the main query is:

```dart
FirebaseFirestore.instance.collection('scholarships')
  .where('status', isEqualTo: 'active')
  .orderBy('deadline')          // composite index (status, deadline): defined in firestore.indexes.json and enabled in the live project
```

then filter by country / education level / field / GPA on the client. Need another query combination? Tell the backend so a new index can be created.

---

## 2. `users/{uid}` — profile & preferences (Set preferences)

Access: read/write/delete by the **owner only** (`request.auth.uid == uid`).

| Field | Type | Notes |
|---|---|---|
| `displayName` | string | |
| `educationLevel` | EducationLevel | The level the student **wants to study** (matched against `scholarships.educationLevels`) |
| `currentEducationLevel` | `"high_school"` \| EducationLevel | optional |
| `citizenship` | string | ISO alpha-2 (matched against `eligibleCitizenships`) |
| `targetCountries` | array\<string\> | ISO alpha-2 (matched against `hostCountries`), max 30 |
| `fieldsOfStudy` | array\<string\> | max 20 |
| `gpa` | number | 0–4 |
| `languageScores` | map | Fixed keys: `ielts` (number), `toeflIbt` (number), `duolingo` (number), `jlpt` (`"N1"`–`"N5"`), `topik` (number 1–6). All optional. |
| `fundingPreference` | `"full"` \| `"partial"` \| `"any"` | optional |
| `cvSummary` | map \| null | CV extraction result: `{ skills: string[], experienceYears: number, extractedBy: "on_device" \| "cloud", extractedAt: Timestamp }`. **The raw CV text is NOT stored in Firestore.** |
| `privacy` | map | `{ cloudAiAllowed: boolean }`. `false` = private mode (Gemini Nano only, no cloud fallback). |
| `onboardingCompleted` | boolean | |
| `createdAt`, `updatedAt` | Timestamp | Set with `FieldValue.serverTimestamp()` |

---

## 3. `users/{uid}/saved_scholarships/{scholarshipId}` — Save → Prepare → Apply → Track updates

Access: **owner only**. The document ID = the scholarship ID. On create, the rules make sure `scholarships/{scholarshipId}` actually exists.

| Field | Type | Notes |
|---|---|---|
| `scholarshipId` | string | **Required**, must equal the document ID |
| `status` | `"saved"` \| `"preparing"` \| `"applied"` | **Required** |
| `matchScore` | number \| null | 0–1, from Hybrid AI |
| `checklist` | array\<{ `id`: string, `label`: string, `done`: boolean }\> | Copied from `scholarships.requirements` when the user starts "Prepare". Max 50 items. |
| `notes` | string | Max 5000 characters |
| `lastSeenUpdatedAt` | Timestamp \| null | Set to `scholarships.updatedAt` when the user opens the details |
| `savedAt`, `updatedAt` | Timestamp | |

**"Updated" badge logic:** show it when `scholarship.updatedAt > saved.lastSeenUpdatedAt`, then show `scholarship.lastChangeSummary`. After the user opens the details, rewrite `lastSeenUpdatedAt`.

> The `matches/{id}` collection from the old rules is **replaced** by `saved_scholarships/{id}`. Scores for scholarships that are not saved are computed on-device and do not need to be stored.

---

## 4. Backend-only collections (clients cannot access them)

**`sources/{sourceId}`** (ID = scholarship ID): `scholarshipId`, `name`, `url`, `ignorePatterns?` (an array of regexes for dynamic text), `lastContentHash` (SHA-256), `previousContentHash`, `lastRunStatus` (`seeded` \| `baseline` \| `unchanged` \| `updated` \| `error`), `needsReview` (boolean), `lastChangedAt`, `lastRunAt`, `lastHttpStatus`, `lastError`, `consecutiveErrors`.

**`sync_logs/{logId}`**: one document per sync run: `startedAt`, `finishedAt`, `trigger`, `runId`, `status` (`success` \| `partial` \| `failed`), summaries for `sources` & `deadlines`, `changedSourceIds`, `errors`.

**Source change flow** (following the "Scheduled source checks → Validate and review → Authorized backend publisher" diagram): `check-sources` only **flags** `sources.needsReview = true` when a page's hash changes. The `scholarships` content is only changed after Research & the Quality Lead have verified the change; that is when `lastChangeSummary` and `updatedAt` are updated. This way users never see a false "update" caused by a banner or ad on the source page.

---

## 5. `backend/data/scholarships.json` format (filled in by the Research team via Pull Request)

A single array of objects. It is validated automatically in CI (`npm run validate:data`) before the PR can be merged, then published to Firestore when it is merged into `main`.

| JSON field | Required | Format | Becomes in Firestore |
|---|---|---|---|
| `id` | ✔ | lowercase slug `program-year` | document ID |
| `title`, `provider`, `description`, `sourceUrl` (https) | ✔ | string | same |
| `fundingType` | ✔ | `full` \| `partial` | same |
| `educationLevels` | ✔ | array, at least 1 | same |
| `eligibleCitizenships`, `hostCountries` | ✔ | ISO alpha-2 (`GB`, not `UK`) or `GLOBAL` | same |
| `fieldsOfStudy` | ✔ | array (may be `[]`) | same |
| `deadline` | ✔ | `YYYY-MM-DD` → 23:59:59 WIB, or ISO 8601 with a time zone | Timestamp |
| `openDate` | | `YYYY-MM-DD` → 00:00 WIB | Timestamp |
| `status` | ✔ | `active` \| `closed` | same (then managed by `process-deadlines`) |
| `minGpa` | | number 0–4 or `null` | same |
| `requirements` | | array of strings | array of `{id, label}` (`id` is generated from the label) |
| `benefits` | | array of strings | same |
| `lastVerified` | | `YYYY-MM-DD` | `lastVerifiedAt` |
| `verifiedBy` | | a name, or `pending-human-review` | `verifiedBy` + `verificationStatus` |
| `notes` | | string | same |
| `changeSummary` | | 1 sentence, filled **when changing** an existing record. Shown to students, so write it in English. | `lastChangeSummary` |

`updatedAt` only goes up when a field the user sees has changed. Changing only `notes`, `lastVerified`, or `verifiedBy` does **not** trigger the "Updated" badge.

---

## 6. Remote Config

| Key | Type | Default (match it in the app's `setDefaults`) | Purpose |
|---|---|---|---|
| `ai_inference_mode` | String | `PREFER_ON_DEVICE` | Hybrid inference mode for Firebase AI Logic: `PREFER_ON_DEVICE` (Nano first, the normal value), `ONLY_ON_DEVICE`, `PREFER_IN_CLOUD` or `ONLY_IN_CLOUD` (every question to the cloud, for QA tests only). Cloud AI off in the app always means on-device only |
| `on_device_model` | String | `PREVIEW_FAST` | Gemini Nano to request: `PREVIEW_FAST` (Gemini Nano 4 Fast), `PREVIEW` (Gemini Nano 4 Full) or `STABLE`. Falls back to the stable Nano on phones without the AICore Developer Preview |
| `cloud_fallback_model` | String | `gemini-3.5-flash-lite` | Cloud model used when the on-device model is not ready |
| `min_match_score_threshold` | Number | `0.65` | Minimum `matchScore` to be shown as a "match" |

Always call `setDefaults` with the values above so the app keeps working when offline / when the fetch fails.
