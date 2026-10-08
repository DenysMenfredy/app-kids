import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

import { Role } from "../domain/roles";

/**
 * Authorization guards for callable functions (spec §12: authorize every
 * privileged operation server-side; Admin SDK bypasses Security Rules, so
 * these checks are mandatory in backend code).
 */

/**
 * Whether callables demand a valid App Check token.
 *
 * App Check attests that the caller is a genuine build of the app (spec
 * §12). The emulator has no app binary to attest and no App Check backend
 * to issue tokens, so enforcement is skipped there — and only there, so
 * every deployed environment still requires it. Authentication and the
 * role checks below are unaffected either way.
 */
export const enforceAppCheck = process.env.FUNCTIONS_EMULATOR !== "true";

export function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Faça login para continuar.");
  }
  return uid;
}

/**
 * Email/password parents must confirm ownership of their address before
 * creating a child profile or starting checkout. Federated Google and Apple
 * sign-ins remain available without a second verification step.
 */
export function requireVerifiedParentEmail(request: CallableRequest): void {
  const provider = request.auth?.token?.firebase?.sign_in_provider;
  const emailVerified = request.auth?.token?.email_verified === true;
  if (provider === "password" && !emailVerified) {
    throw new HttpsError(
      "failed-precondition",
      "Confirme seu e-mail antes de cadastrar um perfil infantil ou iniciar uma assinatura.",
    );
  }
}

export function requireRole(request: CallableRequest, ...roles: Role[]): string {
  const uid = requireAuth(request);
  const role = request.auth?.token?.role as Role | undefined;
  if (!role || !roles.includes(role)) {
    throw new HttpsError(
      "permission-denied",
      "Você não tem permissão para esta operação.",
    );
  }
  return uid;
}

export function requireString(
  value: unknown,
  field: string,
  { maxLength = 500 }: { maxLength?: number } = {},
): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maxLength) {
    throw new HttpsError("invalid-argument", `Campo inválido: ${field}`);
  }
  return value;
}
