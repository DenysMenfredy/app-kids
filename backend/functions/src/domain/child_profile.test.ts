import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { parseChildProfile } from "./child_profile";

describe("child profile input", () => {
  it("normalizes a valid minimal profile", () => {
    assert.deepEqual(
      parseChildProfile({ name: "  Sofia  ", age: 5, avatarId: "orange" }),
      { name: "Sofia", age: 5, avatarId: "orange" },
    );
  });

  it("rejects missing, oversized, or blank names", () => {
    assert.equal(parseChildProfile({ age: 5, avatarId: "orange" }), null);
    assert.equal(parseChildProfile({
      name: " ", age: 5, avatarId: "orange",
    }), null);
    assert.equal(parseChildProfile({
      name: "x".repeat(81), age: 5, avatarId: "orange",
    }), null);
  });

  it("accepts only whole-number ages from three through seven", () => {
    for (const age of [2, 8, 4.5, "5"]) {
      assert.equal(parseChildProfile({
        name: "Sofia", age, avatarId: "orange",
      }), null);
    }
  });

  it("accepts only avatars offered by the app", () => {
    assert.equal(parseChildProfile({
      name: "Sofia", age: 5, avatarId: "unknown",
    }), null);
  });

  it("rejects extra fields that could smuggle child data", () => {
    assert.equal(parseChildProfile({
      name: "Sofia", age: 5, avatarId: "orange", school: "Escola X",
    }), null);
  });
});
