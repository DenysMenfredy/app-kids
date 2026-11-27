# G1 — Android physical validation (2026-11-27)

Status: **BLOCKED — no physical Android device attached.** Nothing in the
"Checklist" below was executed on a device. This change prepares the dev
build, the install/evidence tooling and the checklist so the run can start as
soon as hardware is available. It does **not** claim any physical validation.

## Scope

One pass of the G1 onboarding and learning flow on a physical Android device,
against a development build and a synthetic account:

registration → email verification → child creation → assessment → lesson →
reward → book.

Constraints:

- no emulator as a substitute for a physical device;
- no production project, billing, purchases or real family data;
- no secrets and no PII in the committed evidence;
- bugs found are reported in separate PRs, not fixed in this evidence PR.

## Environment audit (2026-11-27)

| Item | Finding |
| --- | --- |
| Connected devices | none — `adb devices -l` lists no device and `lsusb` shows no Android device |
| adb | not on `PATH`; binary present at `~/Android/Sdk/platform-tools/adb` |
| Android SDK | 36.1.0, no `cmdline-tools`, licenses not confirmed |
| Flutter | 3.47.4, Dart 3.13.3 |
| Host JDK | 25.0.5, incompatible with the project's Gradle 8.14 — the build fails at the Gradle step |
| JDK used for the build | Temurin 21.0.13.1 (matches the Java 21 pinned in CI), installed under `/tmp` for this run |

No device was available, so the physical run itself is the only missing part.

## Dev build (verified)

Build command, run from `lele/`:

```bash
JAVA_HOME=/path/to/jdk-21 \
  flutter build apk --debug --dart-define-from-file=config/firebase.dev.json
```

Result:

- built `lele/build/app/outputs/flutter-apk/app-debug.apk`;
- commit `6041beb20d7b5d18324f08b79eb28d53bfc4c1ca` (main);
- config validator: `Firebase config validada: dev / android`;
- package `br.com.lele.lele`, version `0.1.0` (code 1), minSdk 24, targetSdk 36;
- size ≈ 165 MiB (debug); SHA-256
  `d91b3c3ee3679d7fd699bc91511cae23b95a1487bc9aafc718a1bda6e6c2a700`.

The APK is a local artifact: it is not committed (size) and cannot be attached
to GitHub as-is. Rebuild from the same commit and configuration; the recorded
SHA identifies the artifact prepared here, not a reproducible-build guarantee.

## Prerequisites before the run

1. **Physical Android device**, Android 7.0+ (minSdk 24), USB debugging
   authorized. An emulator is not acceptable evidence.
2. **Host tooling**: Flutter 3.47.4, JDK 21, Android SDK with platform-tools.
3. **Synthetic account with an accessible inbox.** Email verification sends a
   real message from the `letrando-dev` project; the tester must be able to
   open the link. Never use a real parent's or child's mailbox.
4. **Dev backend ready**: email/password Auth, Firestore Rules, Cloud
   Functions and seed content deployed to `letrando-dev`. Readiness was not
   verified from this host.
5. **App Check debug token registered.** Debug builds use the Android debug
   provider, and callables enforce App Check. On first launch, logcat prints
   `Enter this debug token in the Firebase console` — register it for the
   `letrando-dev` Android app before running the assessment. Do not paste the
   token into the PR or the evidence.
6. **No billing or purchases**. The free book is enough for the book step.

## Install

```bash
# from the repository root, after building the APK above
adb devices -l                       # confirm the physical device is "device"
adb install -r lele/build/app/outputs/flutter-apk/app-debug.apk
adb shell pm clear br.com.lele.lele  # only for a clean first-run state
adb logcat -c
adb shell monkey -p br.com.lele.lele -c android.intent.category.LAUNCHER 1
```

For a full evidence session, use the script instead of copying the commands:

```bash
docs/evidence/g1/android-g1-evidence.sh \
  --apk lele/build/app/outputs/flutter-apk/app-debug.apk
```

It refuses emulators, records device/build/app metadata (without the serial),
installs the APK, captures logcat while the checklist runs, takes one
screenshot per step and writes a pass/fail matrix. Output goes to `/tmp` by
default so PII is not committed. Preflight is automatic; the script prompts
for the ten device steps below.

## Checklist (not executed)

Record one artifact per step. `☐` means not run; replace with `PASS`/`FAIL`
only after observing the result on the device.

| # | Step | Action | Expected | Evidence | Result |
| --- | --- | --- | --- | --- | --- |
| 1 | Preflight | Connect device, run script | Physical model/SDK/fingerprint recorded; APK SHA matches | `device-info.txt`, `app-info.txt` | ☐ |
| 2 | Cold start | Launch app | Splash → welcome carousel, no crash | screenshot | ☐ |
| 3 | Registration | `Criar conta` with synthetic name/e-mail/password | Account created; verification screen opens | screenshot (e-mail masked) | ☐ |
| 4 | E-mail verification | Open the link from the inbox, return to app, `Já confirmei` | Verification accepted; child setup opens; resend shows a 60 s cooldown | screenshot (e-mail masked) | ☐ |
| 5 | Child creation | Fill child name, age, avatar; `Continuar` | Profile saved; assessment intro opens | screenshot (child name masked) | ☐ |
| 6 | Assessment | `Vamos lá`, answer the 3 questions | Result screen and parent dashboard show a placement; no callable error | screenshots | ☐ |
| 7 | Child mode | Open the child area from the dashboard | Child home shows journey, streak, coins and XP | screenshot | ☐ |
| 8 | Lesson | Open the current lesson and finish the activities | Tap, match, trace, listen and story steps all complete; no dead end | screenshots | ☐ |
| 9 | Reward | Finish the lesson | Reward screen with XP/coins/streak increment; back navigation works | screenshot | ☐ |
| 10 | Book | Open the library and a free book | Pages turn; read-aloud works; returning to the shelf works | screenshot | ☐ |
| 11 | Stability | Reopen the app; read crash buffer | Session/profile persists; no app crash or ANR in `crash.txt` | `crash.txt`, `logcat.txt` | ☐ |

Additional checks:

- [ ] App Check token was registered before step 6 (token kept out of evidence).
- [ ] No full-screen notification or system dialog exposes a real account.
- [ ] Screenshots contain no real e-mail, full name, address or child data.
- [ ] Device model and Android version are recorded; device serial is not.
- [ ] Any bug has its own PR/issue linked from this document.

## Evidence handling

- Keep raw artifacts outside the repository (`/tmp/g1-evidence-*` is the
  script default).
- Review `logcat.txt` before sharing: it can contain e-mail addresses and UIDs.
- Mask parent/child names and e-mails in screenshots; do not crop out the app
  bar in a way that hides the build identity.
- Commit only the filled checklist with artifact names and SHA-256 hashes, or
  attach reviewed artifacts to the PR. Never commit raw PII.

## Result

Not validated. The single unblocking action is connecting an authorized
physical Android device to this host, then running the script and checklist.
The dev backend and App Check registration must be confirmed by their owner
before step 6 can pass.
