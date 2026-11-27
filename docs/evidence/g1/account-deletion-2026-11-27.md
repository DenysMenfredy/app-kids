# G1 — account deletion in the app (local evidence, 2026-11-27)

Status: **local flow passed** against the Emulator Suite. Cloud, physical
device and the scheduled worker run remain later gates.

## Environment

| Item | Value |
| --- | --- |
| Device | `emulator-5554`, Android 16 / API 36, 540×1200 for the run |
| Stack | Auth 9099, Firestore 8081, Functions 5001 (host 8080 is an unrelated Adminer) |
| Backend | `main` at `ae58d4b` (request callable from T08b; worker merged) |
| App | account-deletion branch, debug build with `USE_FIREBASE=true` and `USE_EMULATOR=true`; local Firestore port override to 8081, **not committed** |
| Account | one synthetic password account; no real family data |

## Flow observed

1. Parent dashboard shows **Configurações da conta**.
2. Settings explains what is deleted and warns that deleting the account does
   not cancel a Google Play/App Store subscription; the store-management link
   is visible.
3. Confirmation dialog repeats the deletion and subscription warning.
4. Password reauthentication is required before the request. The app refreshes
   the ID token after reauthentication.
5. `requestAccountDeletion` is called with a bounded `requestId`.
6. The pending dialog shows status **Solicitada**, explains that processing
   continues outside the app and that there is no store cancellation, and
   offers **Sair da conta**.
7. After signing out, the app lands on the login screen and does not recreate
   the account. The Flutter preferences file is empty on this test device, so
   the cached parent/child, pending lesson and notification keys are gone.

## Backend evidence

Tombstone read from the local Firestore emulator (UID/request ID omitted):

```text
exists=true
status=requested
schemaVersion=1
flowVersion=t08b-placeholder-v1
uidMatches=true
hasRequestId=true
hasReauthenticatedAt=true
hasSessionsRevokedAt=true
```

The request is server-owned, idempotent and blocks new child-data operations;
the app never writes the tombstone. No retention deadline is displayed, because
D07 is still open.

## Screenshots

- `docs/evidence/g1/account-deletion/01-confirmation-dialog.png`
- `docs/evidence/g1/account-deletion/02-reauthentication.png`
- `docs/evidence/g1/account-deletion/03-pending-dialog.png`
- `docs/evidence/g1/account-deletion/04-settings-entry.png`
- `docs/evidence/g1/account-deletion/05-signed-out.png`

The account e-mail was cropped out of the screenshots; names are synthetic.

## Tests

- `flutter analyze`: zero issues.
- `flutter test`: **400** tests passing, including 6 new account-deletion tests:
  error-code mapping, request id/result bounds, local cleanup scope, password
  reauthentication → request → sign-out, `reauth_required` staying on the
  password step, and `session_revocation_failed` retry/sign-out.

## Limits

- The scheduled deletion worker was not executed as a cron/scheduler run; it is
  covered by the backend tests from PR #11 and the local tombstone above.
- Store subscription cancellation links were displayed but not opened in this
  run.
- Physical device, cloud and App Check remain later gates.
