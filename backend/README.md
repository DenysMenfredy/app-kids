# Letrando Backend — Firebase

Implements `Letrando_Firebase_System_Design_Specification.pdf`: Firebase-first
MVP backend for the Letrando literacy app (Flutter client in `../lele`).

## Layout

```
backend/
├── firebase.json              # Firestore/Storage/Functions/emulator config
├── .firebaserc                # letrando-dev / -staging / -production aliases
├── firestore.rules            # client trust boundary (§12–§14)
├── firestore.indexes.json
├── storage.rules              # binary content assets only (§6)
├── functions/                 # Cloud Functions — TypeScript, Node 22, v2 API
│   └── src/
│       ├── config.ts          # Secret Manager + per-env params
│       ├── lib/               # firestore paths, guards, idempotency, logging
│       ├── domain/            # pure logic: plans, subscription, entitlement,
│       │                      # reminders, assessment, gamification
│       │                      # (fully unit-tested)
│       ├── auth/              # onUserCreated bootstrap
│       ├── payments/          # provider abstraction, Stripe checkout/portal,
│       │                      # webhook (signature + idempotency)
│       ├── subscriptions/     # syncEntitlement trigger (single writer)
│       ├── notifications/     # registerDevice, sendDailyReminders, FCM fan-out
│       ├── profiles/          # server-issued child profile IDs
│       ├── learning/          # sessions, scored attempts, completion,
│       │                      # updateProgress, submitAssessment
│       ├── analytics/         # trackServerEvent → structured logs → BigQuery
│       └── admin/             # setUserRole (custom claims), manageContent
├── dev.sh                     # run the whole backend on emulators
├── smoke.sh                   # end-to-end check against those emulators
├── content/bncc_alignment.json # BNCC crosswalk (reference, not seeded)
├── seed/                      # curriculum content, imported into Firestore
│   ├── courses/ modules/      # 1 course, 7 modules
│   ├── lessons/               # 37 lessons (4 activities each)
│   ├── activities/            # 148 tap/match/trace/listen exercises
│   ├── stories/               # 6 module-7 texts + comprehension questions
│   └── assessments/           # onboarding placement questionnaire
├── test/rules/                # Security Rules tests (Firestore emulator)
└── docs/adr/                  # architecture decision records
```

## Trust model

The mobile client is untrusted. It may only:

- read/write approved fields of its own profile and existing child profiles,
  and its own notification preferences; read its own sessions and learning
  data (the latter are written by trusted functions, ADR 0006);
- read its own subscriptions/entitlements/notifications/devices;
- read public catalog metadata; read first-module activity/story payloads or
  Premium payloads only while their server entitlement is current.

Everything privileged — checkout creation, webhook processing, entitlement
activation, role assignment, child-profile creation, content publishing,
device registration, notification fan-out, assessment scoring and reward
granting — happens in Cloud Functions guarded by auth, applicable role checks
and App Check.

## Learning flow (§5, ADR 0003)

```
Flutter → reads assessments/{id}          (labels only; weights ignored)
        → submitAssessment {questionId: optionId}
        → backend scores from the STORED weights → placement band
        → writes child learningLevel/currentCourseId/currentLessonId
          + users/{uid}/assessmentResults/{childId}

Flutter → startLessonSession {lessonId, childId}
        → backend validates current journey + published activity manifest
        → submitActivityAttempt {sessionId, activityId, response, requestId}
        → backend scores against published content; session records evidence
        → completeLesson {lessonId, childId, sessionId}
        → backend requires all four activities and derives lesson statistics
        → transaction: already completed? → no reward
        → else applyLessonReward (XP, coins, local-calendar streak)
        → users/{uid}/gamification/{childId}   (client-read-only)
        → and, when this was the lesson the child was on,
          currentLessonId moves to the next one in the course
```

Child profile creation uses `createChildProfile {requestId, profile}`. The
callable authenticates and validates the parent request, applies App Check,
allocates the document ID on the server, and makes same-request retries
idempotent. Clients can query their own child list and edit allowlisted fields
on an existing profile; client document creation is denied by Rules (ADR 0008).

XP, coins, score, answer counts and duration are never trusted from client
payloads; the app reads the resulting server documents. Trace evidence is
limited to gesture metadata and does not claim to verify handwriting accuracy.

## Content model (§5)

The curriculum is data, not code. `seed/` holds it as the documents Firestore
stores, and `npm run seed` imports them:

