import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

import {
  CONSENT_PURPOSES,
  CURRENT_CONSENT_TEXT_VERSION,
  consentRefusal,
  parseConsentPurposes,
  parseParentConsentInput,
  purposesEqual,
} from "./consent";

const uid = "parent_uid";
const valid = {
  textVersion: CURRENT_CONSENT_TEXT_VERSION,
  purposes: { notifications: true, marketing: false, analytics: true },
  origin: "parent_app",
};

const currentRecord = {
  schemaVersion: 1,
  ...valid,
  uid,
  acceptedAt: new Date(),
  updatedAt: new Date(),
};

describe("parent consent input", () => {
  it("accepts the current version, all three purposes and an allowlisted origin", () => {
    assert.deepEqual(parseParentConsentInput(valid), valid);
  });

  it("rejects an arbitrary text version or unknown text fields", () => {
    assert.equal(parseParentConsentInput({ ...valid, textVersion: "v2" }), null);
    assert.equal(parseParentConsentInput({ ...valid, text: "invented legal copy" }), null);
    assert.equal(parseParentConsentInput({ ...valid, textVersion: 2 }), null);
  });

  it("rejects missing, extra or non-boolean purposes", () => {
    assert.equal(parseParentConsentInput({
      ...valid, purposes: { notifications: true },
    }), null);
    assert.equal(parseParentConsentInput({
      ...valid, purposes: { ...valid.purposes, ads: false },
    }), null);
    assert.equal(parseParentConsentInput({
      ...valid, purposes: { ...valid.purposes, marketing: "yes" },
    }), null);
  });

  it("rejects unknown origins and extra top-level fields", () => {
    assert.equal(parseParentConsentInput({ ...valid, origin: "web" }), null);
    assert.equal(parseParentConsentInput({ ...valid, uid: "attacker" }), null);
    assert.equal(parseParentConsentInput(null), null);
  });

  it("keeps all optional purposes explicit and independent", () => {
    for (const purpose of CONSENT_PURPOSES) {
      const purposes = { notifications: false, marketing: false, analytics: false };
      purposes[purpose] = true;
      assert.deepEqual(parseConsentPurposes(purposes), purposes);
    }
    assert.equal(purposesEqual(valid.purposes, { ...valid.purposes }), true);
    assert.equal(purposesEqual(valid.purposes, {
      notifications: true, marketing: true, analytics: true,
    }), false);
  });
});

describe("current-consent gate", () => {
  it("requires consent when the document is absent", () => {
    assert.deepEqual(consentRefusal(null, uid), {
      code: "consent_required",
      requiredTextVersion: CURRENT_CONSENT_TEXT_VERSION,
    });
  });

  it("accepts only the current version, owner and complete shape", () => {
    assert.equal(consentRefusal(currentRecord, uid), null);
  });

  it("fails closed for outdated versions and malformed records", () => {
    for (const record of [
      { ...currentRecord, textVersion: "d07-placeholder-0" },
      { ...currentRecord, schemaVersion: 2 },
      { ...currentRecord, uid: "someone_else" },
      { ...currentRecord, origin: "web" },
      { ...currentRecord, acceptedAt: undefined },
      { ...currentRecord, purposes: { notifications: true } },
      { ...currentRecord, purposes: { ...valid.purposes, marketing: "no" } },
    ]) {
      const refusal = consentRefusal(record, uid);
      assert.equal(refusal?.code, "consent_outdated");
      assert.equal(refusal?.requiredTextVersion, CURRENT_CONSENT_TEXT_VERSION);
    }
  });

  it("reports the accepted version when one can be read", () => {
    assert.equal(
      consentRefusal({ ...currentRecord, textVersion: "d07-placeholder-0" }, uid)
        ?.acceptedTextVersion,
      "d07-placeholder-0",
    );
  });

  it("keeps the Rules literal in sync with the server allowlist", () => {
    const rules = readFileSync(join(__dirname, "../../../firestore.rules"), "utf8");
    assert.ok(
      rules.includes(`textVersion == '${CURRENT_CONSENT_TEXT_VERSION}'`),
      "firestore.rules must gate child edits on the current consent version",
    );
  });
});
