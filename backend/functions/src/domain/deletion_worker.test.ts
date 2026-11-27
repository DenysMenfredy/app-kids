import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  DELETION_PRESERVED_USER_COLLECTIONS,
  DELETION_RETRY_BASE_MS,
  DELETION_RETRY_MAX_MS,
  DELETION_USER_COLLECTIONS,
  DELETION_WORKER_LEASE_MS,
  deletionClaimDecision,
  deletionRetryDelayMs,
} from "./deletion_worker";

const now = 1_800_000_000_000;

function record(overrides = {}) {
  return {
    schemaVersion: 1,
    status: "requested",
    nextAttemptAt: new Date(now - 1),
    ...overrides,
  };
}

describe("deletion worker claim policy", () => {
  it("claims due requested and failed jobs", () => {
    assert.equal(deletionClaimDecision(record(), now), "claim");
    assert.equal(deletionClaimDecision(record({ status: "failed" }), now), "claim");
  });

  it("skips completed, future, leased and missing jobs", () => {
    assert.equal(deletionClaimDecision(null, now), "skip");
    assert.equal(deletionClaimDecision(record({ status: "completed" }), now), "skip");
    assert.equal(deletionClaimDecision(record({
      nextAttemptAt: new Date(now + 1),
    }), now), "skip");
    assert.equal(deletionClaimDecision(record({
      status: "processing",
      leaseExpiresAt: new Date(now + 1),
    }), now), "skip");
  });

  it("reclaims an expired or missing lease", () => {
    assert.equal(deletionClaimDecision(record({
      status: "processing",
      leaseExpiresAt: new Date(now - 1),
    }), now), "claim");
    assert.equal(deletionClaimDecision(record({
      status: "processing",
      leaseExpiresAt: undefined,
    }), now), "claim");
  });

  it("rejects unknown states and does not treat them as due", () => {
    assert.equal(deletionClaimDecision(record({ status: "unknown" }), now), "invalid");
  });

  it("backs off exponentially up to the cap", () => {
    assert.equal(deletionRetryDelayMs(1), DELETION_RETRY_BASE_MS);
    assert.equal(deletionRetryDelayMs(2), DELETION_RETRY_BASE_MS * 2);
    assert.equal(deletionRetryDelayMs(3), DELETION_RETRY_BASE_MS * 4);
    assert.equal(deletionRetryDelayMs(100), DELETION_RETRY_MAX_MS);
  });

  it("keeps the tombstone and financial subscriptions out of the delete list", () => {
    assert.ok(DELETION_USER_COLLECTIONS.includes("children"));
    assert.ok(DELETION_USER_COLLECTIONS.includes("sessions"));
    assert.ok(!(DELETION_USER_COLLECTIONS as readonly string[]).includes("subscriptions"));
    assert.ok(!(DELETION_USER_COLLECTIONS as readonly string[]).includes("deletion"));
    assert.deepEqual(DELETION_PRESERVED_USER_COLLECTIONS, ["subscriptions", "deletion"]);
    assert.ok(DELETION_WORKER_LEASE_MS > 0);
  });
});
