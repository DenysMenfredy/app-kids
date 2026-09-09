import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  applyLessonReward,
  GamificationState,
  initialGamification,
  LESSON_COIN_REWARD,
  LESSON_XP_REWARD,
} from "./gamification";
import { isNextCalendarDay, localDateIso } from "./time";

function state(overrides: Partial<GamificationState> = {}): GamificationState {
  return { xp: 100, coins: 20, streak: 3, lastCompletionDate: "2026-09-08", ...overrides };
}

describe("applyLessonReward", () => {
  it("grants the standard XP and coins", () => {
    const next = applyLessonReward(state(), "2026-09-09");
    assert.equal(next.xp, 100 + LESSON_XP_REWARD);
    assert.equal(next.coins, 20 + LESSON_COIN_REWARD);
  });

  it("extends the streak on the next calendar day", () => {
    const next = applyLessonReward(state(), "2026-09-09");
    assert.equal(next.streak, 4);
    assert.equal(next.lastCompletionDate, "2026-09-09");
  });

  it("keeps the streak for a second lesson the same day", () => {
    const next = applyLessonReward(state({ lastCompletionDate: "2026-09-09" }), "2026-09-09");
    assert.equal(next.streak, 3);
    // XP still accrues for the extra lesson.
    assert.equal(next.xp, 150);
  });

  it("restarts the streak after a missed day", () => {
    const next = applyLessonReward(state({ lastCompletionDate: "2026-09-06" }), "2026-09-09");
    assert.equal(next.streak, 1);
  });

  it("starts a streak at 1 for the very first lesson", () => {
    const next = applyLessonReward(initialGamification, "2026-09-09");
    assert.equal(next.streak, 1);
    assert.equal(next.xp, LESSON_XP_REWARD);
    assert.equal(next.coins, LESSON_COIN_REWARD);
  });

  it("repairs a same-day record that somehow has a zero streak", () => {
    const next = applyLessonReward(
      state({ lastCompletionDate: "2026-09-09", streak: 0 }),
      "2026-09-09",
    );
    assert.equal(next.streak, 1);
  });

  it("bridges a month boundary", () => {
    const next = applyLessonReward(state({ lastCompletionDate: "2026-08-31" }), "2026-09-01");
    assert.equal(next.streak, 4);
  });

  it("accepts custom reward amounts", () => {
    const next = applyLessonReward(state(), "2026-09-09", { xp: 5, coins: 1 });
    assert.equal(next.xp, 105);
    assert.equal(next.coins, 21);
  });
});

describe("time helpers", () => {
  it("formats the local calendar date for the user's timezone", () => {
    // 02:30 UTC is still the previous day in São Paulo (UTC-3).
    const instant = new Date("2026-09-09T02:30:00Z");
    assert.equal(localDateIso(instant, "America/Sao_Paulo"), "2026-09-08");
    assert.equal(localDateIso(instant, "UTC"), "2026-09-09");
  });

  it("detects consecutive days across month and year boundaries", () => {
    assert.equal(isNextCalendarDay("2026-09-08", "2026-09-09"), true);
    assert.equal(isNextCalendarDay("2026-08-31", "2026-09-01"), true);
    assert.equal(isNextCalendarDay("2026-12-31", "2027-01-01"), true);
    assert.equal(isNextCalendarDay("2026-09-08", "2026-09-10"), false);
    assert.equal(isNextCalendarDay("2026-09-09", "2026-09-08"), false);
    assert.equal(isNextCalendarDay("not-a-date", "2026-09-09"), false);
  });
});
