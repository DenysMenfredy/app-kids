# G1 — local validation on Android emulator (2026-11-27)

Status: **LOCAL FIRST ROUND — core flow passed on the emulator.** This is not a
physical-device or cloud validation. The physical gate remains open (see
`android-physical-2026-11-27.md`).

## Environment

| Item | Value |
| --- | --- |
| Device | `emulator-5554`, AVD `Medium_Phone_API_36.1`, Android 16 / API 36 |
| Display | 1080×2400 physical; run continued at 540×1200 / density 240 to avoid software-rendering ANRs (see Stability) |
| Host | Linux, 16 cores, KVM, Flutter 3.47.4, JDK 21 |
| Backend | Firebase Emulator Suite: Auth 9099, Firestore 8081, Functions 5001, UI 4000 |
| Port note | Host port 8080 is occupied by an unrelated Adminer instance. The suite ran on 8081 and the app used a **local, uncommitted** one-line override from 8080 to 8081. The canonical stack keeps 8080. |
| Backend code | `main` at `14f74a6` (T08a consent gate) |
| App code | PR #10 (`daeb9a4`, merged as `4bfaaca`; T08c app consent), compiled with `USE_FIREBASE=true` and `USE_EMULATOR=true` |
| Seed | 218 documents (7 modules, 37 lessons, 148 activities, 6 stories, 6 books) |

Build and install:

```bash
cd lele
flutter build apk --debug --dart-define=USE_FIREBASE=true --dart-define=USE_EMULATOR=true
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell pm clear br.com.lele.lele
adb -s emulator-5554 shell monkey -p br.com.lele.lele \
  -c android.intent.category.LAUNCHER 1
```

Evidence captured with `adb exec-out screencap -p`; synthetic accounts only,
no real family data and no passwords in this document.

## Checklist and results

| # | Step | Expected | Result | Evidence |
| --- | --- | --- | --- | --- |
| 1 | Cold start | Splash → welcome carousel, no crash | PASS | `01-parent-dashboard.png` (post-onboarding dashboard) |
| 2 | Registration | Account created; verification screen | PASS | synthetic account; consent callable recorded |
| 3 | E-mail verification | Link accepted; child setup opens | PASS | Auth emulator link; `Já confirmei` advanced |
| 4 | Consent | Recorded after acceptance; gate only when missing | PASS | gate accepted once; later signup recorded without a gate; child creation then passed |
| 5 | Child creation | Profile saved; assessment intro | PASS | `02-child-profile.png` |
| 6 | Assessment | 3 questions submit; placement shown | PASS | `03-assessment-result.png` (module 1) |
| 7 | Child mode | Journey and today's lesson visible | PASS | `04-child-home.png` |
| 8 | Lesson | Tap, match, trace and listen complete | PASS | `05-lesson-intro.png`, `06-tap-activity.png`, `07-trace-activity.png` |
| 9 | Reward | XP, coins and streak increase | PASS | `08-reward.png` (+50 XP, +10 coins, 1 day) |
| 10 | Book | Free book opens; page turns; bookmark saved | PASS | `09-books.png`, `10-book-reader.png` (page 1 → 2 of 5) |
| 11 | Stability | No app crash after the flow | PASS with environment caveat | see below |

### Consent observations

- On the first synthetic account the gate appeared once right after signup and
  was accepted with "Aceitar e continuar"; child creation and all gated
  callables then succeeded.
- On a later account `recordParentConsent` completed during signup and the
  gate did not appear, showing the proactive path works.
- The idempotent `changed: true/false` handling is covered by the unit tests in
  PR #10; the UI treats both as success.

### Stability caveat

At 1080×2400 the emulator hit one ANR: `Input dispatching timed out … Waited
5001ms for MotionEvent` after tapping an assessment option, with the host
emulator using software rendering. No Dart exception or app crash appeared in
logcat. After overriding the display to 540×1200 (density 240), the same flow
completed without ANRs. This is recorded as an environment limitation of the
headless software-rendered emulator, not as a product pass at full resolution.

## Findings (not fixed here, per PR04 scope)

1. **Premium dead-end for a module 2 placement.** One synthetic child was
   placed in "Reconhecimento Visual" (module 2), which the journey shows as
   Premium. With billing disabled, there is no free lesson to continue, so
   lesson → reward is unreachable for that placement. A child placed in module
   1 (lowest answers) completed the flow. This needs a product decision or a
   separate bug/PR; it was not mixed into this evidence change.
2. **Full-resolution emulator ANR** described above; retest on a physical
   device or a hardware-rendered emulator before treating it as resolved.

## Gaps

- Physical-device validation remains required for G1.
- Account-switch/isolation UI is being covered by PR05; offline/relogin and
  local notifications were not part of this first round.
- Cloud deploy, App Check and real e-mail delivery remain paused (ADR 0021).
- The app build is PR #10 (`daeb9a4`, merged as `4bfaaca`). Main also carries the PR08
  backend/account-deletion changes; they do not alter this onboarding flow.
