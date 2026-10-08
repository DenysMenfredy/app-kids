# ADR 0008 — Server-issued child profile IDs and per-child app state

Date: 2026-10-07 · Status: accepted; implementation partial

## Context

The app used the literal document ID `primary` throughout onboarding,
progress, assessment and lesson synchronization. That prevented a parent from
having independent child profiles and made it easy for future profile
switching to attribute a lesson to whichever child happened to be selected at
completion time. Client-created document IDs also cannot establish that the
backend issued the child identity.

## Decision

- Create child profiles through the authenticated, App Check-protected
  `createChildProfile` callable. The Admin SDK allocates the document ID and
  validates the minimum profile fields (name, age band and supported avatar).
- Accept a parent-scoped request ID so retries return the same child ID and
  update that profile rather than duplicate it. Creation requests are not
  client-readable or writable.
- Parents may list and read their own child profiles and may edit only the
  allowlisted profile fields on an existing profile. Firestore Rules reject
  client-side child-document creation and deletion.
- Persist the selected child ID in the authenticated parent's local storage
  namespace. On a reinstall or stale selection, choose an available child
  rather than retaining a removed profile. Each assessment, journey/progress
  query and lesson callable uses that active child ID.
- Capture the child ID when a lesson session starts. Attempts and completion
  remain bound to that child for the entire run, even if the parent changes
  selection; changing accounts invalidates local lesson statistics and
  prevents the old run from being submitted under the new account.
- Keep `primary` as a legacy ID while existing records and their references
  are being inventoried. Do not rename or copy legacy data automatically.

## Consequences and remaining gates

The Flutter app now lists, creates, selects and edits profile fields for
multiple children, and learning writes are scoped to the selected child.
Profile deletion is not exposed: it must wait for a durable, idempotent
cascade over progress, sessions, attempts, rewards, assessment results and
exports, plus the retention policy in D07. Existing `primary` data still
needs a staging migration with a mapping, before/after counts and rollback
procedure. The local Rules tests and Functions unit tests do not prove that
migration or a real-device account-switch/offline scenario.
