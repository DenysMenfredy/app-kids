import { onCall } from "firebase-functions/v2/https";
import { enforceAppCheck, requireAuth } from "../lib/guards";
import { registerInstallation, unregisterInstallation } from "./device_registration";

export const registerDevice = onCall({ enforceAppCheck }, async (request) => {
  const uid = requireAuth(request);
  await registerInstallation(uid, request.data ?? {});
  return { ok: true };
});

export const unregisterDevice = onCall({ enforceAppCheck }, async (request) => {
  const uid = requireAuth(request);
  await unregisterInstallation(uid, request.data ?? {});
  return { ok: true };
});
