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
├── seed/                      # content imported into dev/staging Firestore
├── test/rules/                # Security Rules tests (emulator)
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
npm test                # tsc build + 44 domain unit tests (node --test)

# Seed educational content (assessment questions, weights, placement bands)
FIRESTORE_EMULATOR_HOST=localhost:8080 npm run seed -- --project letrando-dev
GOOGLE_APPLICATION_CREDENTIALS=sa.json npm run seed -- --project letrando-dev

# Security Rules tests (needs firebase-tools + Java 11+ for the emulator)
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
7. Seed the onboarding assessment (`npm run seed` above). Without it,
   `submitAssessment` returns "Avaliação indisponível" and the app shows its
   offline fallback placement.

Never use production payment credentials or production data during
development (spec §21).

## Not yet wired (deliberate MVP cuts)

- Apple/Google native billing providers (interface ready in
  `payments/provider.ts`; see ADR 0002).
- Courses/modules/lessons/activities content: the collections and rules
  exist, but only the assessment is seeded. The app reads the child's
  `currentLessonId` to place them on the journey, yet the lesson ranges and
  the activities themselves are still described in app code.
- Multi-child aggregation for the parent dashboard (gamification is stored
  per child, the app uses a single fixed child id).
- Account deletion / data-retention jobs (LGPD §19 — deletion mechanism must
  land before public launch).
- Achievement and weekly-report notification jobs (sender infra is in place).
- The legal review flagged in §19: this spec is engineering, not legal advice.
