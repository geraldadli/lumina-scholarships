# Lumina app (Flutter, Android)

The student app: **sign in → browse → view details → save → ask AI**, plus onboarding, Prepare checklist, Saved tracking and Privacy & AI settings. UI follows the Lumina hi-fi prototype (Classic Professional: Figtree, `#233447` / `#D9EAFD` palette).

```
lib/
├── main.dart              Firebase + App Check init, falls back to demo mode
├── app.dart               Root gate: splash → welcome → onboarding → tabs
├── theme.dart             Prototype colour tokens and text styles
├── data/
│   ├── backend.dart       LuminaBackend interface (the only thing screens talk to)
│   ├── firebase_backend.dart  Auth + Firestore, docs/firestore-contract.md field names
│   └── demo_backend.dart  In-memory, runs on assets/demo/scholarships.json
├── models/                Scholarship, UserProfile, SavedScholarship
├── state/                 AppController (session, catalog, saved, AI), browse filters
├── screens/               One file per screen
└── widgets/               Buttons, chips, tags, toggles, scholarship card
```

AI comes from `packages/hybrid_ai` (path dependency): `HybridAi.ask` for Ask AI, `generateChecklist` for Prepare, and `MatchScorer` for every match score. Nothing is re-implemented here.

## Run

```bash
cd frontend
flutter pub get
flutter run            # phone or emulator, Android 8.0 (API 26)+
flutter analyze && flutter test
```

### Demo mode vs live Firebase

Without `android/app/google-services.json` the app builds and runs in **demo mode**: sign-in is simulated, the catalog comes from `assets/demo/scholarships.json` (a copy of `backend/data/scholarships.json`), and nothing is persisted. A banner on Welcome and Home says so. Ask AI shows the "AI unavailable" card because the plugin also needs Firebase.

To go live:

1. Get `google-services.json` for `com.lumina.app` from the backend engineer and put it at `frontend/android/app/google-services.json`. It is gitignored, so **never commit it**.
2. Ask backend to enable the **Google** and **Email/Password** sign-in providers in Firebase Auth.
3. Run a debug build once and look in logcat for `Enter this debug secret into the allow list`. Register that token in Firebase Console → App Check → Manage debug tokens. Without it, cloud AI answers fail with `appCheckFailed`.
   To use a token that is already registered instead, put `{"APP_CHECK_DEBUG_TOKEN": "<token>"}` in `_local/app_check.json` (gitignored) and build with `--dart-define-from-file=../_local/app_check.json`. Never commit the token.

To refresh the demo data: `cp ../backend/data/scholarships.json assets/demo/scholarships.json`.

## Data access (what backend needs to know)

| Screen | Reads / writes | Notes |
|---|---|---|
| Browse, Home | `scholarships` ordered by `deadline` | Whole catalog, filtered on the client (contract §1). Needs only the single-field index Firestore creates automatically. |
| Onboarding, Edit preferences, Privacy | `users/{uid}` `set(merge)` | Cleared optional fields are deleted, never written as `null`, because the rules reject `educationLevel: null` and similar. |
| Save button | `users/{uid}/saved_scholarships/{id}` create / delete | `scholarshipId` = doc id, `status: saved`, `matchScore` from `MatchScorer`, `lastSeenUpdatedAt` = the scholarship's `updatedAt`. |
| Saved, Prepare | same doc, `update` | `status`, `checklist` (`{id,label,done}`, max 50), `notes` (max 5000), `lastSeenUpdatedAt`. |
| Details | `lastSeenUpdatedAt` rewrite | Clears the "Updated" badge after the student opens the details (contract §3). |
| Delete account | batch-deletes saved docs and `users/{uid}`, then the auth user | Re-authenticates **first** (password, or Google sign-in again). A wrong password or a cancel deletes nothing. |

Dates are displayed in WIB, matching how the research team publishes deadlines.

## Known gaps (later sprints)

- CV import (button shows "arrives in a later sprint").
- Bahasa Indonesia UI.
- Share sheet (Details copies the official link for now).
- `minMatchScore` is read from `HybridAi.getStatus()` (Remote Config via the plugin), with the contract default `0.65` until that returns.
