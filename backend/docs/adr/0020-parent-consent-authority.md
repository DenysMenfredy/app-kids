# ADR 0020 — Server-owned, versioned parent consent gates child data

Date: 2026-11-27 · Status: accepted; D07 legal text still open

## Context

Creating a child profile and collecting learning evidence must happen only
after the parent has accepted the current child-data terms. D07 (the reviewed
legal text and retention policy) is still open. Copying an invented legal text
into code would be worse than leaving the gate visibly incomplete, so the
backend needs a versioned mechanism now and a reviewed text later.

The client is untrusted (spec §12, §22). A consent flag sent by the app or
written directly to Firestore cannot establish who accepted what, when, or
which version. It must be recorded by the server, keyed to the authenticated
parent, and checked again before every path that creates child data.

## Decision

1. Store one server-owned document per parent at
   `users/{uid}/consent/current` with:
   - `schemaVersion: 1`;
   - `textVersion`, a server-allowlisted version identifier;
   - `purposes`, an explicit boolean map for `notifications`, `marketing` and
     `analytics`;
   - `origin`, an allowlisted source label (`parent_app` today);
   - `uid`, copied from the verified Auth token, never from the request;
   - `acceptedAt` and `updatedAt`, both server timestamps.
2. Record acceptance through the authenticated, App Check-protected
   `recordParentConsent` callable. It accepts only the allowlisted version,
   purpose keys and origin; it rejects arbitrary text, unknown fields and
   unknown versions. A singleton document makes retries idempotent: an
   identical submission returns `changed: false` without a write. A new text
   version resets `acceptedAt`; changing only optional purposes keeps it.
3. `CURRENT_CONSENT_TEXT_VERSION` is `d07-placeholder-v1`. It is a version
   identifier, not legal copy. The backend stores no consent text. When D07 is
   approved, add the reviewed version to the allowlist, make it current, and
   require re-consent; old records fail closed.
4. Firestore Rules make the consent document read-only to its owner. The
   client cannot create, update or delete it. Child-profile updates additionally
   require a current consent; child creation remains server-only. Reads of
   existing child data stay available to the authenticated parent so an
   outdated consent does not hide the family's own data.
5. Every callable that creates or collects child data calls
   `requireCurrentParentConsent` before touching Firestore:
   `createChildProfile`, `submitAssessment`, `startLessonSession`,
   `submitActivityAttempt`, `completeLesson`, `updateLessonSession`,
   `updateProgress` and `saveBookBookmark`. Reads such as
   `getWeeklyLearningSummary` and `recoverLessonSession` are not blocked.
   Missing consent returns `failed-precondition` with
   `details.code: "consent_required"`; an older or malformed record returns
   `consent_outdated` and the accepted/required versions.
6. Optional purposes are recorded, not inferred. Accepting the text is the
   base child-data consent; declining notifications, marketing or analytics
   does not block child creation. The existing `trackServerEvent` logging path
   does not consult the `analytics` purpose yet; PR14 owns collection
   eligibility and must wire this record before analytics can be described as
   consent-based. This ADR does not approve or enable that collection.
7. Existing accounts without a current record are not backfilled with assumed
   consent. Their child-data writes fail closed until the parent accepts the
   current version. No child data is deleted by this ADR.

## Consequences and remaining gates

- **D07 dependency:** the placeholder must be replaced by the reviewed text
  version before G1/G2 acceptance. Until then, the mechanism is testable but
  the legal copy is explicitly not approved.
- **App integration (PR09):** the Flutter flow must show the versioned consent
  and call `recordParentConsent` before child creation. Until that ships, a
  client that has not been updated will receive `consent_required`; this is
  intentional fail-closed behavior, not a backend regression.
- **Version migration:** bumping the current version invalidates every old
  record. A release that bumps it must include the re-consent UI and a
  migration/communication plan; there is no silent grandfathering.
- **Rules duplication:** `firestore.rules` repeats the placeholder version
  because Rules cannot import TypeScript. A Rules test and the Functions
  domain test both pin the literal; change them together.
- **Not covered:** retention/deletion, legal review, consent withdrawal UI,
  consent history/audit export, analytics/crash collection and the
  parent-facing explanation remain D07 or later tasks. This ADR records
  authority and the fail-closed boundary only.