Module metadata remains readable, but activity answer keys and story payloads
are protected by Security Rules and by the session callables: module 1 is free;
later modules require the current `full_curriculum` entitlement. A stale
`active` flag without a valid period is insufficient. Book pages and protected
media still need a real backend catalog/Storage contract before publication.

```
seed/{courses,modules,lessons,activities,stories,assessments}/
      │  npm run seed
      ▼
Firestore
```

The current content is the BNCC-aligned bundle
(`jornada_alfabetizacao_bncc_seed.zip`): 1 course, 7 modules, 37 lessons,
148 activities and 6 stories, progressing vowels and tracing → visual
recognition → phonological awareness → grapheme-phoneme and blending →
words and digraphs → short phrases → stories and comprehension. Distractors
teach rather than pad: module 4's listening exercises are near-minimal pairs
(FOCA / FADA / FACA), and module 3's share an initial sound.

`content/bncc_alignment.json` maps modules to BNCC goals. It is a
pedagogical crosswalk for the team, deliberately **not** seeded and not a
claim of curricular compliance — the BNCC separates Educação Infantil
objectives by age band from Ensino Fundamental skills, and this product
spans 3–7, so difficulty has to follow the child's assessment rather than a
grade.

Content is hand-maintained: edit the files under `seed/` (or replace them
from a new bundle) and re-run the import. Every `npm test` validates them
(`src/content/seed_content.test.ts` checks ids, cross-references, lesson
ordering, per-activity payloads, that all four activities of a lesson teach
the same letter, and that no matching exercise pairs I with L):

```
courses/{courseId}          → moduleIds, locale, published
modules/{moduleId}          → courseId, number, title, lessonTheme,
                              firstLessonId, lessonCount
lessons/{lessonId}          → moduleId, number, order, title, theme,
                              estimatedMinutes, activityIds
activities/{activityId}     → lessonId, type, order, difficulty, instruction
stories/{storyId}           → lessonId, title, text, questions
```

One lesson is four activities in play order — `tap`, `match`, `trace`,
`listen` — each carrying only what its exercise needs:

| type | payload |
| --- | --- |
| `tap` | `target`, `options[]` (one `correct`), `speech` |
| `match` | `pairs[]` of upper/lower, `lowercaseOrder` for the right column |
| `trace` | `letter` |
| `listen` | `answer`, `options[]` (one `correct`), `speech` |

`speech` is the pt-BR text the app reads aloud, including how each letter is
*said* ("bê", "éle-agá"); recorded audio replaces it once assets exist. Two
content rules are enforced by tests: exactly one correct option per
exercise, and never uppercase `I` alongside `L` — the same glyph in most
fonts, so the child couldn't tell them apart.

Module lesson ranges match the assessment's placement bands and the app's
`curriculum`, asserted by tests on both sides.

**Engine gap:** `stories/` carries the six module-7 texts and their
comprehension questions, but the four activity types only express letters
and words, so nothing reads them yet. Those lessons currently do
phrase-level listening — real practice, but not reading a story. A story
activity type is the missing piece.

## Payments flow (§8)

```
Flutter → createCheckoutSession (callable, App Check, plan validation)
        → Stripe Checkout (hosted page; no card data in the app)
        → Stripe webhook → verify signature → webhookEvents idempotency claim
        → users/{uid}/subscriptions/{subId} upsert
        → syncEntitlement trigger → users/{uid}/entitlements/premium
```

Premium is never activated from the checkout redirect. BRL is stored as
integer cents (R$149,90 = 14990).

## Running it locally

```bash
./dev.sh          # build functions + start Auth/Firestore/Functions emulators,
                  # seeding backend/seed/ on first run. UI: localhost:4000
./dev.sh --reseed # start from a clean database
./smoke.sh        # end-to-end check against the running emulators
```

`dev.sh` runs under the throwaway project `demo-letrando`, so no credentials
are involved and nothing can reach a real project. See the root README for
pointing the Flutter app at it.

`smoke.sh` walks the slice the unit suites can't: sign-up → profile bootstrap
→ rejects an unverified email → verifies the emulator-only test account →
idempotent server-issued child creation → rules-enforced profile edit →
server-side assessment scoring → scored activity attempts → concurrent and
replayed lesson completion → denied client XP write. It uses a random password
and removes the temporary smoke-test parent and Firestore subcollections when
it exits.

