import { createHash } from "node:crypto";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { db, paths } from "../lib/firestore";

export const tokenHash = (value: string): string =>
  createHash("sha256").update(value).digest("hex");

export function installationInput(data: Record<string, unknown>): {
  deviceId: string; secretHash: string;
} {
  if (typeof data.deviceId !== "string" || !/^[a-f0-9]{32}$/.test(data.deviceId) ||
      typeof data.installationSecret !== "string" || !/^[a-f0-9]{64}$/.test(data.installationSecret)) {
    throw new HttpsError("invalid-argument", "Instalação inválida.");
  }
  return { deviceId: data.deviceId, secretHash: tokenHash(data.installationSecret) };
}

/** Possession of an installation secret, not a submitted UID, permits rebinding. */
export async function registerInstallation(uid: string, data: Record<string, unknown>): Promise<void> {
  const { deviceId, secretHash } = installationInput(data);
  const { platform, fcmToken, permission, notificationsEnabled } = data;
  if ((platform !== "android" && platform !== "ios") ||
      typeof fcmToken !== "string" || fcmToken.length < 1 || fcmToken.length > 4096 ||
      !["authorized", "provisional", "denied"].includes(String(permission)) ||
      typeof notificationsEnabled !== "boolean") {
    throw new HttpsError("invalid-argument", "Dados de notificação inválidos.");
  }
  const hash = tokenHash(fcmToken);
  const registry = db().doc(`notificationInstallations/${deviceId}`);
  const tokenRef = db().doc(`notificationTokens/${hash}`);
  await db().runTransaction(async (tx) => {
    const [installation, token, parent] = await tx.getAll(registry, tokenRef, db().doc(paths.user(uid)));
    if (!parent.exists) throw new HttpsError("failed-precondition", "Perfil ainda não disponível.");
    if (installation.exists && installation.get("secretHash") !== secretHash) {
      throw new HttpsError("permission-denied", "Instalação não reconhecida.");
    }
    if (token.exists && token.get("deviceId") !== deviceId) {
      throw new HttpsError("failed-precondition", "Renove o token deste dispositivo.");
    }
    const previousUid = installation.get("uid") as string | undefined;
    const oldHash = installation.get("tokenHash") as string | undefined;
    if (previousUid && previousUid !== uid) tx.delete(db().doc(`${paths.devices(previousUid)}/${deviceId}`));
    if (oldHash && oldHash !== hash) tx.delete(db().doc(`notificationTokens/${oldHash}`));
    tx.set(registry, { uid, deviceId, secretHash, tokenHash: hash, updatedAt: FieldValue.serverTimestamp() });
    tx.set(tokenRef, { uid, deviceId });
    tx.set(db().doc(`${paths.devices(uid)}/${deviceId}`), {
      platform, fcmToken, tokenHash: hash, permission,
      notificationsEnabled: notificationsEnabled && permission !== "denied",
      lastSeenAt: FieldValue.serverTimestamp(),
    });
  });
}

export async function unregisterInstallation(uid: string, data: Record<string, unknown>): Promise<void> {
  const { deviceId, secretHash } = installationInput(data);
  const registry = db().doc(`notificationInstallations/${deviceId}`);
  await db().runTransaction(async (tx) => {
    const installation = await tx.get(registry);
    // A late logout from A must not remove B's freshly rebound installation.
    if (!installation.exists || installation.get("uid") !== uid) return;
    if (installation.get("secretHash") !== secretHash) {
      throw new HttpsError("permission-denied", "Instalação não reconhecida.");
    }
    tx.delete(db().doc(`${paths.devices(uid)}/${deviceId}`));
    tx.delete(db().doc(`notificationTokens/${installation.get("tokenHash")}`));
    tx.update(registry, { uid: null, tokenHash: null, updatedAt: FieldValue.serverTimestamp() });
  });
}
