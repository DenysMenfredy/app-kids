// Explicit, narrow dev/staging setup. No provider credentials or user data.
import {createRequire} from "node:module";

const require = createRequire(new URL("../../test/rules/package.json", import.meta.url));
const auth = require("firebase-tools/lib/auth");
const {requireAuth} = require("firebase-tools/lib/requireAuth");
const {Client} = require("firebase-tools/lib/apiv2");
const {identityOrigin} = require("firebase-tools/lib/api");

async function main() {
  if (process.argv.length !== 3 || process.argv[2] !== "--apply") {
    throw new Error("Use --apply to enable email/password in dev and staging only.");
  }
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error("Sign in with the project-owner Firebase CLI account.");
  const options = {nonInteractive: true};
  auth.setActiveAccount(options, account);
  await requireAuth(options);
  const api = new Client({urlPrefix: identityOrigin(), apiVersion: "admin/v2"});
  const update = {
    signIn: {email: {enabled: true, passwordRequired: true}, allowDuplicateEmails: false},
    emailPrivacyConfig: {enableImprovedEmailPrivacy: true},
    notification: {defaultLocale: "pt-BR"},
  };
  const updateMask = ["signIn.email.enabled", "signIn.email.passwordRequired",
    "signIn.allowDuplicateEmails", "emailPrivacyConfig.enableImprovedEmailPrivacy",
    "notification.defaultLocale"].join(",");
  for (const projectId of ["letrando-dev", "letrando-staging"]) {
    const path = `/projects/${projectId}/config`;
    const {body: before} = await api.get(path);
    if (before.subtype !== "FIREBASE_AUTH") {
      throw new Error(`Expected initialized standard Firebase Auth: ${projectId}`);
    }
    await api.patch(path, update, {queryParams: {updateMask}});
    const {body: after} = await api.get(path);
    if (after.signIn?.email?.enabled !== true ||
        after.signIn?.email?.passwordRequired !== true ||
        after.signIn?.allowDuplicateEmails === true ||
        after.emailPrivacyConfig?.enableImprovedEmailPrivacy !== true ||
        after.notification?.defaultLocale !== "pt-BR") {
      throw new Error(`Email configuration readback failed: ${projectId}`);
    }
    console.log(JSON.stringify({projectId, emailPasswordEnabled: true,
      passwordlessEmailEnabled: false, emailEnumerationProtection: true,
      allowDuplicateEmails: false, notificationLocale: "pt-BR"}));
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
