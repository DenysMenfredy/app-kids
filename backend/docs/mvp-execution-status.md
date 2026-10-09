# MVP execution status — 2026-10-09

Source: `../../Lele_Plano_Execucao_MVP.md`. This is a code-and-local-test
inventory, not evidence of Firebase console configuration or a deploy.
The 2026-10-09 Flutter changes passed whole-project Dart analysis, local Android
installation, emulator hot restart and runtime-error inspection. This continuation
passed all 16 Functions test groups, all 39 Security Rules tests, all 309 Flutter
tests, eight additional Firebase-mode profile-state regression tests, and the
demo-emulator smoke flows, including active-time lifecycle,
atomic daily summaries, concurrent completion and email-verification
enforcement. This remains local evidence, not staging, console or physical-device
validation.

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
| T03 | Implemented locally; staging gate open | Rewards require a server-created lesson session; activity responses are scored against published content; stats, progression and rewards are derived transactionally. The demo-emulator smoke flow passed invented-lesson denial, incomplete-session denial, scored activities, parallel completion with exactly one reward, replay idempotency and XP-write denial. Staging rollout and older-client compatibility remain open. |
| T04 | Locally verified | Client writes to placement, completion, attempts and sessions are denied; profile updates have field/type/size bounds. Rules tests and demo emulator smoke pass. Check compatibility with older clients before deploy. |
| T05 | Partial | `createChildProfile` allocates IDs server-side with parent-scoped idempotency; client Rules deny child creation; list/select/add/edit UI uses `(uid, childId)` for learning paths and holds each lesson to its starting child. Removed selections fall back to a surviving registered profile, or an explicit empty state when none remain. Dashboard and profile sheet distinguish empty/loading/error states; child-only routes wait for a real selected profile, and adding a child starts with a blank required name. Profile deletion, legacy `primary` migration, and staging rehearsal remain open. ADR 0008 records the boundary. |
| T06 | Partial | Cached profile/selection is UID-namespaced; child, parent-name, progress, journey and entitlement streams switch to UID/child-keyed providers so another scope's last snapshot is not shown while loading. Firebase mode never substitutes the demo Sofia or a cached profile for an empty/pending/failed child list; the local cache is selection input, not evidence that a child exists. Lesson stats reset on parent/child changes and lesson writes remain bound to the starting child. Offline/logout/restart device checks and Firestore SDK cache strategy remain open. |
| T09, T11–T12 | Partial; guarded | Backend now reserves one seven-day no-card trial per parent, cancels at trial end if no payment method is added, stores server-created Checkout/customer mappings, and uses retryable webhook leases plus current Stripe subscription retrieval. No user-facing trial-ending notice is wired, the signed Stripe integration matrix has not run, and checkout remains disabled by default behind the web App Check ID. Portal UI and native billing remain incomplete. |
| T10 | Partial | Module-1 and `full_curriculum` lesson boundaries remain enforced. Book pages now require a published, version-matched payload and the current `premium_books` feature for Premium titles; direct payload lists and client writes are denied. Rules tests and demo-emulator integration pass. External Storage media is not used by this book slice. |
| T07 | Partial | New email/password accounts must verify before child setup; resend/check flows refresh Firebase user and ID-token state. Firestore Rules and the child-profile and checkout callables enforce the boundary; Google/Apple are exempt. ADR 0011 records the decision. The demo smoke flow confirms an unverified token is rejected and a verified token can proceed; real email delivery, physical iOS validation, and support for independently existing Apple accounts remain open. |
| T14 | Implemented locally; release gates open | Six original stories (two free, four Premium) now have published backend metadata/pages, symbolic cover/page illustrations, a reader with narration and navigation, loading/error/empty/locked states, and parent/child-scoped server-validated bookmarks. Existing demo exports receive books on startup. Whole-project Flutter analysis has zero issues; all 297 Flutter tests, 38 Rules tests, Functions tests and book publication/bookmark emulator smoke pass. Staging publication, editorial review and physical iOS/Android narration checks remain open. ADR 0012 records access and bookmark boundaries. |
| T16 | Implemented locally; release gates open | The dashboard now reads server-owned per-child weekly totals instead of fixed example bars. Daily summaries are materialized once per completed session in the reward transaction, split active time at local midnight, preserve first completion dates and count replays as practice without another new lesson/reward. The parent-timezone week, weighted answer accuracy, initial one-new-lesson daily goal, empty/loading/error states and midnight refresh are implemented. Local domain, widget, Rules and emulator lifecycle/concurrency/replay checks pass. Older sessions have no guessed active-time backfill; staging and physical-device validation remain open. ADR 0013 defines the formulas. |
| T08, T13, T17–T18, T20 | Open | Implement in the order and with the gates in the execution plan. |
| T19 | Partial | Backend structured logs and server analytics now recursively omit child profile identifiers; client event coverage, collection eligibility/consent, crash reporting and export/retention controls remain open. |
| T15 | Partial | Server-owned scored attempts cover all four activity types. New sessions enforce the activity order and require every match pair before advancing. Ordered lifecycle commands, foreground heartbeats, pause/resume/abandonment and bounded server-measured active time now feed daily summaries. The client captures both the child and lesson at start; transient attempt/completion retries preserve IDs and repeated completion reuses one result. Emulator checks cover paused time, late commands, out-of-order answers and duplicate totals. Versioned content contracts, durable cold-process exercise resumption, actionable failed-session recovery, physical lifecycle validation and privacy-reviewed trace criteria remain open. |

The previous `primary` data model remains supported until its records are
counted and migrated; direct published-content reads, incomplete Premium
catalog coverage, and lack of real-device/staging evidence prevent declaring
G1/G2 complete. Trace evidence is a bounded gesture signal, not proof of
accurate handwriting. ADRs 0006 and 0008 record the learning and child-data
trust boundaries and their remaining validation gates.
