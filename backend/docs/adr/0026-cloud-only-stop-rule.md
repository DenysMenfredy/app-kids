# ADR 0026 — Cloud-only stop rule

Date: 2026-11-27. Status: accepted by the founder/CEO.

## Context

The engineering scope required to publish the MVP is nearly complete. The
remaining blockers are the cloud environment (Blaze, remote Firestore/Storage,
Workload Identity, GitHub Environment, App Check release registration and the
first deploy) and owner items (D07/legal texts, physical device, Play Console).
Without a stop rule, the team could start G2/G3 or invent cloud work before the
owner authorizes it.

## Decision

When all engineering required for publication is complete with evidence and no
P0/P1 engineering issue is open, and the only remaining blocker is the cloud
environment, engineering stops:

1. No new PRs, features, refactors or cloud/billing/store setup.
2. Leave `main` green and no half-finished work; close or freeze WIP.
3. Produce a handoff with what is ready, evidence, what cloud is missing,
   commands/runbook, risks and rollback.
4. Report to the CEO and wait for explicit authorization before any cloud
   action.

The same applies when the only remaining items are owner-owned (D07/legal
texts, physical device, Play Console): stop and wait. When in doubt, ask the
CEO before advancing.

## Current application (2026-11-27)

- G1 local engineering scope is complete; T08 is complete.
- The only engineering item remaining is the repair of children stored above
  module 1 without an active entitlement (ADR 0025).
- After that repair is merged and verified, the trigger is reached: cloud,
  App Check release, physical device, D07 and Play Console remain, and
  engineering stops. No G2/G3 starts.

## Consequences

- The team does not start G2/G3 or cloud work without explicit CEO
  authorization.
- The handoff becomes the source of truth for resuming.
- A new engineering task requires a new explicit decision; it is not implied by
  an owner dependency.
