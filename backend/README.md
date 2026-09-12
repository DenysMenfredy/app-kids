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
├── functions/                 # Cloud Functions — TypeScript, Node 20, v2 API
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
├── seed/                      # curriculum content, imported into Firestore
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

The curriculum is data, not code. `backend/seed/` holds it as plain JSON,
hand-editable by a content editor and validated on every `npm test`
(`src/content/seed_content.test.ts` checks ids, cross-references, lesson
ordering and per-activity payloads):

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

`speech` is the pt-BR text the app reads aloud; recorded audio replaces it
once assets exist. Two content rules are enforced by tests: exactly one
correct option per exercise, and never uppercase `I` alongside `L` — the
same glyph in most fonts, so the child couldn't tell them apart.

A seed file may hold one document or an array of them, so 148 activities
stay in one reviewable file. Module lesson ranges match the assessment's
placement bands and the app's `curriculum`, which is asserted by tests on
both sides.

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

## Commands

```bash
cd functions
npm install
npm test                # tsc build + 59 unit tests (domain + seed integrity)

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
