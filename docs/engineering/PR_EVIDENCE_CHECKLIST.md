# PR evidence checklist

Every PR that changes behavior, configuration, deploy or data includes evidence
in its body or as a PR comment. Evidence is required for gate reports; "it
works" is not evidence.

## Rules

- Use synthetic accounts and content. Never include a real child name, e-mail,
  UID, token, purchase token or screenshot with PII.
- Redact identifiers as `<uid>`, `<email>`, `<child>`.
- State the environment: emulator, `letrando-dev`, `letrando-staging`, or
  physical device model + Android version.
- State the commit SHA and the command; attach raw output where possible.
- Never paste secrets, service-account JSON, keystore or `.env` contents.

## Minimum by change type

| Change | Evidence |
| --- | --- |
| App UI/flow | `flutter analyze`, `flutter test`, screenshots or video of the flow with synthetic data |
| Cloud Functions | `npm test` output; emulator call trace; App Check behavior when relevant |
| Security Rules | `npm test` output; explicit allow/deny case names |
| Deploy | workflow run URL, project alias, deployed function list, smoke output |
| Physical device | device model/OS, build SHA, full-flow checklist, screen recording, crash log if any |
| App Check | token provider, allowed case, denied case, console registration proof without secrets |
| Billing | store environment (sandbox/test), product ID, purchase/restore/cancel/revoke cases, server log correlation without tokens |
| Data migration | before/after counts, idempotent rerun, rollback rehearsal |

## Gate report template

- Gate: G1 / G2 / G3
- Status: pass / fail
- Evidence: links to PRs and runs
- Failed: what did not pass
- Blocked by: owner or dependency
- Next: next concrete step