The parent dashboard's weekly totals come from server-owned daily summaries.
The additional lifecycle/summary integration check uses only the running demo
emulators and removes its temporary users:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
npm --prefix functions run test:learning:smoke
```

It covers bounded presence, pause/resume, delayed commands, child ownership,
concurrent completion, replay, and exact summary contributions. ADR 0013
documents the active-time and calendar policy; historical session time is not
backfilled from wall-clock durations.

If signup succeeds but saving a child's profile fails, check the Functions
terminal for `Loaded functions definitions from source` and a
`createChildProfile` initialization message. A terminal waiting at
`Prompting for parameters` can have open emulator ports while every callable
still returns 404. The committed `functions/.env.demo-letrando` supplies
fake payment parameters and explicitly disables web checkout so startup
does not wait for that prompt. Restart `./dev.sh` after adding a callable or
changing its configuration; normal shutdown exports the local data.

`No AppCheckProvider installed` in an Android emulator run is a separate SDK
warning: the app intentionally skips App Check in emulator mode, and the
callables skip only attestation enforcement there (ADR 0004). Auth and child
ownership checks still run. A missing-provider warning alone does not mean
that a child-profile request was rejected.

The Rules suite uses `demo-letrando-rules` with separate ports, while
`dev.sh` uses `demo-letrando`. Both the project IDs and ports must differ:
the Firebase CLI stores its emulator hub locator per project, so reusing
the development project can break discovery and data export after tests.

## Commands

```bash
cd functions
npm install
npm test                # TypeScript build + domain and seed-integrity tests

# Seed educational content (course, modules, lessons, activities, assessment)
FIRESTORE_EMULATOR_HOST=localhost:8080 npm run seed -- --project letrando-dev
GOOGLE_APPLICATION_CREDENTIALS=sa.json npm run seed -- --project letrando-dev

# Security Rules tests — 34 tests against the Firestore emulator.
# firebase-tools is a local devDependency; the emulator needs Java 11+.
cd ../test/rules
npm install
npm test                # firebase emulators:exec → node --test (29 tests)

# Deploy (per environment)
firebase deploy --project dev        # letrando-dev
firebase deploy --project staging
firebase deploy --project production
```

## Environment setup (per Firebase project)

1. Create the three Firebase projects from `.firebaserc`.
2. Secrets (Secret Manager):
   `firebase functions:secrets:set STRIPE_SECRET_KEY --project <env>` and
   `STRIPE_WEBHOOK_SECRET`.
3. Params (`.env.<project>` files or deploy prompts):
   `STRIPE_PRICE_FOUNDER_MONTHLY|QUARTERLY|ANNUAL`, `CHECKOUT_RETURN_URL`.
4. Point the Stripe webhook endpoint at the deployed `stripeWebhook` URL and
   subscribe to: `checkout.session.completed`, `customer.subscription.*`,
   `invoice.paid`, `invoice.payment_failed`.
5. Enable App Check (Play Integrity / App Attest) and enforce it for
   Firestore, Functions and Storage.
6. BigQuery: create a Cloud Logging sink filtered on
   `jsonPayload.message="letrando_event"` (server events) and enable the
   Firebase Analytics BigQuery export (client events).
7. Seed the curriculum and assessment (`npm run seed` above). Without the
   assessment, `submitAssessment` returns "Avaliação indisponível" and the
   app shows its offline fallback placement.

Never use production payment credentials or production data during
development (spec §21).

## Not yet wired (deliberate MVP cuts)

- **Release blocker:** the App Check client integration is present, but its
  Play Integrity/App Attest and web registrations plus physical-device tests
  are still outstanding. Enforcement remains on outside the emulator
  (ADR 0004).
- Apple/Google native billing providers (interface ready in
  `payments/provider.ts`; see ADR 0002).
- Only the module *ranges* are still mirrored in app code (`curriculum` in
  the Flutter app); lessons and activities themselves are fetched. The app
  keeps one bundled sample lesson for offline/demo play, checked against
  this seed by a test so the two can't drift.
- Multi-child summary/aggregation for the parent dashboard (the app can now
  select a child; XP, coins, streak and journey remain scoped per child).
- Profile deletion and migration of legacy `primary` children; see ADR 0008.
- Account deletion / data-retention jobs (LGPD §19 — deletion mechanism must
  land before public launch).
- Achievement and weekly-report notification jobs (sender infra is in place).
- The legal review flagged in §19: this spec is engineering, not legal advice.
