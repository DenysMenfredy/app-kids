import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

import { requireVerifiedParentEmail } from "./guards";

function requestFor(provider: string, emailVerified: boolean): CallableRequest {
  return {
    auth: {
      uid: "parent_uid",
      token: {
        firebase: { sign_in_provider: provider },
        email_verified: emailVerified,
      },
    },
  } as unknown as CallableRequest;
}

describe("requireVerifiedParentEmail", () => {
  it("rejects unverified email/password accounts", () => {
    assert.throws(
      () => requireVerifiedParentEmail(requestFor("password", false)),
      (error: unknown) =>
        error instanceof HttpsError && error.code === "failed-precondition",
    );
  });

  it("allows verified email/password accounts", () => {
    assert.doesNotThrow(() =>
      requireVerifiedParentEmail(requestFor("password", true)),
    );
  });

  it("does not add a verification step to Google or Apple sign-in", () => {
    assert.doesNotThrow(() =>
      requireVerifiedParentEmail(requestFor("google.com", false)),
    );
    assert.doesNotThrow(() =>
      requireVerifiedParentEmail(requestFor("apple.com", false)),
    );
  });
});
