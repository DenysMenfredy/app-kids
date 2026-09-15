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
│       ├── learning/          # updateProgress, completeLesson (rewards),
│       │                      # submitAssessment (server-side placement)
│       ├── analytics/         # trackServerEvent → structured logs → BigQuery
│       └── admin/             # setUserRole (custom claims), manageContent
├── dev.sh                     # run the whole backend on emulators
├── smoke.sh                   # end-to-end check against those emulators
├── content/curriculum.json    # authored curriculum — edit this
├── seed/                      # generated from it, imported into Firestore
│   ├── courses/ modules/      # 1 course, 7 modules
│   ├── lessons/               # 37 lessons (4 activities each)
│   ├── activities/            # 148 tap/match/trace/listen exercises
│   └── assessments/           # onboarding placement questionnaire
├── test/rules/                # Security Rules tests (Firestore emulator)
└── docs/adr/                  # architecture decision records
```

## Trust model

The mobile client is untrusted. It may only:

- read/write its own profile, children, preferences, sessions and learning
  data (schema-validated by Security Rules);
- read its own subscriptions/entitlements/notifications/devices;
- read published educational content, products and feature flags.

Everything privileged — checkout creation, webhook processing, entitlement
activation, role assignment, content publishing, device registration,
notification fan-out, assessment scoring and reward granting — happens in
Cloud Functions guarded by auth + role checks and App Check.

## Learning flow (§5, ADR 0003)

```
Flutter → reads assessments/{id}          (labels only; weights ignored)
        → submitAssessment {questionId: optionId}
        → backend scores from the STORED weights → placement band
        → writes child learningLevel/currentCourseId/currentLessonId
          + users/{uid}/assessmentResults/{childId}

Flutter → completeLesson {lessonId, childId, stats}
        → transaction: already completed? → no reward
        → else applyLessonReward (XP, coins, local-calendar streak)
        → users/{uid}/gamification/{childId}   (client-read-only)
```

XP, coins and streak are never written by the client; the app reads that
document and displays what it is told.

## Content model (§5)

The curriculum is data, not code, and it is authored in one place:

```
content/curriculum.json     the editorial source — 37 lessons, hand-written
      │  npm run seed:build
      ▼
seed/{courses,modules,lessons,activities}/    generated documents
      │  npm run seed
      ▼
Firestore
```

`content/curriculum.json` is where the teaching decisions live: which letter
each lesson introduces, which distractors contrast with it, which word the
child hears. Sequencing follows how pt-BR alphabetisation is normally
taught — vowels, then the consonants that form the simplest CV syllables,
then voiced/voiceless pairs (B/P, D/T, F/V, C/G, S/Z), then the digraphs.

Editing that file and re-running the build is the whole content workflow;
the generated files are validated on every `npm test`
(`src/content/seed_content.test.ts` checks ids, cross-references, lesson
ordering, per-activity payloads, and that all four activities of a lesson
teach the same letter):

```
courses/{courseId}          → moduleIds, locale, published
modules/{moduleId}          → courseId, number, title, lessonTheme,
                              firstLessonId, lessonCount
lessons/{lessonId}          → moduleId, number, order, title, theme,
                              estimatedMinutes, activityIds
activities/{activityId}     → lessonId, type, order, difficulty, instruction
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

**Engine gap:** modules 6 and 7 are called *Frases* and *Histórias*, but the
four activity types only express letters and words. Those lessons use
phrase-level listening and review the most-confused letter pairs, which is
real practice but not sentence or story work. Proper ones need new activity
types.

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

`smoke.sh` walks the slice the unit suites can't: sign-up → the profile
bootstrap trigger → a rules-enforced child write → server-side assessment
scoring → reward granting and its idempotency → a denied client XP write.

## Commands

```bash
cd functions
npm install
npm test                # tsc build + 61 unit tests (domain + seed integrity)
npm run seed:build      # regenerate seed/ from content/curriculum.json

# Seed educational content (course, modules, lessons, activities, assessment)
FIRESTORE_EMULATOR_HOST=localhost:8080 npm run seed -- --project letrando-dev
GOOGLE_APPLICATION_CREDENTIALS=sa.json npm run seed -- --project letrando-dev

# Security Rules tests — 24 tests against the Firestore emulator.
# firebase-tools is a local devDependency; the emulator needs Java 11+.
cd ../test/rules
npm install
npm test                # firebase emulators:exec → node --test

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

- **Release blocker:** the app has no App Check integration, so every
  callable would reject it against a real project. Enforcement is on
  everywhere except the emulator (ADR 0004); the client must add
  `firebase_app_check` before a deployment real devices talk to.
- Apple/Google native billing providers (interface ready in
  `payments/provider.ts`; see ADR 0002).
- Only the module *ranges* are still mirrored in app code (`curriculum` in
  the Flutter app); lessons and activities themselves are fetched. The app
  keeps one bundled sample lesson for offline/demo play, checked against
  this seed by a test so the two can't drift.
- Multi-child aggregation for the parent dashboard (gamification is stored
  per child, the app uses a single fixed child id).
- Account deletion / data-retention jobs (LGPD §19 — deletion mechanism must
  land before public launch).
- Achievement and weekly-report notification jobs (sender infra is in place).
- The legal review flagged in §19: this spec is engineering, not legal advice.
