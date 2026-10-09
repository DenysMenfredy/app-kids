# ADR 0013 — Server-bounded active time and per-child daily summaries

Date: 2026-10-09 · Status: accepted for local implementation; staging gate open

## Decision

The existing server-owned session/attempt contract remains the source of truth.
New sessions also enforce the manifest's activity order server-side; all match
pairs must finish before advancing. Retries of previous activities do not move
the cursor backward. Existing sessions without the sequence version retain
their previous contract during rollout.
`updateLessonSession` accepts ordered heartbeat, pause, resume and abandon
commands from the authenticated parent. It verifies the child and session,
and rechecks publication and current entitlement on heartbeat/resume. Retried
or delayed sequence numbers cannot accrue time twice or undo a newer command.

Flutter sends presence every 15 seconds while a lesson is in the foreground,
pauses on lifecycle changes, and abandons a run when leaving its routes. The
backend credits at most 30 seconds between accepted signals and at most 30
minutes per session. A pause/resume excludes the paused interval. Missing
signals, process termination and network failure can undercount time; presence
is not proof of attention. No client duration is accepted as authoritative.

Time uses the IANA timezone captured from the parent at session creation.
Credited intervals split exactly at local midnight. Changing the parent's
timezone affects future sessions; historical calendar buckets are retained.
Older sessions without timing evidence receive no guessed active-time backfill.

Completing a session atomically materializes its contribution once into
`users/{uid}/children/{childId}/dailySummaries/{localDate}`. The same transaction
records completion and grants the first child/lesson reward. Concurrent requests
and retries cannot duplicate a contribution. New replay sessions contribute
practice time and answers but never another new lesson or reward. First
completion timestamps remain stable across replay and retries.

The weekly window is Monday through Sunday in the parent's current timezone.
Practice time sums credited intervals for completed sessions. New lessons count
first-ever child/lesson completions, on the session's completion date. Attempts
and correct answers are attributed to that completion date; weekly accuracy is
`sum(correctAnswers) / sum(attempts)`, never an average of daily percentages.
The initial daily goal is one new lesson. Trace correctness retains ADR 0006's
limited gesture interpretation. Incomplete/abandoned sessions do not appear in
the completed-practice chart. Clients cannot write summaries; the read callable
and Rules require the authenticated parent and an existing child.

## Remaining gates

Staging/device lifecycle validation, a published content-version contract,
durable cold-process exercise resumption and a migration of older session
contracts remain open under T15. No staging deployment, backup restore or
physical-device validation is implied by local tests. D04–D07 stay undecided;
this change does not activate analytics collection or a deletion policy.

## Rollout and rollback

Deploy the Functions and Rules to staging before the new Flutter client, then
verify summary reads and lifecycle commands with old and new clients. Older
clients remain usable but cannot report foreground heartbeats, so their measured
time may be lower. The new client shows a retry state if the read callable is
unavailable. A client rollback should retain the compatible backend endpoints,
session guards and recorded summaries; do not remove summary documents or undo
already-issued rewards. Backend defects require a compatible correction that
preserves completed-session idempotency. No historical migration or production
deployment was performed during local implementation.
