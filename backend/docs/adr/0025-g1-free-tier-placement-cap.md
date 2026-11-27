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
5. This fixes new submissions. Children already stored above module 1 without a
   current entitlement are not rewritten by this change; they need a repair or
   re-assessment before release. No remote data is touched.

## Consequences and remaining gates

- **No dead-end in the new flow:** a free high score lands on module 1's first
  lesson and can start a session; an active premium entitlement keeps the
  original band.
- **Existing placements:** a one-time repair/backfill for previously misplaced
  children is still required; it is separate from this P0.
- **Billing dependency:** the cap stays until native-store purchase,
  server-side verification and entitlement activation are real. The exact
  removal point is the G1 billing enablement decision, not a date invented here.
- **Tests:** domain tier-placement tests plus an emulator smoke with free,
  active-premium and expired-premium synthetic families.
