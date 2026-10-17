# MVP execution status — 2026-10-17

Source: `../../Lele_Plano_Execucao_MVP.md`. This records code/local-test evidence
and the explicitly verified Firebase registrations below, not a backend deploy
or end-to-end staging acceptance.
Execution now follows version 2.0 (native stores only). The owner confirmed
no trial promise until verified (D01), UID-wide cross-platform Premium (D08),
and monthly/quarterly/annual equal-benefit plans without in-app plan changes
(D09). ADR 0017 supersedes the prior external-acquisition decision while
preserving Apple identity rules and legacy customer reconciliation.

This first v2 delivery starts with F0/T01–T04, not an unverified claim that
F1 or the full MVP is finished. All 367 Flutter tests, 104 Functions tests,
41 Rules tests and the disposable-account trust smoke passed locally.
Build validation rejects missing/mismatched real config and demo/dev/emulator
releases. On 2026-10-16 the owner authorized creation of `letrando-dev` and
`letrando-staging`, accepted Firebase terms, and authorized Android/iOS app
registration. All four apps use `br.com.lele.lele` and were created successfully.
Public SDK files were downloaded per environment and converted to explicit build
defines; dev is selected locally. Dev/staging Android coherence validation and
the staging/dev mismatch rejection passed. iOS metadata passed generator checks;
Mac-native validation and physical builds remain unverified. Project/app IDs are
recorded in `lele/config/README.md`; no production project or billing linkage was
created. Attestation, provider configuration, backend provisioning, real staging
startup and physical-device tests remain gates. Android debug compilation/installation, Flutter MCP hot restart
and runtime-error inspection passed. A direct Gradle release pre-build rejected
missing real Firebase configuration before registration, as intended. The
tested offline helper converts downloaded public Android/iOS files to environment
defines without overwriting existing config. Release CI now selects the matching
native Android file and reads the distribution project/app from validated config.
No remote deploy, customer cancellation or data migration occurred.

Auth follow-up (ADR 0018): the native Google client now uses official
`google_sign_in` and a Firebase ID-token exchange, with chooser/cancellation,
logout and public OAuth-metadata regressions. Both existing debug signing
fingerprints were registered in dev only. The owner initialized ordinary Auth in
both consoles; 2026-10-17 API checks confirm `FIREBASE_AUTH` and billing disabled.
Email/password is now enabled and read back in both projects, with passwordless
email disabled, duplicate emails disabled, enumeration protection enabled and
default notification locale `pt-BR`. Narrow field-mask updates did not change
users, domains, other providers, templates, App Check or billing. The public init
API's billing requirement was not used to upgrade either project.
The owner approved the project-owner email for Google's public support contact
and deferred Apple because there is no Developer membership yet. The supplied
refreshed Android/iOS files are both dev: their actual public OAuth IDs were
imported into dev config/native files, and Runner declares the dev iOS callback.
Readback confirms dev Google is enabled and its web audience matches the app;
staging Google is still absent. All 367 app tests, analysis and real-dev-config
Android debug compilation passed. A fresh demo-emulator launch and MCP hot restart
found no Dart runtime errors; this is not a real-provider login test. Real email
delivery, Google consent/account creation, Mac/iOS validation, staging signing and
callback setup remain open. See `auth-providers.md` for the remaining gates.

## F0 inventory

| Item | Repository evidence | Still to verify externally |
| --- | --- | --- |
| Environments | `letrando-dev` and `letrando-staging` were created and verified active; required Firebase-enablement IAM permissions were confirmed. Billing was verified disabled before app registration and was not linked. Node 22 and `southamerica-east1` remain configured in the repo, not remotely deployed. | Production creation is not authorized; backend APIs, IAM/service credentials, database regions/indexes, Google/Apple sandbox/production contexts remain open. |
| Native IDs | Four active Firebase registrations: Android/iOS in dev/staging, all using the existing `br.com.lele.lele`. | Distinct installable flavors, signing fingerprints, Apple capability and URL schemes. Registration is not store enrollment. |
| Client Firebase | Real public Android/iOS SDK files are saved under `lele/config/native/{dev,staging}` and generated into both environment JSON files. Active native files select dev; Android checks accept each matching environment and reject a cross-environment file. Android/Xcode pre-build and release CI share a validator. | Finish OAuth/native resources/capabilities/flavors, App Check and backend setup; validate physical staging builds on Android/iOS. Public bucket metadata is not evidence of Storage provisioning. See `lele/config/README.md`. |
| CI | Flutter, Functions and Rules tests remain; native Android debug compile and content inventory are added. Release dispatch selects staging/production; tags force production; missing/mismatched public/native config rejects the build. | Confirm actual GitHub run status and each GitHub Environment's signing/distribution/project configuration. |
| Legacy children | Read-only local `inventory:mvp -- --emulator` found eight demo child documents, zero named `primary`, on 2026-10-16. Newly created profiles receive server IDs. | Remote/export counts remain unknown. Rehearse the idempotent migration, reference counts and rollback in staging; no export was modified. |
| Store products | Native-only policy and three plan periods are confirmed; no real product/base-plan IDs were supplied or invented. | Console owner must confirm/register products, store API IAM/keys, test accounts, Pub/Sub, sandbox/review contexts and Mac/device availability. |
| Plugin spike | Pins official in_app_purchase 3.3.1 / Android 0.5.4 / StoreKit 0.4.13+3; compile-time account-ID/JWS parameter capability regressions pass. | Native store test purchases, backend verification, callbacks, restore/finish and physical iOS compilation are not covered by capability tests. |

