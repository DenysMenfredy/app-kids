# ADR 0006 — Learning placement and completion cannot be written by clients

Date: 2026-10-07 · Status: accepted

## Context

ADR 0003 puts placement, XP, coins and streak under backend authority. The
old Firestore rules still permitted a parent client to set
`children/{childId}.learningLevel/currentCourseId/currentLessonId` and to
create `learningProgress`, `activityAttempts` and `sessions`. The client
also could call `completeLesson` with a new, nonexistent lesson ID; the
idempotency key was unique, so this minted a fresh reward.

## Decision

- A parent may create or edit only child profile fields (`name`, `birthDate`,
  `age`, `avatarId`, `updatedAt`). Placement and journey fields are written
  by `submitAssessment` and `completeLesson`. A merge may preserve them but
  never add, remove or change them.
- `learningProgress`, `activityAttempts` and `sessions` are read-only to
  clients. Their writers are trusted functions. Child deletion is held for
  the backend lifecycle flow so delete/recreate cannot orphan or recycle
  server-owned learning state.
- `users/{uid}.email` and `createdAt` are server-owned. Client profile
  creation and updates may touch only the approved mutable fields.
- `completeLesson` must see an existing published lesson in the child's
  course, and it must be the child's current lesson or one this child has
  already completed. The transaction rechecks lesson and child state before
  granting. The next lesson query is scoped to the same course.
- `updateProgress` must target the child's current published lesson and runs
  transactionally with the progress read. A completed state is terminal;
  clients cannot reset it to make the completion reward eligible again.
- A lesson run starts through `startLessonSession`, which checks the child's
  current journey and snapshots the four published activity IDs from the
  lesson manifest. Clients cannot create or mutate session documents.
- `submitActivityAttempt` checks session ownership, lesson membership and
  publication, then scores tap/listen options and match pairs against the
  published activity document. Request IDs deduplicate retries, successful
  match pairs count once, and each activity has a bounded attempt count.
- `completeLesson` requires all four activities in that session to be
  complete. It derives duration, score and answer counts from the server-owned
  session, and ignores any similarly named fields supplied by the client.
  Reward and progression remain in the same idempotent transaction.
- Trace intentionally stores no handwriting paths. Its bounded stroke count,
  point count and elapsed time establish that gesture-shaped input was
  reported, but cannot prove that a child traced the glyph accurately; this
  limitation must remain explicit until a privacy-reviewed validation method
  is selected.

## Rollout and remaining work

The current Flutter client writes only profile fields directly and uses
callables for learning. Rule deployment must still be coordinated with any
older installed clients; no deployment is implied by this ADR. The
`primary` child migration and account deletion need their own backend
flows before the multiple-child beta.

This closes the local implementation gap for T03's reward evidence and adds
the core T15 session/attempt contract. Emulator integration, concurrency and
retry checks, staging rollout, versioned content migration, and physical-device
validation remain required. Trace metadata is not equivalent to handwriting
recognition. Do not declare G1 or commercial release complete from the local
unit tests alone.

Rules tests cover create, merge, replacement, deletion and cross-account
reads. The emulator smoke script exercises a forged placement and an
invented lesson in the end-to-end path.
