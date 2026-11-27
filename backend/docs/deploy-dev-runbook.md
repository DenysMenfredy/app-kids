# Deploy the backend to letrando-dev

This is the runbook for the first real backend deploy (G1) and the repeatable
dev path afterwards. It covers Cloud Functions, Firestore rules and indexes,
Storage rules, the curriculum seed, App Check and the synthetic-account smoke
check. Production is out of scope: it is never seeded by this workflow and its
payment credentials/data must not be used during development.

The deploy workflow is manual (`workflow_dispatch`), uses GitHub Environments
for approval, and authenticates to GCP with Workload Identity Federation. No
service-account JSON key is stored in GitHub or in the repository.

## What the workflow does

1. Builds and tests `backend/functions`, then runs the Security Rules tests.
2. Fails early if the selected GitHub Environment has no
   `GCP_WORKLOAD_IDENTITY_PROVIDER` or `GCP_DEPLOY_SERVICE_ACCOUNT`.
3. Deploys `firestore:rules`, `firestore:indexes`, `storage` and `functions`
   to `letrando-<environment>`.
4. Seeds `backend/seed/` for dev and staging. The seed uses stable document
   IDs and merge/overwrite writes, so re-running it converges to the same
   content; production is rejected by the script and skipped by the workflow.
5. Runs `npm run smoke:dev` after the dev deploy and uploads its JSON evidence
   as the `dev-smoke-evidence` artifact.

## One-time owner setup

The order matters: billing and the project services are prerequisites for
Functions v2 and Cloud Build, and the GitHub Environment cannot usefully exist
before the Workload Identity provider does.

### 1. Billing, project services and data stores

Cloud Functions v2, Cloud Build, Artifact Registry and Cloud Run require the
Blaze plan. Firestore/Storage need their APIs enabled and their default
resources created before the first rules deploy.

```sh
# Owner account with Billing Account Administrator on the target account.
gcloud billing projects link letrando-dev --billing-account=<BILLING_ACCOUNT_ID>
```

Then, in the Firebase console for `letrando-dev`:

- **Firestore Database** → Create database → Native mode →
  `southamerica-east1`.
- **Storage** → Get started → default bucket
  `letrando-dev.firebasestorage.app`.
- Confirm **Cloud Functions**, **Cloud Build**, **Artifact Registry**,
  **Cloud Run** and **Firestore** APIs are enabled (the first deploy enables
  some of them, but a billing-disabled project fails before that).

### 2. Workload Identity Federation for GitHub Actions

Run once with an owner account. Replace the project number only if the
project changes (the repo records `293659867381` for `letrando-dev`).

```sh
PROJECT=letrando-dev
PROJECT_NUMBER=293659867381
REPO=DenysMenfredy/app-kids
SA=deploy-backend-dev@${PROJECT}.iam.gserviceaccount.com

gcloud iam workload-identity-pools create github \
  --project="$PROJECT" --location=global --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc github \
  --project="$PROJECT" --location=global --workload-identity-pool=github \
  --display-name="$REPO" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='$REPO'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

gcloud iam service-accounts create deploy-backend-dev \
  --project="$PROJECT" --display-name="Backend deploy (dev)"

# Broad for a dev deploy identity; tighten after the first green run.
for role in \
  roles/firebase.admin \
  roles/cloudfunctions.admin \
  roles/run.admin \
  roles/artifactregistry.writer \
  roles/cloudbuild.builds.editor \
  roles/storage.admin \
  roles/datastore.user \
  roles/iam.serviceAccountUser \
  roles/serviceusage.serviceUsageConsumer \
  roles/firebaseappcheck.admin
do
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:$SA" --role="$role" --quiet
done

gcloud iam service-accounts add-iam-policy-binding "$SA" \
  --project="$PROJECT" --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/attribute.repository/${REPO}"
```

The provider resource to store in GitHub is:

```
projects/293659867381/locations/global/workloadIdentityPools/github/providers/github
```

### 3. GitHub Environment

Create the `dev` Environment with required reviewers (the release workflow
uses the same environment pattern). Then set its variables and the smoke
secret:

```sh
gh api --method PUT repos/DenysMenfredy/app-kids/environments/dev

gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER --env dev \
  --body "projects/293659867381/locations/global/workloadIdentityPools/github/providers/github"
gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --env dev \
  --body "deploy-backend-dev@letrando-dev.iam.gserviceaccount.com"

# Paste the debug token from step 4; never commit it.
gh secret set DEV_APP_CHECK_DEBUG_TOKEN --env dev
```

Add required reviewers in **Settings → Environments → dev → Required
reviewers** so a human authorizes the deploy. The workflow does not
auto-approve, merge or promote to production.

### 4. App Check for the dev app

App Check is enforced by every deployed callable (`enforceAppCheck`). A
missing or invalid token returns `401 UNAUTHENTICATED`, which can look like an
Auth problem. The Android dev app is
`1:293659867381:android:45886330baeba918606dbc`. The iOS app remains registered
in Firebase but is deferred by ADR 0019; do not configure App Attest for the MVP.

1. **Register providers** in **App Check → Apps**:
   - Android `Lele Dev Android`: Play Integrity.
