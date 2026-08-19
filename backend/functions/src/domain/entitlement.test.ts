import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { deriveEntitlement, PREMIUM_FEATURES } from "./entitlement";
import { fromStripeStatus, Subscription } from "./subscription";

const NOW = new Date("2026-08-18T12:00:00Z");

function subscription(overrides: Partial<Subscription> = {}): Subscription {
  return {
    provider: "stripe",
    providerCustomerId: "cus_123",
    providerSubscriptionId: "sub_123",
    planId: "founder_annual",
    status: "active",
    currency: "BRL",
    amountCents: 14990,
    interval: "year",
    currentPeriodStart: new Date("2026-08-01T00:00:00Z"),
    currentPeriodEnd: new Date("2027-08-01T00:00:00Z"),
    cancelAtPeriodEnd: false,
    ...overrides,
  };
}

describe("deriveEntitlement", () => {
  it("grants premium for an active subscription inside its period", () => {
    const ent = deriveEntitlement(subscription(), NOW);
    assert.equal(ent.active, true);
    assert.equal(ent.source, "stripe");
    assert.equal(ent.plan, "founder_annual");
    assert.deepEqual(ent.features, [...PREMIUM_FEATURES]);
    assert.deepEqual(ent.validUntil, new Date("2027-08-01T00:00:00Z"));
  });

  it("grants premium during trials", () => {
    const ent = deriveEntitlement(subscription({ status: "trialing" }), NOW);
    assert.equal(ent.active, true);
  });

  it("keeps access in past_due grace until the period ends", () => {
    const ent = deriveEntitlement(subscription({ status: "past_due" }), NOW);
    assert.equal(ent.active, true);
  });

  it("keeps access after cancellation until the paid period expires", () => {
    const ent = deriveEntitlement(
      subscription({ status: "canceled", cancelAtPeriodEnd: true }),
      NOW,
    );
    assert.equal(ent.active, true);
  });

  it("revokes access once the period has expired, regardless of status", () => {
    const ent = deriveEntitlement(
      subscription({ currentPeriodEnd: new Date("2026-08-17T00:00:00Z") }),
      NOW,
    );
    assert.equal(ent.active, false);
    assert.deepEqual(ent.features, []);
  });

  it("revokes access for expired status", () => {
    const ent = deriveEntitlement(subscription({ status: "expired" }), NOW);
    assert.equal(ent.active, false);
  });

  it("fails safely with no subscription at all", () => {
    const ent = deriveEntitlement(null, NOW);
    assert.equal(ent.active, false);
    assert.equal(ent.source, "none");
    assert.equal(ent.plan, null);
  });
});

describe("fromStripeStatus", () => {
  it("maps known statuses", () => {
    assert.equal(fromStripeStatus("active"), "active");
    assert.equal(fromStripeStatus("trialing"), "trialing");
    assert.equal(fromStripeStatus("past_due"), "past_due");
    assert.equal(fromStripeStatus("canceled"), "canceled");
  });

  it("maps unknown or failure statuses to expired (fail safe)", () => {
    assert.equal(fromStripeStatus("incomplete"), "expired");
    assert.equal(fromStripeStatus("unpaid"), "expired");
    assert.equal(fromStripeStatus("banana"), "expired");
  });
});
