import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  DELETION_FLOW_VERSION,
  DELETION_REAUTH_WINDOW_SECONDS,
  deletionBlocksOperations,
  deletionRequestDecision,
  parseAccountDeletionRequest,
  reauthRefusal,
} from "./account_deletion";

const uid = "parent_uid";
const record = {
  schemaVersion: 1,
  flowVersion: DELETION_FLOW_VERSION,
  status: "requested",
  requestId: "request_123",
  uid,
  requestedAt: new Date(),
  updatedAt: new Date(),
};

describe("account-deletion request input", () => {
  it("accepts one bounded requestId", () => {
    assert.deepEqual(parseAccountDeletionRequest({ requestId: "request_123" }), {
      requestId: "request_123",
    });
  });

  it("rejects missing, malformed or client-supplied state", () => {
    for (const value of [
      null,
      {},
      { requestId: "" },
      { requestId: "has spaces" },
      { requestId: "x".repeat(81) },
      { requestId: "ok", status: "completed" },
      { requestId: "ok", uid: "attacker" },
    ]) {
      assert.equal(parseAccountDeletionRequest(value), null);
    }
  });
});

describe("reauthentication window", () => {
  const now = 1_800_000_000;

  it("accepts a token authenticated inside the window", () => {
    assert.equal(reauthRefusal(now - 60, now), null);
    assert.equal(reauthRefusal(now, now), null);
  });

  it("rejects an old, missing, invalid or future auth_time", () => {
    for (const authTime of [
      now - DELETION_REAUTH_WINDOW_SECONDS - 1,
      undefined,
      null,
      "1800000000",
      Number.NaN,
      now + 1,
    ]) {
      assert.deepEqual(reauthRefusal(authTime, now), {
        code: "reauth_required",
        maxAgeSeconds: DELETION_REAUTH_WINDOW_SECONDS,
      });
    }
  });
});

describe("deletion tombstone blocking", () => {
  it("blocks every existing tombstone, including failed and malformed ones", () => {
    for (const status of ["requested", "processing", "completed", "failed", "unknown", undefined]) {
      assert.equal(deletionBlocksOperations(status), true);
    }
  });

  it("creates, retries, returns or rejects a request idempotently", () => {
    assert.deepEqual(deletionRequestDecision(null, uid), { kind: "create" });
    assert.deepEqual(deletionRequestDecision(record, uid), {
      kind: "existing",
      status: "requested",
      requestId: "request_123",
    });
    assert.deepEqual(deletionRequestDecision({ ...record, status: "failed" }, uid), {
      kind: "retry",
    });
  });

  it("fails closed for malformed or crossed tombstones", () => {
    for (const value of [
      { ...record, schemaVersion: 2 },
      { ...record, uid: "someone_else" },
      { ...record, status: "unknown" },
      { ...record, requestId: undefined },
    ]) {
      assert.deepEqual(deletionRequestDecision(value, uid), { kind: "invalid" });
    }
  });
});
