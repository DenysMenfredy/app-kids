# ADR 0012 — Published book catalog, protected pages and child bookmarks

Date: 2026-10-08 · Status: accepted for local MVP implementation

## Decision

`books/{bookId}` contains cover metadata, explicit `free`/`premium` access,
page count and schema/content versions. Authenticated catalog queries filter
`published == true`. Text is stored separately in `bookContents/{bookId}`.
Published pages require matching versions and counts; Premium pages require
the current server-owned `premium_books` entitlement, independently of the UI.
Unclassified, unpublished, expired and mismatched content fails closed.

Six original short pt-BR stories form this initial catalog: two free and four
Premium. Covers and page scenes use app-rendered symbols; there are no external
media URLs. Free sample stories alone are included in the demo repository.
Premium text is not bundled in the app. Publication validates complete pages
and publishes catalog/pages atomically through the existing editor-role gate.

Opening or resuming a Firebase book fetches pages from the server. Access is
revalidated before page changes and app resume; cached Premium pages are not
used to authorize a new reading run. Previously delivered bytes cannot be
recovered. This is a bounded book-reading policy; the broader D04 decision
remains open.

`users/{uid}/children/{childId}/bookmarks/{bookId}` is private navigation state.
The `saveBookBookmark` callable checks child ownership, publication, access,
content version and page bounds, and uses a server timestamp. Clients cannot
write bookmarks directly. A bookmark grants no lesson completion, rewards or
entitlement. State is keyed by parent and child and discarded on scope changes.

## Validation and deployment

Run Functions tests, Firestore Rules tests and Flutter reader/scoping tests.
Existing demo emulator exports receive the book seed on the next `dev.sh`
startup without removing profiles. Real projects need an explicit content seed
or editor publication, updated Rules and the new callable deployed; no remote
deployment is part of this change. Editorial review and device narration checks
remain required before a family-facing release.
