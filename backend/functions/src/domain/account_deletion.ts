/**
 * Account-deletion request state (T08b, part 1).
 *
 * D07 (retention periods and the reviewed deletion policy) is still open.
 * `DELETION_FLOW_VERSION` is an explicit placeholder for the flow revision,
 * not a legal deadline. PR08a records the request and blocks new child-data
 * operations; the durable deletion worker is PR08b.
 */

export const DELETION_FLOW_VERSION = "t08b-placeholder-v1";

/** A reauthentication older than this is rejected. Product placeholder, not law. */
export const DELETION_REAUTH_WINDOW_SECONDS = 5 * 60;

export const DELETION_STATUSES = [
  "requested",
  "processing",
  "completed",
  "failed",
] as const;
export type AccountDeletionStatus = (typeof DELETION_STATUSES)[number];

export interface AccountDeletionRequestInput {
  requestId: string;
}

export interface ReauthRefusal {
  code: "reauth_required";
  maxAgeSeconds: number;
}

export type DeletionRequestDecision =
  | { kind: "create" }
  | { kind: "retry" }
  | { kind: "existing"; status: AccountDeletionStatus; requestId: string }
  | { kind: "invalid" };

export function isAccountDeletionStatus(value: unknown): value is AccountDeletionStatus {
  return typeof value === "string" &&
    (DELETION_STATUSES as readonly string[]).includes(value);
}

/** Validates the callable payload without accepting client-supplied state. */
export function parseAccountDeletionRequest(value: unknown): AccountDeletionRequestInput | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return null;
  const data = value as Record<string, unknown>;
  if (Object.keys(data).length !== 1 || !("requestId" in data)) return null;
  if (typeof data.requestId !== "string" ||
      !/^[A-Za-z0-9_-]{1,80}$/.test(data.requestId)) {
    return null;
  }
  return { requestId: data.requestId };
}

/**
 * `auth_time` is a Firebase token claim in seconds. A missing, future-dated or
 * older value is refused; the client must reauthenticate and refresh the token.
 */
export function reauthRefusal(
  authTimeSeconds: unknown,
  nowSeconds: number,
  windowSeconds = DELETION_REAUTH_WINDOW_SECONDS,
): ReauthRefusal | null {
  const refusal = { code: "reauth_required" as const, maxAgeSeconds: windowSeconds };
  if (typeof authTimeSeconds !== "number" || !Number.isFinite(authTimeSeconds) ||
      authTimeSeconds <= 0) {
    return refusal;
  }
  const age = nowSeconds - authTimeSeconds;
  if (age < 0 || age > windowSeconds) return refusal;
  return null;
}

/**
 * Any tombstone except a retryable `failed` state blocks child-data writes.
 * Missing or malformed status also fails closed: absence of a valid status is
 * not evidence that deletion is over.
 */
export function deletionBlocksOperations(status: unknown): boolean {
  return status !== "failed";
}

/**
 * Decides what a new request means for an existing tombstone. A pending or
 * completed request is returned as-is (idempotent effect); a failed request can
 * be retried; malformed state is rejected rather than overwritten.
 */
export function deletionRequestDecision(
  record: Record<string, unknown> | null | undefined,
  uid: string,
): DeletionRequestDecision {
  if (!record) return { kind: "create" };
  if (record.schemaVersion !== 1 || record.uid !== uid) return { kind: "invalid" };
  if (record.status === "failed") return { kind: "retry" };
  if (!isAccountDeletionStatus(record.status)) return { kind: "invalid" };
  if (typeof record.requestId !== "string" || record.requestId.length === 0) {
    return { kind: "invalid" };
  }
  return { kind: "existing", status: record.status, requestId: record.requestId };
}
