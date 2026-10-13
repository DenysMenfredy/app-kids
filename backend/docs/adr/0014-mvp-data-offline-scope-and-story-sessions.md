# ADR 0014 — MVP profile/offline scope and versioned story lessons

Date: 2026-10-09 · Status: accepted for local implementation; release gates open

## Product decisions

The product owner approved D04–D06 on 2026-10-09:

- D04: catalog and history may be cached; loading protected content and recording
  authoritative progress require a connection. Downloaded bytes cannot be
  remotely recovered. There is no offline completion/reward queue in the MVP.
- D05: child data is a short name/nickname, an offered avatar and integer age
  3–7. No exact birth date is collected. Existing backend/Rules allowlists stay
  in force; this does not approve consent wording or retention periods.
- D06: the launch scope is the existing seven modules, 37 lessons, six
  comprehension stories and six library books. Finishing the existing stories
  adds six required comprehension activities, not additional lessons or titles.

D07 remains open and needs a reviewed retention/deletion matrix. No account
deletion policy, analytics collection or production deployment is activated
or considered completed by this ADR.

## Story and lesson contract

Lessons and activities carry `schemaVersion: 1` and positive `contentVersion`.
The first 31 lessons retain tap → match → trace → listen. Lessons 032–037 append
one `story` activity referencing a published, versioned `stories/{storyId}`.
Its bounded, uniquely identified pages use text and supported symbolic
illustrations; narration uses the existing pt-BR TTS engine. Arbitrary remote
image/audio URLs and unknown activity/schema types are rejected. Questions
have stable IDs, bounded unique choices and one answer present in those choices.

Publishing a lesson validates its full manifest, exercises and optional story,
then publishes them atomically. Direct activity/story publication is rejected.
Republishing increments the lesson revision; unpublishing remains possible
even if draft content is invalid. Seed validation precedes writes, and lessons,
activities and stories must be imported together.

New sessions capture the pedagogy fingerprint, revision, activity order and
existing owner/child scope. Attempts, renewed presence and completion reread
publication and current entitlement and reject edited bundles. Audit-only
timestamp updates do not change the fingerprint. Story responses persist only
question ID and selected option; the server computes correction. All questions
must be correct before the final activity and lesson finish. Existing atomic
first-reward and daily-summary transactions include comprehension evidence.

Flutter loads protected payloads with `Source.server`, scopes the run cache to
account/child and refreshes on each intro. Startup sends the loaded revision and
waits for server acknowledgement before navigation. Within a run, pages and
narration use the already loaded text; local feedback is not authoritative.
Unconfirmed story completion shows a re-open action, not a success celebration.

## Rollout and compatibility

Stage versioned content and backend before the new client; test all six stories
and the unchanged introductory free module. Seed only the intended dev/staging
environment after reviewing content edits. Local startup replaces committed
educational documents, never family records. Older four-step clients cannot
finish five-step story lessons; revised manifests require an upgrade/minimum
client plan before rollout to families. Changed in-flight manifests must restart;
historical progress and rewards are never migrated or reminted. Old sessions
without fingerprints keep their existing checks, but unversioned/changed
manifests are not accepted as newly valid content.

Rollback preserves earned progress, summaries and backend safety checks.
Re-publish a compatible versioned manifest with matching payloads and restart
affected sessions; never reset rewards or restore family data to undo content.
Physical Android/iOS narration, editorial review and staging compatibility
and release checks remain open.
