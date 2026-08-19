import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  isWithinReminderWindow,
  localMinutesOfDay,
  parsePreferredTime,
} from "./reminders";

const SAO_PAULO = "America/Sao_Paulo"; // UTC-3, no DST since 2019

describe("parsePreferredTime", () => {
  it("parses valid HH:mm", () => {
    assert.equal(parsePreferredTime("18:00"), 18 * 60);
    assert.equal(parsePreferredTime("00:00"), 0);
    assert.equal(parsePreferredTime("23:59"), 23 * 60 + 59);
  });

  it("rejects garbage", () => {
    assert.equal(parsePreferredTime("25:00"), null);
    assert.equal(parsePreferredTime("18h"), null);
    assert.equal(parsePreferredTime(""), null);
  });
});

describe("localMinutesOfDay", () => {
  it("converts UTC instants to São Paulo wall clock", () => {
    // 21:00 UTC == 18:00 in São Paulo
    const now = new Date("2026-08-18T21:00:00Z");
    assert.equal(localMinutesOfDay(now, SAO_PAULO), 18 * 60);
  });
});

describe("isWithinReminderWindow", () => {
  const prefs = { dailyReminder: true, preferredTime: "18:00" };

  it("fires inside the window (18:00–18:59 local)", () => {
    assert.equal(
      isWithinReminderWindow(prefs, SAO_PAULO, new Date("2026-08-18T21:00:00Z")),
      true,
    );
    assert.equal(
      isWithinReminderWindow(prefs, SAO_PAULO, new Date("2026-08-18T21:59:00Z")),
      true,
    );
  });

  it("stays quiet outside the window", () => {
    assert.equal(
      isWithinReminderWindow(prefs, SAO_PAULO, new Date("2026-08-18T20:59:00Z")),
      false,
    );
    assert.equal(
      isWithinReminderWindow(prefs, SAO_PAULO, new Date("2026-08-18T22:00:00Z")),
      false,
    );
  });

  it("stays quiet when reminders are disabled", () => {
    assert.equal(
      isWithinReminderWindow(
        { ...prefs, dailyReminder: false },
        SAO_PAULO,
        new Date("2026-08-18T21:00:00Z"),
      ),
      false,
    );
  });

  it("handles windows that wrap past midnight", () => {
    const late = { dailyReminder: true, preferredTime: "23:30" };
    // 02:15 UTC == 23:15 local (previous day) — before the window
    assert.equal(
      isWithinReminderWindow(late, SAO_PAULO, new Date("2026-08-19T02:15:00Z")),
      false,
    );
    // 02:45 UTC == 23:45 local — inside
    assert.equal(
      isWithinReminderWindow(late, SAO_PAULO, new Date("2026-08-19T02:45:00Z")),
      true,
    );
    // 03:15 UTC == 00:15 local next day — still inside the 60-min window
    assert.equal(
      isWithinReminderWindow(late, SAO_PAULO, new Date("2026-08-19T03:15:00Z")),
      true,
    );
  });

  it("fails safe on an unknown timezone", () => {
    assert.equal(
      isWithinReminderWindow(prefs, "Mars/Olympus", new Date()),
      false,
    );
  });

  it("fails safe on a malformed preferred time", () => {
    assert.equal(
      isWithinReminderWindow(
        { dailyReminder: true, preferredTime: "soon" },
        SAO_PAULO,
        new Date(),
      ),
      false,
    );
  });
});
