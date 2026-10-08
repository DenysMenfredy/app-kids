import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { bookPublicationProblem, canAccessBook } from "../domain/books";
import { db, paths, PREMIUM_ENTITLEMENT_ID } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";

/** A bookmark is navigation state, never evidence for rewards or placement. */
export const saveBookBookmark = onCall({ enforceAppCheck }, async (request) => {
  const uid = requireAuth(request);
  const childId = requireString(request.data?.childId, "childId", { maxLength: 64 });
  const bookId = requireString(request.data?.bookId, "bookId", { maxLength: 64 });
  const { pageIndex, contentVersion } = request.data ?? {};
  if (!/^[A-Za-z0-9_-]+$/.test(childId) || !/^[A-Za-z0-9_-]+$/.test(bookId) ||
      !Number.isInteger(pageIndex) || pageIndex < 0 ||
      !Number.isInteger(contentVersion) || contentVersion < 1) {
    throw new HttpsError("invalid-argument", "Posição de leitura inválida.");
  }
  const firestore = db();
  const childRef = firestore.collection(paths.children(uid)).doc(childId);
  const bookmarkRef = childRef.collection("bookmarks").doc(bookId);
  await firestore.runTransaction(async (tx) => {
    const [child, bookSnap, contentSnap, entitlementSnap] = await Promise.all([
      tx.get(childRef),
      tx.get(firestore.collection(paths.books).doc(bookId)),
      tx.get(firestore.collection(paths.bookContents).doc(bookId)),
      tx.get(firestore.collection(paths.entitlements(uid)).doc(PREMIUM_ENTITLEMENT_ID)),
    ]);
    if (!child.exists) {
      throw new HttpsError("not-found", "Perfil da criança não encontrado.");
    }
    const book = bookSnap.data();
    const content = contentSnap.data();
    if (!book || !content || book.published !== true || content.published !== true ||
        bookPublicationProblem(bookId, book, content)) {
      throw new HttpsError("failed-precondition", "Livro indisponível.");
    }
    const entitlement = entitlementSnap.data();
    if (!canAccessBook(book.access, entitlement ? {
      active: entitlement.active,
      features: entitlement.features,
      validFrom: entitlement.validFrom instanceof Timestamp ? entitlement.validFrom.toDate() : null,
      validUntil: entitlement.validUntil instanceof Timestamp ? entitlement.validUntil.toDate() : null,
    } : null, new Date())) {
      throw new HttpsError("permission-denied", "Este livro exige Premium.");
    }
    if (book.contentVersion !== contentVersion || pageIndex >= book.pageCount) {
      throw new HttpsError("failed-precondition", "Livro atualizado; abra a história novamente.");
    }
    tx.set(bookmarkRef, {
      bookId, contentVersion, pageIndex,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});