Local commands: `flutter analyze`, `flutter test`, Functions `npm test`, Rules
`npm test`, and `backend/smoke.sh` against seeded demo emulators. Node 22 is
available via `/home/denys7/.nvm/versions/node/v22.19.0/bin` on this host.

## Decisions

- D01/D03/D08/D09 now follow plan v2 and ADR 0017: no unverified trial copy,
  native-only required commercial billing, UID-wide cross-platform access,
  monthly/quarterly/annual equal benefits and no in-force plan-change UI.
  D02 remains first entire module free. The web acquisition channel is retired,
  not a fallback; legacy reconciliation is preserved pending customer inventory.
- D04–D06 were approved on 2026-10-09 and recorded in ADR 0014: online
  authorization/progress, minimal child fields without exact birth date, and
  the existing seven modules/37 lessons/six stories/six books as launch scope.
- D07 remains open: reviewed retention/deletion matrix and consent wording.

## Task ledger

| Task | Status | Evidence / remaining gate |
| --- | --- | --- |
| T01 | Partial; dev/staging registrations and email verified; dev Google enabled/config imported | Four native registrations and generated per-environment configs are real; dev/staging Android coherence and mixed-environment rejection pass. Ordinary Auth and email/password are enabled with privacy protection and pt-BR defaults; billing remains disabled. Native Google credential exchange is corrected, dev debug fingerprints registered, and refreshed dev OAuth/native metadata and Runner callback match. Remote dev Google audience matches public config; real dev-config Android debug compilation passes. Shared validator checks configured OAuth metadata, rejects demo/emulator/dev releases, and CI selects matching native file/distribution IDs. Production, flavors, staging Google/signing/callback setup, Mac/iOS capabilities and physical staging tests remain gates. Apple is deferred pending membership. |
| T02 | Partial | Flutter activates App Check before protected calls; local emulator exemption remains. Console registration, release attestation, denial metrics and physical tests remain. |
| T03 | Implemented locally; staging gate open | Rewards require a server-created lesson session; activity responses are scored against published content; stats, progression and rewards are derived transactionally. The demo-emulator smoke flow passed invented-lesson denial, incomplete-session denial, scored activities, parallel completion with exactly one reward, replay idempotency and XP-write denial. Staging rollout and older-client compatibility remain open. |
| T04 | Locally verified | Client writes to placement, completion, attempts and sessions are denied; profile updates have field/type/size bounds. Rules tests and demo emulator smoke pass. Check compatibility with older clients before deploy. |
| T05 | Partial | `createChildProfile` allocates IDs server-side with parent-scoped idempotency; client Rules deny child creation; list/select/add/edit UI uses `(uid, childId)` for learning paths and holds each lesson to its starting child. Removed selections fall back to a surviving registered profile, or an explicit empty state when none remain. Dashboard and profile sheet distinguish empty/loading/error states; child-only routes wait for a real selected profile, and adding a child starts with a blank required name. Profile deletion, legacy `primary` migration, and staging rehearsal remain open. ADR 0008 records the boundary. |
| T06 | Partial | Cached profile/selection is UID-namespaced; child, parent-name, progress, journey and entitlement streams switch to UID/child-keyed providers so another scope's last snapshot is not shown while loading. Firebase mode never substitutes the demo Sofia or a cached profile for an empty/pending/failed child list; the local cache is selection input, not evidence that a child exists. Lesson stats reset on parent/child changes and lesson writes remain bound to the starting child. Offline/logout/restart device checks and Firestore SDK cache strategy remain open. |
| T09, T11–T12 | Open for native billing; acquisition disabled | Fixed founder prices, trial promise, external checkout caller/launcher and enabling flag were removed from the app. The old callable rejects all new acquisition even for the previously attested web app; legacy webhook/portal/entitlement reconciliation remains untouched for existing contracts. Native plugin capability spike is pinned/tested, but native catalog, parental purchase gate, prepare/verification, purchase ownership, RTDN/JWS inbox, reconciliation/outbox, acknowledgement/finish and restore are still required before enabling sales. No real product IDs or sandbox purchase evidence exists. |
| T10 | Partial | Module-1 and `full_curriculum` lesson boundaries remain enforced. Book pages now require a published, version-matched payload and the current `premium_books` feature for Premium titles; direct payload lists and client writes are denied. Rules tests and demo-emulator integration pass. External Storage media is not used by this book slice. |
| T07 | Partial | New email/password accounts must verify before child setup; resend/check flows refresh Firebase user and ID-token state. Firestore Rules and the child-profile and checkout callables enforce the boundary; Google/Apple are exempt. ADR 0011 records the decision. The demo smoke flow confirms an unverified token is rejected and a verified token can proceed; real email delivery, physical iOS validation, and support for independently existing Apple accounts remain open. |
| T14 | Implemented locally; release gates open | Six original stories (two free, four Premium) now have published backend metadata/pages, symbolic cover/page illustrations, a reader with narration and navigation, loading/error/empty/locked states, and parent/child-scoped server-validated bookmarks. Existing demo exports receive books on startup. Whole-project Flutter analysis has zero issues; all 297 Flutter tests, 38 Rules tests, Functions tests and book publication/bookmark emulator smoke pass. Staging publication, editorial review and physical iOS/Android narration checks remain open. ADR 0012 records access and bookmark boundaries. |
| T16 | Implemented locally; release gates open | The dashboard now reads server-owned per-child weekly totals instead of fixed example bars. Daily summaries are materialized once per completed session in the reward transaction, split active time at local midnight, preserve first completion dates and count replays as practice without another new lesson/reward. The parent-timezone week, weighted answer accuracy, initial one-new-lesson daily goal, empty/loading/error states and midnight refresh are implemented. Local domain, widget, Rules and emulator lifecycle/concurrency/replay checks pass. Older sessions have no guessed active-time backfill; staging and physical-device validation remain open. ADR 0013 defines the formulas. |
| T13 | Implemented locally; release gates open | All six existing module-7 stories now have a versioned page/question contract, symbolic illustrations, pt-BR narration, page navigation, comprehension feedback and a required final step in their lessons. Backend scoring requires every question and feeds the same reward/summary transaction; malformed publication, stale revisions and changed in-flight content are rejected. Flutter and all-six-story emulator checks pass, including missing questions, wrong answers, expiry, ownership and parallel completion. Editorial review, staging/old-client rollout and physical-device narration remain open under ADR 0014. |
| T17 | Partial; local demo verified | Parent permission/category/time/timezone controls, native local demo, remote Flutter registration/refresh and logout cleanup are wired. Server-only installation/token ownership, proof-checked rebind, late-logout protection, category rechecks and retryable/partial-send claims pass 11 emulator regressions with simulated FCM. All 335 Flutter tests, 41 Rules tests and Functions groups pass; Android local tray display and MCP hot restart/runtime checks pass. Real Firebase/APNs setup, physical remote/background/terminated tests, offline account-switch cleanup and iOS build remain open. ADR 0016 and notifications-demo.md distinguish local demo from real delivery. |
| T08, T18, T20 | Open | T18 still needs per-child daily missions and an indexed due-work queue with completion/access rechecks, backoff, expiry and timezone/quiet-hour handling; the legacy hourly reminder sweep is not that implementation. T08 still needs reviewed D07 policy; no retention period or consent text was silently approved. |
| T19 | Partial | Backend structured logs and server analytics now recursively omit child profile identifiers; client event coverage, collection eligibility/consent, crash reporting and export/retention controls remain open. |
| T15 | Partial; local recovery implemented | Server-scored attempts cover the four original exercises and optional comprehension, with ordered cursors, revisions/fingerprints and every pair/question required. Starts have persisted idempotency keys; a bounded UID/child-local queue retains unacknowledged attempts after retries and process reconstruction. Online recovery revalidates ownership/content/access/journey, restores confirmed pairs/questions and excludes the inactive gap. Both final exercise types offer save retry and open rewards only after confirmation. Restart explicitly abandons the old run; logout removes the owner's retry data and late responses cannot recreate it. All 328 Flutter tests, eight Firebase-mode profile checks, 17 Functions groups, 39 Rules tests and extended demo-emulator start/recovery/concurrency/expiry/edit checks pass. Android debug installation and hot restart pass with no Dart runtime errors. Staging/older-client rollout, physical process-kill/lifecycle validation and reviewed trace criteria remain open. ADRs 0013–0015 document the contracts. |

The previous `primary` data model remains supported until its records are
counted and migrated; direct published-content reads, incomplete Premium
catalog coverage, and lack of real-device/staging evidence prevent declaring
G1/G2 complete. Trace evidence is a bounded gesture signal, not proof of
accurate handwriting. ADRs 0006 and 0008 record the learning and child-data
trust boundaries and their remaining validation gates.
