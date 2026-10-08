import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

import { bookPublicationProblem, canAccessBook } from "./books";

const root = join(__dirname, "../../../seed");
const books = JSON.parse(readFileSync(join(root, "books/books.json"), "utf8"));
const contents = JSON.parse(readFileSync(join(root, "bookContents/bookContents.json"), "utf8"));

describe("book publication", () => {
  it("publishes only complete, versioned stories with valid illustrations", () => {
    assert.equal(books.length, 6);
    assert.equal(new Set(books.map((book: { id: string }) => book.id)).size, 6);
    for (const book of books) {
      const content = contents.find((item: { id: string }) => item.id === book.id);
      assert.equal(bookPublicationProblem(book.id, book, content), null);
    }
  });

  it("rejects empty, mismatched, duplicate and unsupported pages", () => {
    const book = books[0];
    const content = contents[0];
    for (const invalid of [
      { ...content, pages: [] },
      { ...content, contentVersion: 999 },
      { ...content, pages: content.pages.map(() => content.pages[0]) },
      { ...content, pages: content.pages.map((p: object) => ({ ...p, illustration: "unknown" })) },
    ]) assert.ok(bookPublicationProblem(book.id, book, invalid));
    assert.ok(bookPublicationProblem(book.id, { ...book, pages: content.pages }, content));
  });
});

describe("book access", () => {
  const now = new Date("2026-10-08T12:00:00Z");
  const premium = {
    active: true, features: ["premium_books"],
    validFrom: new Date(now.getTime() - 1000),
    validUntil: new Date(now.getTime() + 1000),
  };
  it("allows free books and only the matching current Premium feature", () => {
    assert.equal(canAccessBook("free", null, now), true);
    assert.equal(canAccessBook("premium", premium, now), true);
    for (const entitlement of [null, { ...premium, active: false },
      { ...premium, features: ["full_curriculum"] },
      { ...premium, validUntil: now },
      { ...premium, validFrom: new Date(now.getTime() + 1) },
    ]) assert.equal(canAccessBook("premium", entitlement, now), false);
    assert.equal(canAccessBook(undefined, premium, now), false);
  });
});
