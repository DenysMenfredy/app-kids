import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { canAccessModule } from "./content_access";

const now = new Date("2026-10-07T12:00:00Z");
const active = {
  active: true,
  features: ["full_curriculum"],
  validFrom: new Date("2026-10-01T00:00:00Z"),
  validUntil: new Date("2026-11-01T00:00:00Z"),
};

describe("free and Premium content access", () => {
  it("keeps the complete first module free without entitlement", () => {
    assert.equal(canAccessModule(1, null, now), true);
  });

  it("denies Premium modules without an active full-curriculum entitlement", () => {
    assert.equal(canAccessModule(2, null, now), false);
    assert.equal(canAccessModule(2, { ...active, active: false }, now), false);
    assert.equal(canAccessModule(2, { ...active, features: [] }, now), false);
  });

  it("grants access only within the entitlement validity window", () => {
    assert.equal(canAccessModule(2, active, now), true);
    assert.equal(canAccessModule(2, {
      ...active,
      validFrom: new Date("2026-10-08T00:00:00Z"),
    }, now), false);
    assert.equal(canAccessModule(2, {
      ...active,
      validUntil: now,
    }, now), false);
  });

  it("fails closed for malformed or unknown module metadata", () => {
    assert.equal(canAccessModule("2", active, now), false);
    assert.equal(canAccessModule(0, active, now), false);
    assert.equal(canAccessModule(3, {
      active: true,
      features: ["premium_books"],
      validFrom: active.validFrom,
      validUntil: active.validUntil,
    }, now), false);
  });
});
