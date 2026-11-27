# ADR 0022 — Account-deletion request, reauthentication and tombstone

Date: 2026-11-27 · Status: accepted; request/tombstone in PR08a, worker in ADR 0023

## Context

T08b is a P0 trust/G1 item: a parent must be able to request account deletion
without letting a stolen or stale session destroy the wrong account, and the
request must immediately stop new child-data collection while the durable
deletion worker runs. D07 (retention periods and the reviewed deletion policy)
is still open, so this ADR defines the mechanism, not a legal deadline.

PR08a covers the request, tombstone and blocking. ADR 0023 / PR08b
covers the durable worker that removes subcollections, Storage objects and the
Auth account and handles late callbacks; restore reapplication remains open.
No user data is deleted by PR08a.

## Decision

1. Add the authenticated, App Check-protected `requestAccountDeletion`
   callable. It accepts only a bounded `requestId`; it never accepts a status,
   UID or deletion timestamp from the client.
2. Require a recent reauthentication. The callable reads `auth_time` from the
   signed ID token and rejects a value older than
   `DELETION_REAUTH_WINDOW_SECONDS` (currently five minutes) or a missing,
   malformed or future-dated value with `failed-precondition` and
   `details.code: "reauth_required"`. The window is a product placeholder, not
   a legal requirement; the client must reauthenticate and refresh its token.
3. Store one server-owned tombstone at `users/{uid}/deletion/current` with:
   - `schemaVersion: 1`;
   - `flowVersion: "t08b-placeholder-v1"` (explicit placeholder);
   - `status: "requested"` (future worker states may be `processing`,
     `completed` or `failed`);
   - `requestId`, `uid`;
   - `reauthenticatedAt` derived from the signed token's `auth_time`;
   - `requestedAt` and `updatedAt`, both server timestamps;
   - `sessionsRevokedAt` once refresh tokens are revoked.
4. Make the request idempotent by effect: a `requested`, `processing` or
   `completed` tombstone is returned unchanged, even if the retry uses a
   different `requestId`; a same-key retry does not create another record. A
   `failed` request may be retried and replaces the tombstone with a new
   `requested` state. Malformed tombstones fail closed with
   `deletion_state_invalid`.
5. Revoke refresh tokens after the tombstone is committed and record
   `sessionsRevokedAt`. If revocation fails, the tombstone still blocks new
   child-data operations; the client retries and the callable retries
   revocation. Existing ID tokens may remain valid until expiry, so the
   server-side tombstone guard, not token expiry, is authoritative.
6. Reuse a single parent guard for child-data callables:
   `requireNoPendingDeletion` runs before `requireCurrentParentConsent`.
   Every existing tombstone blocks, including `failed` and missing/unknown
   status. A failed worker state can be retried but does not reopen the
   account. `createChildProfile`, `submitAssessment`, `startLessonSession`,
   `submitActivityAttempt`, `completeLesson`, `updateLessonSession`,
   `updateProgress` and `saveBookBookmark` return `failed-precondition` with
   `details.code: "account_deletion_pending"` while deletion is pending.
7. Firestore Rules make the tombstone read-only to its owner and block client
   writes. Child-profile updates require a current consent and no pending
   deletion; `users/{uid}` and notification-preference writes are also blocked
   while deletion is pending. Reads of the family's own data remain available;
   no client write can recreate or bypass the tombstone.
8. No legal retention period is invented. `sessionsRevokedAt` records when
   sessions were closed; a future `retentionDueAt` or equivalent must come from
   the D07 matrix. ADR 0023 owns deletion of subcollections, Storage and Auth,
   plus late-callback guards; restore reapplication remains open.

## Consequences and remaining gates

- **D07 dependency:** retention/deletion deadlines, consent withdrawal wording
  and the reviewed policy remain open. The flow version and reauthentication
  window are explicitly placeholders and must be revisited before G1/G2
  acceptance.
- **App integration:** PR09 (or a follow-up before PR08b) must add the
  reauthentication prompt, call `requestAccountDeletion`, show the pending
  state and handle `reauth_required`/`session_revocation_failed`. A client that
  does not send a recent token gets a typed rejection; no silent fallback.
- **Worker dependency:** the ADR 0023 worker now deletes locally; before
  its deploy, the tombstone blocks but does not delete data. The status can
  stay `requested`; operators must not claim deletion is complete from this
  record alone.
- **Failure mode:** if `revokeRefreshTokens` fails, the callable returns
  `internal` after writing the tombstone. The request is not lost, and the
  guard still blocks child data; retry is safe and idempotent.
- **Not covered:** account deletion for a parent with shared/legacy Apple
  credentials, retention exports, legal holds, billing records, and the actual
  cascade/restore rehearsal remain future work and D07.
