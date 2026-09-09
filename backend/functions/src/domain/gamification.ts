import { isNextCalendarDay } from "./time";

/**
 * Gamification state (XP, coins, daily streak) for one child.
 *
 * Server-owned: the client may read it but never write it, so rewards
 * cannot be minted on-device (spec §22 constraint 1; see ADR 0003).
 */
export interface GamificationState {
  xp: number;
  coins: number;
  streak: number;
  /** Local calendar date (`YYYY-MM-DD`) of the last counted completion. */
  lastCompletionDate: string | null;
}

export const LESSON_XP_REWARD = 50;
export const LESSON_COIN_REWARD = 10;

export const initialGamification: GamificationState = {
  xp: 0,
  coins: 0,
  streak: 0,
  lastCompletionDate: null,
};

/**
 * Applies the reward for a newly completed lesson. Callers must only invoke
 * this for a first-time completion — repeat completions of the same lesson
 * are filtered out upstream so retries never mint extra XP (spec §20).
 *
 * Streak rules, evaluated in the child's local calendar:
 *  - another lesson the same day keeps the streak as it is;
 *  - a lesson the very next day extends it;
 *  - a gap (or a first ever lesson) restarts it at 1.
 */
export function applyLessonReward(
  current: GamificationState,
  todayLocalDate: string,
  { xp = LESSON_XP_REWARD, coins = LESSON_COIN_REWARD } = {},
): GamificationState {
  const last = current.lastCompletionDate;
  let streak: number;
  if (last === todayLocalDate) {
    streak = Math.max(current.streak, 1);
  } else if (last !== null && isNextCalendarDay(last, todayLocalDate)) {
    streak = current.streak + 1;
  } else {
    streak = 1;
  }

  return {
    xp: current.xp + xp,
    coins: current.coins + coins,
    streak,
    lastCompletionDate: todayLocalDate,
  };
}
