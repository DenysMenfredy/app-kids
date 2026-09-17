# Letrando — Repository Guide

Two codebases:

- `lele/` — Flutter app (iOS/Android), pt-BR literacy app for children 3–7.
- `backend/` — Firebase backend (Firestore, Cloud Functions, Security Rules).

## Non-negotiable implementation constraints (system design spec §22)

1. Never trust the mobile client for authorization, subscription status,
   payment status, role assignment, or entitlement activation.
2. Never store passwords or third-party credentials in Firestore/source code.
3. Never hardcode privileged secrets in the mobile app.
4. Verify every Stripe webhook signature.
5. Make every payment webhook handler idempotent.
6. Authorize every privileged operation server-side.
7. Scope every child-data access to the authenticated parent.
8. Never allow the client to mutate entitlement/payment state.
9. Use server timestamps for authoritative timestamps.
10. Store BRL money as integer cents.
11. Prefer small domain-focused Cloud Functions.
12. Test Security Rules and payment state transitions.
13. Do not add NestJS unless an ADR documents the need.
14. Review dependencies for maintenance, security, license and bundle size.
15. Never bypass security rules from client code.

Changes to authentication, payment authority, entitlement logic, child-data
boundaries or security architecture must be documented as ADRs in
`backend/docs/adr/`.

## Working on the backend

- Cloud Functions: `backend/functions` (TypeScript, Node 22, v2 API —
  `nvm use` in `backend/`; the emulator otherwise falls back to the host's
  node and local stops matching production).
  `npm test` compiles and runs the domain unit tests.
- Security Rules: `backend/firestore.rules` + tests in `backend/test/rules`
  (`npm test` there runs the Firestore emulator; firebase-tools is a local
  devDependency and the emulator needs Java 11+).
- Environments: `letrando-dev` / `letrando-staging` / `letrando-production`
  (`backend/.firebaserc`). Never use production payment credentials or
  production data during development.

## Working on the app

- Flutter SDK: `~/develop/flutter` (3.47.4, already on PATH; the CI
  workflows pin the same version — bump both together). An older
  3.35 copy also exists at `~/development/flutter` — do not use it; it
  resolves `pubspec.lock` down to an older Dart and fights the real one.
- `flutter analyze` must stay at zero issues; run `flutter test` before
  handing work back.
