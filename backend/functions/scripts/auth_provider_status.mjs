// Read-only dev/staging provider inventory. Never print config bodies or tokens.
import {createRequire} from "node:module";
import {existsSync, readFileSync} from "node:fs";

const require = createRequire(new URL("../../test/rules/package.json", import.meta.url));
const auth = require("firebase-tools/lib/auth");
const {requireAuth} = require("firebase-tools/lib/requireAuth");
const {Client} = require("firebase-tools/lib/apiv2");
const {identityOrigin, cloudbillingOrigin} = require("firebase-tools/lib/api");

async function main() {
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error("Sign in with the project-owner Firebase CLI account.");
  const options = {nonInteractive: true};
  auth.setActiveAccount(options, account);
  await requireAuth(options);
  const api = new Client({urlPrefix: identityOrigin(), apiVersion: "admin/v2"});
  const billing = new Client({urlPrefix: cloudbillingOrigin(), apiVersion: "v1"});
  for (const projectId of ["letrando-dev", "letrando-staging"]) {
    try {
      const {body: config} = await api.get(`/projects/${projectId}/config`);
      const {body: providers} = await api.get(`/projects/${projectId}/defaultSupportedIdpConfigs`);
      const {body: billingInfo} = await billing.get(`/projects/${projectId}/billingInfo`);
      const environment = projectId.slice("letrando-".length);
      const publicFile = new URL(`../../../lele/config/firebase.${environment}.json`, import.meta.url);
      const publicConfig = existsSync(publicFile) ? JSON.parse(readFileSync(publicFile, "utf8")) : {};
      console.log(JSON.stringify({
        projectId,
        initialized: true,
        emailPasswordEnabled: config.signIn?.email?.enabled === true,
        passwordRequired: config.signIn?.email?.passwordRequired === true,
        allowDuplicateEmails: config.signIn?.allowDuplicateEmails === true,
        anonymousEnabled: config.signIn?.anonymous?.enabled === true,
        phoneEnabled: config.signIn?.phoneNumber?.enabled === true,
        emailEnumerationProtection: config.emailPrivacyConfig?.enableImprovedEmailPrivacy === true,
        authorizedDomains: config.authorizedDomains ?? [],
        notificationLocale: config.notification?.defaultLocale ?? null,
        subtype: config.subtype ?? null,
        billingEnabled: billingInfo.billingEnabled === true,
        providers: (providers.defaultSupportedIdpConfigs ?? []).map((provider) => ({
          id: provider.name?.split("/").at(-1),
          enabled: provider.enabled === true,
          hasClientId: Boolean(provider.clientId),
          hasClientSecret: Boolean(provider.clientSecret),
          clientIdMatchesPublicConfig: provider.name?.endsWith("/google.com") &&
            publicConfig.GOOGLE_WEB_CLIENT_ID ?
            provider.clientId === publicConfig.GOOGLE_WEB_CLIENT_ID : null,
        })),
      }));
    } catch (error) {
      console.log(JSON.stringify({projectId, status: error.status ?? null,
        message: error.message}));
      process.exitCode = 1;
    }
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
