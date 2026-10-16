# ADR 0016 — Parent notification installations and retry boundaries

Date: 2026-10-16. Status: accepted for local implementation; release gates open.

## Context

The first notification diagnostic reproduced duplicate ownership on shared
devices, unvalidated platforms, consumed dedupe keys after failures/no devices,
and a sender that did not recheck current category preferences. Flutter had no
permission, registration or native notification presentation flow.

## Decision

- Parent-only notification settings explain permission before asking the OS.
  Refusal never blocks learning. Marketing is not enabled by this flow.
  Reminder categories, HH:mm and an explicit supported Brazilian timezone are
  parent-scoped; Rules check types, ownership and server update timestamps.
- Local demo notifications are explicitly labeled `Lelê • Demonstração`.
  Emulator/demo builds do not request an FCM token. A local demo is not evidence
  of FCM/APNs transport or production delivery.
- Use maintained BSD-3-Clause packages `firebase_messaging` (resolved 16.5.0,
  compatible with the pinned Core 4.13.0 release set) and
  `flutter_local_notifications` (22.3.2). No analytics SDK is added or enabled.
  The dependency lock records transitive additions; unused desktop/web backends
  are not Android implementations. The local plugin requires Java 17 and core
  library desugaring, configured without exact-alarm or background-service
  permissions. Release bundle-size measurement and iOS compilation remain gates.
- FCM auto-initialization is disabled by default on Android/iOS. Remote token
  registration requires a signed-in parent's explicit installation opt-in and
  OS permission. Token refresh/login/resume retry synchronization. Foreground
  notifications use the local presenter; background notification payloads use
  the native FCM SDK. Data-only background processing is not implemented.
- `registerDevice` and `unregisterDevice` require Auth and deployed App Check.
  Ignore a submitted UID. Validate Android/iOS, permission, enabled boolean,
  token length and random installation identifier/proof. An installation gets
  a random 128-bit ID and 256-bit proof persisted before its first request;
  the backend stores only a hash of this proof. This proof authorizes only
  notification installation bookkeeping, never account access or entitlement.
- Server-only `notificationInstallations` and `notificationTokens` registries
  enforce one token/installation owner. Rebinding requires the same proof and
  transactionally removes the previous parent's device document. Conflicting
  installations must rotate their FCM token, not claim a different installation.
  Late logout from a previous parent cannot delete the new owner's device.
  Client reads/writes of these registries are denied by default Rules.
- Logout attempts authenticated detachment, then disables token auto-init,
  invalidates the token, and clears this app's tray entries even if detachment
  fails. These operations cannot guarantee immediate remote revocation offline;
  staging must exercise offline logout/account switches and process death.
- Notification payloads contain generic text and a stable notification ID,
  never child names or arbitrary client navigation. Taps open the parent
  dashboard through the existing authentication redirect; no child ID or URL
  from the message is trusted.
- The sender claims a two-minute retry lease. Failed/no-device attempts remain
  retryable. It checks current parent existence/category preference and current
  token ownership before sending, deduplicates tokens, batches at most 500 and
  records settled recipient hashes so a partial retry skips accepted recipients.
  Invalid-token cleanup compares the current device token before deleting it.
  `acceptedAt` means FCM acceptance, not delivery; do not write `sentAt` before
  attempting transport. Existing legacy `sentAt` documents remain deduped and
  need an explicit migration decision if old failed sends must be recovered.

## Limits and remaining gates

An external FCM send cannot be atomic with a Firestore commit. A crash after
FCM acceptance and before receipt persistence may repeat a send. Stable Android
tags/APNs collapse IDs and bounded foreground deduplication reduce repeats but
do not promise exactly-once delivery. The lease does not replace a durable due
queue, expiry, bounded retries or reconciliation.

T18 remains open: the legacy hourly sweep is not a child daily-mission system.
Before release it needs indexed/paginated due work, mission/access/completion
revalidation, timezone-change rescheduling, backoff/expiry and quiet-hour policy.
Achievement and weekly/subscription category controls do not create event
producers that have not yet been implemented.

Real development Firebase configuration, APNs key/capability/signing, physical
Android/iOS foreground/background/terminated tests, offline token cleanup,
permission changes outside the app and staging rollout are still required.
D07 retention/deletion and reviewed consent policies are not decided here;
installation/token registry cleanup must be included in that work.

## Local evidence

`test:notifications:smoke` uses throwaway verified emulator parents and synthetic
tokens, replacing FCM only inside the test process. Eleven registration,
ownership, concurrency, opt-out and retry regressions pass and remove their
fixtures. All 335 Flutter tests, 41 Rules tests and 17 Functions test-file groups
pass. Flutter MCP analysis is clean, hot restart succeeds and no Dart runtime
errors were found. An Android native local demo was visibly posted in the tray;
none of this is evidence of real remote push delivery or an iOS build.
