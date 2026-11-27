/**
 * Durable account-deletion worker policy (T08b, part 2).
 *
 * The tombstone is the source of truth. A worker takes a short lease, performs
 * an idempotent sequence of deletions and either completes or records a
 * retryable failure. No legal retention period is invented; the financial
 * preservation marker is an explicit D07 placeholder.
 */

export const DELETION_WORKER_LEASE_MS = 10 * 60 * 1000;
export const DELETION_RETRY_BASE_MS = 5 * 60 * 1000;
export const DELETION_RETRY_MAX_MS = 6 * 60 * 60 * 1000;

/**
 * Explicit user-data subcollections. `subscriptions` and `deletion` are
 * intentionally absent: the tombstone is the late-callback fence, and
 * subscription records are the minimal financial placeholder pending D07.
 */
export const DELETION_USER_COLLECTIONS = [
  "children",
  "childCreationRequests",
  "devices",
  "entitlements",
  "notifications",
  "notificationPreferences",
  "learningProgress",
  "activityAttempts",
  "sessions",
  "gamification",
  "assessmentResults",
  "consent",
] as const;

export const DELETION_PRESERVED_USER_COLLECTIONS = [
  "subscriptions",
  "deletion",
] as const;

export const FINANCIAL_RETENTION_PLACEHOLDER = "d07-financial-placeholder-v1";

export type DeletionClaimDecision = "claim" | "skip" | "invalid";

function timestampMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (value && typeof value === "object") {
    const toMillis = (value as { toMillis?: unknown }).toMillis;
    if (typeof toMillis === "function") {
      const result = toMillis.call(value);
      return typeof result === "number" && Number.isFinite(result) ? result : null;
    }
  }
  return null;
}

/**
 * A requested/failed job is due when it has no nextAttemptAt or that time has
 * passed. A processing job is resumable only after its lease expired; a
 * malformed/unknown status is not silently processed.
 */
export function deletionClaimDecision(
  record: Record<string, unknown> | null | undefined,
  nowMillis: number,
): DeletionClaimDecision {
  if (!record) return "skip";
  if (record.status === "completed") return "skip";
  if (record.status !== "requested" &&
      record.status !== "failed" &&
      record.status !== "processing") {
    return "invalid";
  }

  const nextAttempt = timestampMillis(record.nextAttemptAt);
  if (nextAttempt !== null && nextAttempt > nowMillis) return "skip";

  if (record.status === "processing") {
    const leaseExpiry = timestampMillis(record.leaseExpiresAt);
    if (leaseExpiry !== null && leaseExpiry > nowMillis) return "skip";
  }
  return "claim";
}

/** Exponential backoff with a cap; `attempts` starts at 1 after a claim. */
export function deletionRetryDelayMs(attempts: number): number {
  const exponent = Math.max(1, Math.floor(attempts)) - 1;
  return Math.min(
    DELETION_RETRY_BASE_MS * 2 ** exponent,
    DELETION_RETRY_MAX_MS,
  );
}
