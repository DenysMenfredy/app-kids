import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { creditActiveTime, learningWeekDates, MAX_ACTIVE_MILLISECONDS,
  nextLocalMidnight } from "./active_time";

describe("bounded server activity and local calendar", () => {
  it("caps missing heartbeats and excludes paused time", () => {
    const start = Date.parse("2026-10-09T12:00:00Z");
    const first = creditActiveTime({}, start, start + 3600_000, "America/Belem", true);
    assert.equal(first["2026-10-09"], 30_000);
    assert.deepEqual(creditActiveTime(first, start, start + 3600_000, "America/Belem", false), first);
    const capped = creditActiveTime({ "2026-10-09": MAX_ACTIVE_MILLISECONDS - 500 },
      start, start + 5000, "America/Belem", true);
    assert.equal(capped["2026-10-09"], MAX_ACTIVE_MILLISECONDS);
  });
  it("splits time at the exact local midnight without duplicate milliseconds", () => {
    const start = Date.parse("2026-10-09T02:59:59.500Z");
    const split = creditActiveTime({}, start, start + 2000, "America/Belem", true);
    assert.deepEqual(split, { "2026-10-08": 500, "2026-10-09": 1500 });
    assert.equal(Object.values(split).reduce((sum, value) => sum + value, 0), 2000);
  });
  it("uses Monday through Sunday in the parent's timezone", () => {
    assert.deepEqual(learningWeekDates(new Date("2026-10-12T01:00:00Z"), "America/Belem"),
      ["2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09", "2026-10-10", "2026-10-11"]);
    const now = new Date("2026-11-01T05:30:00Z");
    assert.equal(nextLocalMidnight(now, "America/New_York"), Date.parse("2026-11-02T05:00:00Z"));
  });
});
