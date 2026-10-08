import { EntitlementSnapshot } from "./content_access";

export const BOOK_ILLUSTRATIONS = [
  "frog", "moon", "sun", "pond", "vowels", "party", "letters", "cat",
  "dog", "train", "flowers", "forest", "butterfly", "book", "family",
] as const;

/** Metadata must never contain pages: even locked covers are listable. */
export function bookPublicationProblem(
  bookId: string,
  book: Record<string, unknown>,
  content: Record<string, unknown>,
): string | null {
  const boundedText = (value: unknown, max: number): boolean =>
    typeof value === "string" && value.trim().length > 0 && value.length <= max;
  if (
    book.id !== bookId || content.id !== bookId || "pages" in book ||
    book.schemaVersion !== 1 || content.schemaVersion !== 1 ||
    !Number.isInteger(book.contentVersion) || Number(book.contentVersion) < 1 ||
    content.contentVersion !== book.contentVersion ||
    !boundedText(book.title, 100) || !boundedText(book.description, 300) ||
    !BOOK_ILLUSTRATIONS.includes(book.coverKey as typeof BOOK_ILLUSTRATIONS[number]) ||
    !["free", "premium"].includes(String(book.access)) ||
    !Number.isInteger(book.order) || Number(book.order) < 0 ||
    !Number.isInteger(book.pageCount) || Number(book.pageCount) < 1 ||
    Number(book.pageCount) > 40
  ) return "Metadados do livro inválidos.";

  const pages = content.pages;
  if (!Array.isArray(pages) || pages.length !== book.pageCount) {
    return "O livro precisa de todas as páginas anunciadas.";
  }
  const ids = new Set<string>();
  for (const page of pages) {
    if (
      typeof page !== "object" || page === null || Array.isArray(page) ||
      !boundedText(page.id, 64) || ids.has(page.id) ||
      !boundedText(page.text, 1200) ||
      !BOOK_ILLUSTRATIONS.includes(page.illustration)
    ) return "Página do livro inválida.";
    ids.add(page.id);
  }
  return null;
}

/** Unclassified or expired access never grants a Premium book. */
export function canAccessBook(
  access: unknown,
  entitlement: EntitlementSnapshot | null,
  now: Date,
): boolean {
  if (access === "free") return true;
  return access === "premium" && entitlement?.active === true &&
    Array.isArray(entitlement.features) &&
    entitlement.features.includes("premium_books") &&
    entitlement.validFrom instanceof Date &&
    entitlement.validUntil instanceof Date &&
    entitlement.validFrom.getTime() <= now.getTime() &&
    entitlement.validUntil.getTime() > now.getTime();
}
