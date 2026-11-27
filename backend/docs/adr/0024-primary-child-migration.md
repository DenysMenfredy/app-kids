# ADR 0024 — Legacy `primary` child migration and dual-read compatibility

Date: 2026-11-27 · Status: accepted for local rehearsal; remote migration not authorized

## Context

Early builds used the literal child document ID `primary`. The app still has a
fallback for it, while newer profiles receive server-issued IDs. A migration
must move existing child data without breaking installed clients and without
inventing a deletion or retention policy. D07 remains open; no remote data was
inspected for this decision.

## Decision

1. Inventory the legacy model before writing: count `users/{uid}/children/primary`
   documents, their child-scoped references (bookmarks, daily summaries,
   sessions, activity attempts, learning progress, gamification, assessment
   results and child-creation requests), and orphan references that have no
   primary child. Inventory returns aggregate counts only, never names, e-mail
   or UIDs.
2. Migrate by **copying** the primary child to a server-generated child ID.
   Copy the child-scoped data with deterministic migrated IDs:
   - sessions: `migrated_<oldSessionId>`, with `childId` changed;
   - attempts: new session prefix plus the original request suffix;
   - progress: `<newChildId>_<lesson>` (or `migrated_<oldId>`), with `childId`;
   - gamification and assessment results: new child ID;
   - bookmarks and daily summaries: same document IDs under the new child.
   Child-creation request documents are inventoried but not repointed; they are
   idempotency records, not child state. The old `primary` document and all old
   references stay in place for installed clients. No document is deleted by
   the forward migration.
3. Record a server-owned mapping at `users/{uid}/migrations/primaryChild` with
   `schemaVersion`, `flowVersion: "primary-migration-v1"`, `legacyId: "primary"`,
   `newChildId`, `status` and aggregate counts. The owner may read the mapping;
   clients can never write it.
4. The migration is idempotent and non-overwriting: a rerun reuses the mapping
   and only creates missing copies. A post-migration write under the new child
   is therefore not clobbered. Dry-run is the default; `--apply` is required to
   write. A partial run leaves `status: "pending"` and can be resumed.
5. New clients use dual-read: if `status == "migrated"` and the new child exists,
   hide `children/primary` from the child list and select `newChildId`; if the
   mapping is absent, rolled back, or the new child is missing, keep the current
   `primary` fallback. Old clients continue to read the untouched primary child.
6. Orphan references are reported but never turned into a child or silently
   deleted. They need an explicit owner decision and a separate cleanup.
7. Rollback deletes the copied child (including its copied bookmarks/daily
   summaries), copied sessions/attempts/progress/gamification/assessment and the
   mapping. It leaves the legacy `primary` child and all old references intact.
   It assumes the new child has not received production writes; after cutover,
   restore the export first instead of using rollback.
8. The rehearsal and tooling accept only the Firestore emulator, refuse a
   project containing `production`, and use synthetic fixtures. No remote
   project, backup or production data is touched. A real migration requires an
   owner-approved export/backup, staging rehearsal and a cutover window.

## Consequences and remaining gates

- **App compatibility:** a mobile change is required to hide the legacy child
  when a migrated mapping exists. Until it ships, the new child and `primary`
  may both appear in a list; old clients still work.
- **Writes during the window:** old clients write only to `primary`; new clients
  write to the new child. Dual-read does not merge future writes. The cutover
  must stop old clients or accept a stale primary until they update; D07 and
  the owner decide the window.
- **Remote migration:** the local rehearsal is not evidence of remote counts,
  orphans or backup/restore. Production/staging execution remains blocked on
  owner authorization and D07 retention.
- **Rollback after use:** rollback is destructive for post-migration data under
  the new child. Use it only before cutover or restore a verified export.
- **Not covered:** merging old/new writes, deleting legacy data, retention
  periods, child-profile deletion and the production migration runbook.
