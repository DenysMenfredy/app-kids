# ADR 0021 — Local-first G1; cloud setup deferred

Date: 2026-11-27. Status: accepted by the founder.

## Context

`letrando-dev` exists, the local Firebase CLI is authenticated and the Android
emulator works, but the project has no Blaze billing, remote Firestore/Storage,
Workload Identity, GitHub `dev` environment or App Check registration. The first
manual deploy stopped at Storage and applied nothing. The founder decided not to
configure cloud now and to validate G1 locally first.

## Decision

- G1's first evidence is local: Android emulator `emulator-5554` (Android
  16/API 36) against the Firebase Emulator Suite from `backend/dev.sh`, with the
  seed, local smoke and the app flow.
- Cloud setup is paused: Blaze, remote Firestore/Storage, Workload Identity,
  GitHub Environment, App Check console registration and the first deploy are
  not requested or executed now.
- PR03 stays merged as deploy automation and must not run. The deploy runbook is
  kept for the cloud resumption.
- Cloud deploy, release App Check attestation and physical-device evidence are
  later gates. A local G1 does not authorize production or a store release.
- Production and billing remain prohibited; purchase stays disabled.
- Local-only changes used to run the emulator (port overrides, local config)
  must not be merged unless they are environment-configurable and documented.

## Local acceptance

The local G1 evidence covers signup/e-mail verification, consent, child profile,
assessment, lesson, reward, book, account switch/isolation, offline/relogin and
local notifications. It runs `flutter analyze`, `flutter test`, Functions tests,
Rules tests and `backend/smoke.sh`, with commands, results and no PII. Evidence
is labelled `local`; it is not cloud or physical-device evidence.

## Consequences

- G1 can close on local evidence, explicitly labelled local.
- The cloud gate remains open and must be re-run before G2 or any production
  claim.
- The local stack must run the latest `main`, including T08a consent and the app
  consent call (PR09a).
