# MVP execution status — 2026-10-08

Source: `../../Lele_Plano_Execucao_MVP.md`. This is a code-and-local-test
inventory, not evidence of Firebase console configuration or a deploy.
The 2026-10-08 Flutter changes passed whole-project Dart analysis, emulator
hot restart and runtime-error inspection; Functions passed `tsc --noEmit`.
Automated suites were not run in this pass; email-verification tests and
emulator/device validation remain outstanding.

## F0 inventory

| Item | Repository evidence | Still to verify externally |
| --- | --- | --- |
| Environments | `backend/.firebaserc` names dev, staging and production; Node 22 and `southamerica-east1` are configured. | Project existence, app IDs, IAM, secrets, indexes and Stripe test/live separation in each console. |
| Native IDs | Android and iOS currently use `br.com.lele.lele`. | Distinct per-environment registrations/flavors, signing fingerprints, Apple capability and URL schemes. |
| Client Firebase | `firebase_options.dart` is a placeholder; Android `google-services.json` and iOS `GoogleService-Info.plist` are absent. | Generate/configure per environment; physical staging builds. |
| CI | `.github/workflows/ci.yml` runs Flutter, Functions and Firestore Rules tests; Android release now fails early if production Firebase config is absent. | Confirm actual GitHub run status and production Environment configuration. |
| Legacy children | Existing `primary` documents remain readable; newly created profiles receive server IDs. | Count legacy accounts/children in a non-production export and plan the idempotent migration. No export was modified in this pass. |

Local commands: `flutter analyze`, `flutter test`, Functions `npm test`, Rules
`npm test`, and `backend/smoke.sh` against seeded demo emulators. Node 22 is
available via `/home/denys7/.nvm/versions/node/v22.19.0/bin` on this host.

## Decisions

- D01–D03 were supplied by the product owner on 2026-10-07 and are recorded
  in ADR 0007: a real seven-day trial, entire first module free, and a
  purchase-free Android/iOS beta. Checkout stays disabled until the trial
  and web-only channel have been fully verified.
- D04–D07 remain open: offline boundary, minimal child profile/consent,
  launch content manifest, and legally reviewed retention/deletion matrix.

## Task ledger

| Task | Status | Evidence / remaining gate |
| --- | --- | --- |
| T01 | Partial | Android release CI rejects placeholder/mismatched production config. Real FlutterFire files, flavors, Google/Apple setup, iOS check and device tests still need project access. |
| T02 | Partial | Flutter activates App Check before protected calls; local emulator exemption remains. Console registration, release attestation, denial metrics and physical tests remain. |
| T03 | Implemented locally; integration gate open | Rewards now require a server-created lesson session; activity responses are scored against published content; completion stats are derived from that session and reward/progression remain transactional and idempotent. Run the updated Emulator Suite smoke flow and add concurrent completion evidence before deployment. |
| T04 | Locally verified | Client writes to placement, completion, attempts and sessions are denied; profile updates have field/type/size bounds. Rules tests and demo emulator smoke pass. Check compatibility with older clients before deploy. |
| T05 | Partial | `createChildProfile` allocates IDs server-side with parent-scoped idempotency; client Rules deny child creation; list/select/add/edit UI uses `(uid, childId)` for learning paths and holds each lesson to its starting child. Removed selections now fall back to and persist a valid profile; profile deletion, legacy `primary` migration, and staging rehearsal remain open. ADR 0008 records the boundary. |
| T06 | Partial | Cached profile/selection is UID-namespaced; child, parent-name, progress, journey and entitlement streams now switch to UID/child-keyed providers so the previous account's last snapshot is not shown while another scope loads. Lesson stats reset on parent/child changes and lesson writes remain bound to the starting child. Offline/logout/restart device checks and Firestore SDK cache strategy remain open. |
| T09, T11–T12 | Partial; guarded | Backend now reserves one seven-day no-card trial per parent, cancels at trial end if no payment method is added, stores server-created Checkout/customer mappings, and uses retryable webhook leases plus current Stripe subscription retrieval. No user-facing trial-ending notice is wired, the signed Stripe integration matrix has not run, and checkout remains disabled by default behind the web App Check ID. Portal UI and native billing remain incomplete. |
| T10 | Partial | Firestore Rules tests pass for module 1 and current `full_curriculum` entitlement access; lesson-session callables enforce the same boundary and child UI routes later modules to the paywall. Real book payloads and protected Storage media remain unimplemented. |
| T07 | Partial | New email/password accounts must verify before child setup; resend/check flows refresh Firebase user and ID-token state. Firestore Rules and the child-profile and checkout callables enforce the boundary; Google/Apple are exempt. ADR 0011 records the decision. Auth-emulator delivery, rules/Functions tests, physical iOS validation, and support for independently existing Apple accounts remain open. |
| T14 | Partial | The hardcoded shelf is now limited to demo mode; Firebase mode does not advertise books until published backend content exists. Backend catalog, actual pages/media and reading-position sync remain open. |
| T08, T13, T16–T20 | Open | Implement in the order and with the gates in the execution plan. |
| T15 | Partial | Server-owned sessions and scored attempts now cover tap/listen choices and match pairs; trace stores bounded gesture metadata without raw handwriting. Run emulator integration/retry tests, then complete pause/resume, elapsed active-time semantics, and privacy-reviewed trace criteria. |

The previous `primary` data model remains supported until its records are
counted and migrated; direct published-content reads, incomplete Premium
catalog coverage, and lack of real-device/staging evidence prevent declaring
G1/G2 complete. Trace evidence is a bounded gesture signal, not proof of
accurate handwriting. ADRs 0006 and 0008 record the learning and child-data
trust boundaries and their remaining validation gates.
