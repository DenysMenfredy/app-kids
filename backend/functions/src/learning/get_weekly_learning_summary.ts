import { onCall, HttpsError } from "firebase-functions/v2/https";
import { learningWeekDates, nextLocalMidnight, validTimezone } from "../domain/active_time";
import { localDateIso } from "../domain/time";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";

export const getWeeklyLearningSummary = onCall({ enforceAppCheck }, async (request) => {
  const uid = requireAuth(request);
  const childId = requireString(request.data?.childId, "childId", { maxLength: 64 });
  const [parent, child] = await Promise.all([
    db().doc(paths.user(uid)).get(), db().collection(paths.children(uid)).doc(childId).get(),
  ]);
  if (!child.exists) throw new HttpsError("not-found", "Perfil da criança indisponível.");
  const timezone = validTimezone(parent.get("timezone"));
  const now = new Date();
  const dates = learningWeekDates(now, timezone);
  const docs = await db().getAll(...dates.map((date) =>
    db().collection(paths.dailySummaries(uid, childId)).doc(date)));
  const count = (raw: unknown): number =>
    typeof raw === "number" && Number.isSafeInteger(raw) && raw >= 0 ? raw : 0;
  return { schemaVersion: 1, timezone, today: localDateIso(now, timezone),
    refreshAfterMilliseconds: nextLocalMidnight(now, timezone) - now.getTime(),
    dailyGoalLessons: 1, days: docs.map((doc, index) => ({
      localDate: dates[index], activeSeconds: Math.floor(count(doc.get("activeMilliseconds")) / 1000),
      lessonsCompleted: count(doc.get("lessonsCompleted")),
      sessionsCompleted: count(doc.get("sessionsCompleted")),
      attempts: count(doc.get("attempts")), correctAnswers: count(doc.get("correctAnswers")),
    })) };
});
