import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { parseChildProfile } from "../domain/child_profile";
import { db, paths } from "../lib/firestore";
import {
  enforceAppCheck,
  requireAuth,
  requireString,
  requireVerifiedParentEmail,
} from "../lib/guards";

/** Creates a minimal child profile with an ID allocated by Firestore Admin. */
export const createChildProfile = onCall(
  { enforceAppCheck },
  async (request) => {
    const uid = requireAuth(request);
    requireVerifiedParentEmail(request);
    const requestId = requireString(request.data?.requestId, "requestId", {
      maxLength: 80,
    });
    if (!/^[A-Za-z0-9_-]+$/.test(requestId)) {
      throw new HttpsError("invalid-argument", "Identificador inválido.");
    }
    const profile = parseChildProfile(request.data?.profile);
    if (!profile) {
      throw new HttpsError("invalid-argument", "Perfil da criança inválido.");
    }

    const firestore = db();
    const childRef = firestore.collection(paths.children(uid)).doc();
    const requestRef = firestore
      .collection(paths.childCreationRequests(uid))
      .doc(requestId);

    const childId = await firestore.runTransaction(async (tx) => {
      const existing = await tx.get(requestRef);
      if (existing.exists) {
        const priorChildId = existing.get("childId");
        if (typeof priorChildId !== "string") {
          throw new HttpsError("data-loss", "Solicitação de perfil inválida.");
        }
        const priorChildRef = firestore
          .collection(paths.children(uid))
          .doc(priorChildId);
        const priorChild = await tx.get(priorChildRef);
        if (!priorChild.exists) {
          throw new HttpsError("data-loss", "Perfil associado não encontrado.");
        }
        tx.update(priorChildRef, {
          ...profile,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return priorChildId;
      }
      tx.create(childRef, {
        ...profile,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.create(requestRef, {
        childId: childRef.id,
        createdAt: FieldValue.serverTimestamp(),
      });
      return childRef.id;
    });

    return { childId };
  },
);
