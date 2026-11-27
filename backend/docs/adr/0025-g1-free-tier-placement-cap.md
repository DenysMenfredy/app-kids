# ADR 0025 — G1 free-tier placement cap

Date: 2026-11-27 · Status: accepted; temporary G1 rule while billing is disabled

## Context

With billing disabled, a parent cannot obtain a current `full_curriculum`
entitlement. An assessment can still place a child in module 2 or later, whose
first lesson `startLessonSession` denies without that entitlement. The child
then has no accessible lesson — a dead-end in the first-session flow.

## Decision

1. `submitAssessment` keeps scoring and the requested placement server-side, then
   reads the same entitlement authority used by lesson start
   (`canAccessModuleForUser` → `canAccessModule`). Module 1 remains free; a
   later module requires an active `full_curriculum` entitlement with a current
   `validFrom`/`validUntil`.
2. When the requested band is above module 1 and that authority denies access,
   persist and return the free module's placement instead. The free
   `firstLessonId` comes from the published module 1 document, falling back to
   the assessment's module-1 rule. The child's `currentLessonId` is written to
   that lesson, so the next screen can start it.
3. Return `freeTierCapped: true` and `requestedModuleNumber` alongside the
   capped `placement`; store both in `assessmentResults` for audit. A premium
   parent or a free module-1 band returns `freeTierCapped: false`. The client
   never chooses the band or the cap.
4. The cap is a **temporary G1 rule while billing is off**. Remove or replace it
   when native billing and server-verified entitlement activation are enabled
   and the G1 paywall/entitlement flow is live. It must not be removed merely to
   make a client build pass.
5. Add an emulator-only repair pass for already-affected children. It detects
   a child whose `currentLessonId` belongs to a published module above 1 while
   the parent has no current `full_curriculum` entitlement, and changes **only**
   `currentCourseId`/`currentLessonId` to module 1's first lesson. It preserves
   `learningLevel`, learning progress, sessions, attempts, rewards, assessment
   results and bookmarks. Previous pointers are stored per child in the
   server-owned `users/{uid}/migrations/moduleOneRepair` document, so rollback
   can restore them. The tool is idempotent, dry-run by default and reports
   aggregate counts; no remote data is touched.
6. Rollback restores only the recorded pointers and removes the repair document.
   It assumes the child has not advanced since the repair; after a real cutover,
   use a verified export instead.

## Consequences and remaining gates

- **No dead-end in the new flow:** a free high score lands on module 1's first
  lesson and can start a session; an active premium entitlement keeps the
  original band.
- **Existing placements:** the local repair pass now exists; a staging/production
  run still requires owner authorization and an export. Fixture counts and
  rollback are recorded in the PR evidence.
- **Billing dependency:** the cap stays until native-store purchase,
  server-side verification and entitlement activation are real. The exact
  removal point is the G1 billing enablement decision, not a date invented here.
- **Tests:** domain tier-placement tests plus emulator smokes with free,
  active-premium and expired-premium synthetic families, and the repair/rollback
  fixture pass.
