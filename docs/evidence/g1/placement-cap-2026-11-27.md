# G1 — free-tier placement cap revalidation (2026-11-27)

Status: **PASSED locally** for the P0 fixed in PR #16. This is an emulator
run against the local Emulator Suite, not a physical or cloud validation.

## Environment

| Item | Value |
| --- | --- |
| Device | `emulator-5554`, Android 16 / API 36, 540×1200 |
| Stack | Auth 9099, Firestore 8081, Functions 5001 (host 8080 is an unrelated Adminer) |
| Backend | `main` at `ae58d4b` (includes PR #16, cap in `submitAssessment`) |
| App | `main` at `ae58d4b`, debug build with `USE_FIREBASE=true` and `USE_EMULATOR=true`; local one-line Firestore port override to 8081, **not committed** |
| Data | new synthetic children only; no real family data |

## Scenario A — free tier, high-score answers

New synthetic child `Lia`, answers `Quase todas` / `Sozinho(a)` / `Todos os
dias` (requested band 4).

Backend result read from the emulator (IDs omitted):

```text
placement.moduleNumber=1
placement.firstLessonId=lesson_001
freeTierCapped=true
requestedModuleNumber=4
child.currentLessonId=lesson_001
```

App result screen showed **MÓDULO 1 — Coordenação Motora e Vogais**, with no
premium module promise. The child home offered the lesson and the lesson
started into the tap activity (`Toque na letra A`), with no dead-end.

Evidence: `01-free-capped-result.png`, `02-free-lesson-available.png`,
`03-free-lesson-started.png`.

## Scenario B — Premium active, same high-score answers

Second synthetic child `Caio`, same answers, with a **local-only** active
`full_curriculum` entitlement written to
`users/{uid}/entitlements/premium` through the Admin SDK against the Firestore
emulator. No cloud project was touched.

Backend result:

```text
placement.moduleNumber=4
placement.firstLessonId=lesson_014
freeTierCapped=false
requestedModuleNumber=4
child.currentLessonId=lesson_014
```

App result screen showed **MÓDULO 4 — Juntar Sons e Sílabas** and the lesson
started into the tap activity (`Toque na letra F`), confirming the band is
preserved for active Premium.

Evidence: `04-premium-band-result.png`, `05-premium-lesson-started.png`.

## Notes

- The cap is server-owned; the app only renders the placement returned by
  `submitAssessment`. Extra fields (`freeTierCapped`,
  `requestedModuleNumber`) are ignored by the current UI.
- Existing children stored above module 1 without entitlement are not repaired
  by this change; ADR 0025 keeps them for a later reparo/reavaliação.
- Physical device, cloud and App Check remain later gates.

## Commands

```bash
# stack (local, 8081): firebase emulators:start --config firebase.g1.local.json
# app build: flutter build apk --debug \
#   --dart-define=USE_FIREBASE=true --dart-define=USE_EMULATOR=true
# install: adb -s emulator-5554 install -r app-debug.apk
# evidence: adb -s emulator-5554 exec-out screencap -p > step.png
```
