import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { isKnownPlan, PLANS } from "./plans";

describe("plan catalog", () => {
  it("matches founder pricing in integer cents (spec §7)", () => {
    assert.equal(PLANS.founder_monthly.amountCents, 1990);
    assert.equal(PLANS.founder_quarterly.amountCents, 4990);
    assert.equal(PLANS.founder_annual.amountCents, 14990);
  });

  it("prices everything in BRL", () => {
    for (const plan of Object.values(PLANS)) {
      assert.equal(plan.currency, "BRL");
      assert.ok(Number.isInteger(plan.amountCents));
    }
  });

  it("rejects unknown plan ids", () => {
    assert.equal(isKnownPlan("founder_annual"), true);
    assert.equal(isKnownPlan("free_forever"), false);
    assert.equal(isKnownPlan(""), false);
  });
});
