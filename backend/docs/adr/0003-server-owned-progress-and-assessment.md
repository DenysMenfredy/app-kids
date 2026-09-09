# ADR 0003 — Server-owned gamification and assessment placement

Date: 2026-09-09 · Status: accepted

## Context

The MVP shipped with the child's XP, coins and daily streak computed and
stored on the device, and with the assessment questions and their placement
outcome hardcoded in the Flutter app. Both are product state that parents
will eventually see in progress reports and that Premium messaging leans on,
so neither can stay client-authoritative:

- On-device rewards can be edited or replayed, and they don't survive a
  reinstall or a second device.
- A hardcoded assessment cannot be tuned without an app release, and a
  client-chosen placement lets the app pick its own starting module.

Spec §22 constraint 1 forbids trusting the client for authorization-adjacent
state, §5 requires content to be configuration-driven, and §16 places
"validated learning updates" on the controlled side of the boundary.

## Decision

1. **Assessment content lives in Firestore** under `assessments/{id}`:
   questions, option labels, per-option weights and placement bands. It is
   readable by authenticated clients when `published`, writable only through
   `manageContent`. The app renders labels; it never sees a decision rule it
   could apply itself.
2. **Placement is scored server-side.** `submitAssessment` receives only
   `{questionId: optionId}` pairs, looks the weights up in the stored
   document, derives the band, writes `learningLevel` / `currentCourseId` /
   `currentLessonId` onto the child, and records the full result in
   `users/{uid}/assessmentResults/{childId}` (client-read-only).
3. **XP, coins and streak are server-owned** in
   `users/{uid}/gamification/{childId}` (client-read-only). `completeLesson`
   applies the reward inside a transaction that first checks whether that
   lesson was already completed, so replays refresh the stats but never mint
   currency twice. Streaks are evaluated in the child's local calendar using
   the profile timezone.

## Consequences

- Two new client-read-only collections; Security Rules and their tests cover
  both the read and the denied write.
- Reward and placement policy are pure functions (`domain/gamification.ts`,
  `domain/assessment.ts`), unit-tested without Firebase.
- Tuning thresholds or reward amounts is a content/config change, not an app
  release. `backend/seed/` holds the dev import of the MVP assessment.
- The app keeps a local fallback for offline/demo mode, but in Firebase mode
  the backend values win: the client displays what it is told.
- Not covered yet: retroactive migration of locally-accrued XP (fresh
  accounts start at zero), and multi-child gamification aggregation for the
  parent dashboard.
