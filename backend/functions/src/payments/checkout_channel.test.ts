import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { isApprovedWebCheckoutApp } from "./checkout_channel";

describe("Stripe web checkout channel", () => {
  it("fails closed without explicit web registration", () => {
    assert.equal(isApprovedWebCheckoutApp("disabled", "mobile-id"), false);
    assert.equal(isApprovedWebCheckoutApp("", "web-id"), false);
    assert.equal(isApprovedWebCheckoutApp("web-id", undefined), false);
  });

  it("rejects an attested mobile app ID", () => {
    assert.equal(isApprovedWebCheckoutApp("web-id", "mobile-id"), false);
  });

  it("rejects even the previously approved web app under plan v2", () => {
    assert.equal(isApprovedWebCheckoutApp("web-id", "web-id"), false);
  });
});
