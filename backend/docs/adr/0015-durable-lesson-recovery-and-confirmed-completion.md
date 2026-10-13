# ADR 0015 — Durable lesson recovery and confirmed completion

Date: 2026-10-13 · Status: accepted

## Context

T15 requires network retries, pause/return and completion without duplicated
time or rewards. The previous client discarded attempts after three failed
sends, lost its session on process exit and treated a three-second completion
timeout as a lesson finished without reward deltas. Story completion already
avoided false confirmation, but reopening started the exercises again.

## Decision

1. Persist a start request key before calling `startLessonSession`. The backend
   derives a stable session reference inside the authenticated parent's session
   collection and creates it transactionally. Reusing a key for another child,
   lesson or revision is rejected. Retries recheck content, access and journey;
   an expired or abandoned run needs a new key. Older clients may omit it.
2. Keep one pending run per `(uid, childId)` on the device: lesson/revision,
   session reference, request keys, lifecycle sequence and bounded unsent
   answer evidence. Persist before sending; remove an answer only after an
   acknowledgement. Three transient retries exhaust the current send, not
   the durable queue. Permanent rejection does not trigger automatic retries.
3. The local pointer grants no access or completion. `recoverLessonSession`
   requires Auth/App Check, validates parent/child/session/lesson ownership,
   publication, fingerprint, current entitlement and journey, and rejects
   abandoned or older-than-24-hour runs. It derives the unfinished exercise
   and completed pairs/questions exclusively from server-scored progress.
4. Recovery sets active presence to the server's current time without crediting
   the gap since the last process. Ordered lifecycle commands remain monotonic.
   The existing bounded active-time calculation and reward/summary transaction
   continue to own learning totals.
5. Reopening the intro offers continuation or explicit restart. Continuation
   restores confirmed matching pairs/story questions and server answer counts;
   an unfinished drawing or story-reading page restarts that exercise's UI.
   Content is loaded online again. Expired, changed or inaccessible content
   cannot be resumed; the parent can discard the pointer and return to the
   current journey. Restart abandons the old run and uses a fresh key.
6. Completion drains persisted evidence before calling `completeLesson`.
   Both ordinary and story lessons offer save retry when confirmation fails.
   Only a confirmed response advances demo progress or opens the reward screen.
   If a committed response was lost, retry confirms the existing completion
   with current totals and no second reward.
7. Retry data contains no child name, full protected payload or raw trace
   points. Response keys/types and size are bounded (500 pending responses,
   250,000 serialized characters). The local cache expires after 24 hours,
   matching the existing resumable session window. Logout removes that owner's
   pointers; a disposed/changed-owner service cannot apply late responses or
   recreate cleared retry data. Other owners' namespaces stay isolated.

## Consequences and validation

This adds no client authority and no direct Firestore write permission. The
existing parent-scoped session/attempt collections remain the single source
of truth; no second child-session collection is introduced. Deploy the new
callable before releasing its client. The single local pointer does not promise
cross-device resumption, precise drawing/page restoration or encrypted offline
content distribution.

Client regression coverage includes lost start/answer/completion responses,
process reconstruction with stable keys, late responses after logout, bounded
cache data, matching restoration, story-question restoration and save retry
on 320×568 and 390×844 screens. Demo-emulator integration covers transactional
start deduplication, ownership/key collisions, partial recovery, no offline-time
credit, expired/abandoned denial, current Premium and edited-content rejection.

Staging rollout and physical-device kill/background/foreground checks remain
release gates. This local retry-cache lifetime is a technical session limit;
it does not resolve D07's reviewed backend retention/deletion/consent policy.
