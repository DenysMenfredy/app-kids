# ADR 0023 — Durable account-deletion worker

Date: 2026-11-27 · Status: accepted; worker implemented locally, D07 retention open

## Context

ADR 0022 records the deletion request and tombstone but deliberately deletes no
data. T08b still needs a durable worker that can resume after a crash, retry
with backoff, remove explicit user/child data, Storage objects and the Auth
account, and prevent late payment callbacks from recreating a closed account.
D07 (retention and the reviewed deletion policy) remains open, so no legal
deadline is inferred here.

## Decision

1. Run a scheduled sweep every 15 minutes over collection-group tombstones in
   `requested`, `failed` or `processing`. It reads at most 50 candidates per
   invocation and processes them one at a time; one failed job does not abort
   the batch.
2. Claim one tombstone in a Firestore transaction before doing any deletion:
   - set `status: "processing"`, increment `attempts`, write a random
     `workerClaim`, `processingStartedAt` and a 10-minute `leaseExpiresAt`;
   - set `nextAttemptAt` to the lease expiry so a crashed worker becomes due
     again after the lease expires;
   - skip a completed job, a job whose `nextAttemptAt` is in the future, or a
     live lease. A malformed/unknown state is not processed.
   - Completion and failure updates check `workerClaim`, so an old worker
     cannot overwrite a newer claim.
3. Delete only explicit user-data collections:
   `children` (including daily summaries/bookmarks), `childCreationRequests`,
   `devices`, `entitlements`, `notifications`, `notificationPreferences`,
   `learningProgress`, `activityAttempts`, `sessions`, `gamification`,
   `assessmentResults` and `consent`. Delete the `billing/trial` document, the
   user document, objects under the Storage prefix `users/{uid}/`, and the Auth
   account. `auth/user-not-found` is success, so a retry after a partial Auth
   deletion converges.
4. Preserve the `deletion` tombstone and `subscriptions` subcollection. The
   tombstone stays after completion so late callbacks fail closed; the
   subscription records and top-level `stripeCustomers` /
   `stripeCheckoutSessions` mappings are the minimal financial reconciliation
   placeholder. The completed tombstone records
   `financialRetention: "d07-financial-placeholder-v1"`; no retention period is
   invented. D07 must decide whether to shorten, export or delete these records
   later.
5. Guard late writers:
   - `stripeWebhook` skips checkout/subscription events once the tombstone
     blocks, before trial or subscription writes;
   - `consumeTrialEligibility`, `releaseTrialReservation`,
     `refreshTrialReservation` and `claimTrialForCheckout` skip when the
     tombstone blocks;
   - `upsertSubscription` and `syncEntitlementForUser` skip, so a late Stripe
     event cannot recreate subscriptions/entitlements;
   - `registerDevice`/`unregisterDevice`, `createCustomerPortal` and
     `recordParentConsent` reject new operations with
     `account_deletion_pending`;
   - existing top-level financial mappings are preserved, but a late event
     that resolves a closed account is skipped before writing; it cannot
     recreate the user document, child data or Auth account.
6. Status transitions are `requested → processing → completed` or
   `→ failed → processing` on retry. A `failed` job remains closed to new
   operations while it waits for retry; only the worker reopens processing.
   A failed job stores `lastErrorCode` (no raw provider/error payload) and
   `nextAttemptAt` from exponential backoff:
   5 minutes base, doubling, capped at 6 hours. `attempts` is incremented per
   claim. The worker logs only job counts, status and error codes — no email,
   child data, tokens or raw provider payloads.
7. The sweep needs Cloud Scheduler and the collection-group index on
   `deletion.status`. No cloud deploy is performed by this change; the worker
   is exercised locally against the emulators.

## Consequences and remaining gates

- **D07 dependency:** financial retention, legal deletion deadlines and the
  reviewed retention matrix remain open. The placeholder only says "keep the
  minimum for reconciliation"; it is not a policy.
- **PR08b edges:** restore reapplication, dead-letter/manual repair tooling and
  legal export are not implemented. A permanently failing job remains
  `failed` with backoff and its error code; operators must inspect it.
- **Storage:** the MVP has no user uploads (content assets only), but the
  worker deletes the `users/{uid}/` prefix for future uploads. A missing
  bucket fails the job and retries rather than silently claiming completion.
- **Top-level maps:** `stripeCustomers` and `stripeCheckoutSessions` are not
  deleted. They contain UID/customer/session identifiers, not child data; D07
  may add a financial export/cleanup step.
- **Auth:** deleting the Auth account does not invalidate already-issued ID
  tokens before expiry. The tombstone guard is authoritative and remains
  readable by the worker; that is why it is not deleted on completion.
- **Testing:** domain tests cover claims/backoff/collection lists; the
  emulator smoke covers explicit collections, Storage, Auth, financial
  preservation, late entitlement/trial guards and failed-job retry.
