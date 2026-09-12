import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { trackServerEvent } from "../analytics/track_server_event";
import {
  AnswerMap,
  Assessment,
  InvalidAnswerError,
  maxScore,
  placementFor,
  scoreAnswers,
} from "../domain/assessment";
import { DEFAULT_ASSESSMENT_ID, db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { log } from "../lib/logger";

/**
 * Scores an assessment and places the child on the learning journey.
 *
 * The client sends only which option it picked; weights, thresholds and the
 * resulting placement all come from the stored assessment, so the starting
 * module can't be chosen on-device (spec §22 constraints 1 and 6).
 */
export const submitAssessment = onCall(
  { enforceAppCheck },
  async (request) => {
    const uid = requireAuth(request);
    const childId = requireString(request.data?.childId, "childId", {
      maxLength: 64,
    });
    const assessmentId = typeof request.data?.assessmentId === "string"
      ? request.data.assessmentId
      : DEFAULT_ASSESSMENT_ID;
    const answers = parseAnswers(request.data?.answers);

    const childRef = db().collection(paths.children(uid)).doc(childId);
    const child = await childRef.get();
    if (!child.exists) {
      throw new HttpsError("not-found", "Perfil da criança não encontrado.");
    }

    const assessmentSnap = await db()
      .collection(paths.assessments)
      .doc(assessmentId)
      .get();
    const assessment = assessmentSnap.data() as Assessment | undefined;
    if (!assessmentSnap.exists || !assessment?.published) {
      throw new HttpsError("not-found", "Avaliação indisponível.");
    }

    let score: number;
    try {
      score = scoreAnswers(assessment.questions, answers);
    } catch (error) {
      if (error instanceof InvalidAnswerError) {
        throw new HttpsError("invalid-argument", "Respostas inválidas.");
      }
      throw error;
    }
    const placement = placementFor(assessment.placements, score);

    const batch = db().batch();
    // Only fields the child schema allows, so the parent can still edit the
    // profile from the app afterwards.
    batch.set(
      childRef,
      {
        learningLevel: placement.learningLevel,
        currentCourseId: placement.courseId,
        currentLessonId: placement.firstLessonId,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    batch.set(db().collection(paths.assessmentResults(uid)).doc(childId), {
      assessmentId,
      childId,
      answers,
      score,
      maxScore: maxScore(assessment.questions),
      placement,
      completedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();

    trackServerEvent("assessment_completed", uid, {
      childId,
      assessmentId,
      score,
      moduleNumber: placement.moduleNumber,
    });
    log("learning", "assessment_completed", {
      uid,
      childId,
      assessmentId,
      score,
      moduleNumber: placement.moduleNumber,
    });

    return { score, placement };
  },
);

/** Accepts `{ questionId: optionId }` with string keys and values only. */
function parseAnswers(raw: unknown): AnswerMap {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "Campo inválido: answers");
  }
  const entries = Object.entries(raw as Record<string, unknown>);
  if (entries.length === 0 || entries.length > 50) {
    throw new HttpsError("invalid-argument", "Campo inválido: answers");
  }
  const answers: AnswerMap = {};
  for (const [key, value] of entries) {
    if (
      typeof value !== "string" ||
      key.length === 0 ||
      key.length > 64 ||
      value.length === 0 ||
      value.length > 64
    ) {
      throw new HttpsError("invalid-argument", "Campo inválido: answers");
    }
    answers[key] = value;
  }
  return answers;
}
