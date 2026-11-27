# GitHub governance — MVP

Applied on 2026-11-27 to `DenysMenfredy/app-kids`.

## Branch protection (`main`)

- Pull request required before merging; no direct pushes.
- Required status checks: `Flutter app`, `Cloud Functions`, `Security Rules`
  (job names from `.github/workflows/ci.yml`).
- Conversation resolution required.
- Linear history required; squash merge only.
- Force pushes and branch deletion blocked.
- Rules apply to admins.
- Approvals required: 0. Reason: the repository has one GitHub identity today;
  a required approval would block every PR. Revisit when a second reviewer
  account exists.
- Code-owner review is not required, although `.github/CODEOWNERS` documents
  ownership.

## Merge policy

- One behavior per PR.
- Squash merge with a conventional title.
- The PR body follows `.github/pull_request_template.md`.
- Evidence follows `docs/engineering/PR_EVIDENCE_CHECKLIST.md`.

## How to verify

```sh
gh api repos/DenysMenfredy/app-kids/branches/main/protection
gh api repos/DenysMenfredy/app-kids \
  --jq '{allow_squash_merge,allow_merge_commit,allow_rebase_merge}'
```

## Limitations

- All agents authenticate as `DenysMenfredy`; GitHub does not allow
  self-approval. The current control is CI plus evidence, not a second human
  review.
- Required checks are job names. Renaming a job in `ci.yml` requires updating
  branch protection in the same change.