2. **Register a debug token** for the Android app. Run a debug build with the
   dev config and read the token from logcat:
   ```sh
   flutter run --dart-define=USE_FIREBASE=true --dart-define=APP_ENV=dev
   adb logcat | grep -i "App Check"
   ```
   The line contains `FirebaseAppCheck debug token: <uuid>`. Register that UUID
   under **App Check → Apps → Lele Dev Android → Manage debug tokens**. The
   same value goes into the `DEV_APP_CHECK_DEBUG_TOKEN` GitHub secret.
   Debug tokens are for debug builds only; never ship one in a release.
3. **Verify the console state** with the owner account:
   ```sh
   ACCESS_TOKEN="$(gcloud auth print-access-token)"
   curl -sS -H "Authorization: Bearer $ACCESS_TOKEN" \
     "https://firebaseappcheck.googleapis.com/v1/projects/letrando-dev/apps/1:293659867381:android:45886330baeba918606dbc/appCheckConfig"
   ```
   A configured provider returns its config; a 404 means no provider is
   registered yet. Play Integrity also needs the Android app linked in Play
   Console (internal testing track is enough for the first check).
4. **Release attestation is separate**: a green dev deploy with a debug token
   does not prove Play Integrity on a release build. Install a release build on
   a physical device and confirm token exchange in App Check metrics before
   marking the Android MVP acceptance criterion complete. iOS stays deferred by
   ADR 0019.

## Running the deploy

```sh
gh workflow run deploy-backend.yml -f environment=dev
gh run list --workflow=deploy-backend.yml --limit 1
gh run watch <RUN_ID>
```

Expected evidence: a green run, the deploy log ending with the Functions,
rules, indexes and Storage deploy summaries, the seed summary, and a
`dev-smoke-evidence` artifact whose `status` is `passed`.

Local fallback (owner Firebase CLI login; do not use production creds):

```sh
cd backend
npx --yes firebase-tools@13 deploy \
  --only firestore:rules,firestore:indexes,storage,functions \
  --project letrando-dev --non-interactive

cd functions
npm run build
npm run seed -- --project letrando-dev
APP_CHECK_DEBUG_TOKEN=... npm run smoke:dev -- \
  --project letrando-dev --evidence /tmp/dev-smoke.json
```

The smoke script creates `smoke+<random>@example.test`, verifies the Auth
bootstrap, exchanges the App Check debug token, creates one child profile
twice with the same `requestId`, checks that a request without App Check is
rejected, and removes the synthetic account and every document under it. It
refuses anything except `letrando-dev` and `letrando-staging`, and its JSON
evidence contains no email, UID or token.

## Evidence to attach to the G1 record

- Workflow run URL and the green check names.
- Seed output (collection/file counts) and the `dev-smoke-evidence` artifact
  with `status: "passed"`.
- App Check console/metrics showing the dev Android app and an accepted debug
  token exchange; no screenshots with personal data.
- Confirmation that no production project, payment credential or real child
  data was used.

## Rollback

Rollback is a redeploy of the last green commit, not a data deletion.

1. Find the last green `main` commit and create a clean worktree from it.
2. Redeploy the affected surface with the same command:
   ```sh
   cd backend
   npx --yes firebase-tools@13 deploy \
     --only firestore:rules,firestore:indexes,storage,functions \
     --project letrando-dev --non-interactive
   ```
3. Rules/indexes: restoring the previous `firestore.rules` /
   `firestore.indexes.json` and redeploying reverts the configuration. Removing
   an index does not delete documents, but can break queries until the
   previous index is restored.
4. Functions: Firebase keeps the previous revisions; redeploying the previous
   commit moves traffic back. There is no per-function version selector in
   this workflow, so keep the commit SHA in the G1 record.
5. Seed: it is additive/overwriting, not deleting. Re-run the seed from the
   previous commit to restore content; never delete Firestore collections as a
   rollback.

If a rollback changes auth, payment, entitlement or child-data boundaries,
record it as an ADR in `backend/docs/adr/` before the next deploy.

## Readiness check — 2026-11-27

Observed with an owner Firebase token and the GitHub API before this PR:

| Item | State |
| --- | --- |
| `letrando-dev` billing | disabled (`billingEnabled: false`) |
| Firestore API / database | API disabled; no database |
| Cloud Functions API | disabled; no functions |
| Storage buckets | none |
| App Check API | enabled; no provider config, no debug tokens |
| Firebase apps | Android dev app registered; iOS deferred by ADR 0019 |
| GitHub `dev` Environment | absent |
| GitHub repo variables/secrets | none (`GCP_*` missing) |

So the first deploy cannot be green yet. The blocking owner action is to enable
Blaze billing and create the Firestore/Storage resources (step 1), then finish
steps 2–4. Until then this PR prepares the automation and the evidence path but
does not claim a deploy.

## Troubleshooting

| Symptom | Cause / action |
| --- | --- |
| `SERVICE_DISABLED` or billing error | Step 1 is incomplete; enable Blaze and the APIs. |
| `google-github-actions/auth` permission/attribute error | WIF provider, repository condition or `workloadIdentityUser` binding is wrong. |
| Callable returns `401 UNAUTHENTICATED` | App Check header missing, debug token not registered for this Android app, or token expired. |
| `createChildProfile` fails with `FAILED_PRECONDITION` | The synthetic user is not email-verified; the script sets it, so check for a stale token. |
| Seed stops with “Refusing to seed a production project” | Expected; production content goes through `manageContent`. |
| Smoke cleanup error | The script deletes Auth first, then `users/{uid}`; re-run it and inspect the Auth/Firestore records for the synthetic `@example.test` account only. |
