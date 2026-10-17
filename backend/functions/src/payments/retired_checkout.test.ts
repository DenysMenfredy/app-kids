import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CallableRequest } from "firebase-functions/v2/https";
import { createCheckoutSession } from "./create_checkout_session";

describe("retired external acquisition endpoint", () => {
  it("still requires Firebase Auth", async () => {
    await assert.rejects(createCheckoutSession.run({ data: {} } as CallableRequest),
      (error: unknown) => (error as { code?: string }).code === "unauthenticated");
  });
  it("never creates checkout even for an attested verified parent", async () => {
    await assert.rejects(createCheckoutSession.run({
      data: { planId: "founder_annual" }, app: { appId: "previous-web-id" },
      auth: { uid: "test-parent", token: { email_verified: true } },
    } as unknown as CallableRequest),
    (error: unknown) => (error as { code?: string }).code === "failed-precondition");
  });
});
