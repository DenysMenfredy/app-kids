# app-kids

**Lelê / Letrando** — a pt-BR literacy app for Brazilian children ages 3–7,
and the Firebase backend behind it.

- `lele/` — Flutter app (Android + iOS). See [lele/README.md](lele/README.md).
- `backend/` — Firestore, Cloud Functions, Security Rules, seeded curriculum.
  See [backend/README.md](backend/README.md).
- `CLAUDE.md` — non-negotiable implementation constraints from the system
  design spec.

## Running locally

### Prerequisites

| Need | For |
| --- | --- |
| Flutter SDK (`~/develop/flutter`, already on PATH) | the app |
| Node 22 (`nvm use` in `backend/`) | Cloud Functions, seeding |
| Java 11+ | the Firebase emulators |
| Chrome, or an Android emulator/device | somewhere to run the app |

```bash
cd backend && nvm use     # Node 22 — the Cloud Functions runtime
```

Node matters more than it looks: the Functions emulator silently falls back
to whatever `node` is on PATH, so running a different major than the deploy
runtime means local behaviour can differ from production. `backend/.nvmrc`
pins it, and `dev.sh` warns when they don't match.

### Option 1 — app only, no backend (fastest)

The app defaults to **local mode**: fake auth, on-device storage, one bundled
sample lesson. No Firebase project, no emulators, nothing to install.

```bash
cd lele
flutter run            # pick a device when prompted
```

### Option 2 — full stack against the emulators

**Terminal 1 — backend.** Builds the functions, starts the Auth, Firestore
and Functions emulators, and seeds the curriculum on first run:

```bash
cd backend
npm install --prefix functions        # first time only
npm install --prefix test/rules       # first time only (firebase-tools)
./dev.sh
```

It runs under the throwaway project `demo-letrando` — the `demo-` prefix
means Firebase tooling can never reach a real project from here, so no
credentials are involved. Emulator data persists in `backend/.emulator-data/`
between runs; `./dev.sh --reseed` starts from a clean database.

The Emulator UI is at **http://localhost:4000** — handy for inspecting
Firestore documents and the users you create.

**Terminal 2 — app pointed at the emulators:**

```bash
cd lele
flutter run \
  --dart-define=USE_FIREBASE=true \
  --dart-define=USE_EMULATOR=true
```

No `flutterfire configure` needed: emulator runs use throwaway demo
credentials baked into `core/firebase/firebase_emulators.dart`.

### Picking a device

```bash
flutter devices                                    # what's available
flutter emulators                                  # Android AVDs
flutter emulators --launch Medium_Phone_API_36.1   # start one
flutter run -d chrome                              # or just use the browser
```

The app finds the emulators automatically: `10.0.2.2` from an Android
emulator, `localhost` everywhere else. For a **physical device**, both have to
change — the emulators bind to loopback by default:

```bash
# backend/firebase.json → add "host": "0.0.0.0" to each emulator
flutter run --dart-define=USE_FIREBASE=true --dart-define=USE_EMULATOR=true \
            --dart-define=EMULATOR_HOST=192.168.x.x
```

### Trying the flow

Sign up with any email and password — the Auth emulator accepts anything, and
`onUserCreated` bootstraps the profile. Then: child profile → assessment
(scored server-side, placing the child on the journey) → dashboard → child
mode → the lesson for wherever they were placed.

Payments are the one thing that won't work locally: `backend/functions/.env.demo-letrando`
holds fake Stripe values so the emulator starts, but checkout needs real keys.

## Tests

```bash
cd lele && flutter analyze && flutter test          # 83 tests
cd backend/functions && npm test                    # 61 tests (domain + seed)
cd backend/test/rules && npm test                   # 27 rules tests (emulator)
cd backend && ./smoke.sh                            # 11 end-to-end checks
```
