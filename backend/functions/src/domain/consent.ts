/**
 * Parent consent — versioned acceptance of the child-data terms.
 *
 * D07 (the reviewed legal text) is still open. `CURRENT_CONSENT_TEXT_VERSION`
 * is therefore an explicit placeholder: it is a version identifier, not a
 * substitute for legal copy. When D07 lands, add the approved version to the
 * allowlist, bump the current one and require re-consent. Records that do not
 * match an allowlisted version fail closed for child-data writes.
 */

export const CURRENT_CONSENT_TEXT_VERSION = "d07-placeholder-v1";

/** Server-side allowlist; a client can never submit an arbitrary version. */
export const SUPPORTED_CONSENT_TEXT_VERSIONS = [
  CURRENT_CONSENT_TEXT_VERSION,
] as const;

export const CONSENT_PURPOSES = ["notifications", "marketing", "analytics"] as const;
export type ConsentPurpose = (typeof CONSENT_PURPOSES)[number];
export type ConsentPurposes = Record<ConsentPurpose, boolean>;

/**
 * Where the consent was collected. The callable cannot prove a platform, so
 * this is an allowlisted source label, not a security boundary.
 */
export const CONSENT_ORIGINS = ["parent_app"] as const;
export type ConsentOrigin = (typeof CONSENT_ORIGINS)[number];

export interface ParentConsentInput {
  textVersion: string;
  purposes: ConsentPurposes;
  origin: ConsentOrigin;
}

export type ConsentRefusalCode = "consent_required" | "consent_outdated";

export interface ConsentRefusal {
  code: ConsentRefusalCode;
  requiredTextVersion: string;
  acceptedTextVersion?: string;
}

const inputKeys = ["origin", "purposes", "textVersion"] as const;

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(value: Record<string, unknown>, allowed: readonly string[]): boolean {
  const keys = Object.keys(value);
  return keys.length === allowed.length && keys.every((key) => allowed.includes(key));
}

export function parseConsentPurposes(value: unknown): ConsentPurposes | null {
  if (!isPlainObject(value) || !hasExactKeys(value, CONSENT_PURPOSES)) return null;
  const purposes = {} as ConsentPurposes;
  for (const purpose of CONSENT_PURPOSES) {
    if (typeof value[purpose] !== "boolean") return null;
    purposes[purpose] = value[purpose];
  }
  return purposes;
}

/** Validates the callable payload. Returns null for anything a client invented. */
export function parseParentConsentInput(value: unknown): ParentConsentInput | null {
  if (!isPlainObject(value) || !hasExactKeys(value, inputKeys)) return null;
  if (typeof value.textVersion !== "string") return null;
  if (!(SUPPORTED_CONSENT_TEXT_VERSIONS as readonly string[]).includes(value.textVersion)) {
    return null;
  }
  if (typeof value.origin !== "string" ||
      !(CONSENT_ORIGINS as readonly string[]).includes(value.origin)) {
    return null;
  }
  const purposes = parseConsentPurposes(value.purposes);
  if (!purposes) return null;
  return {
    textVersion: value.textVersion,
    purposes,
    origin: value.origin as ConsentOrigin,
  };
}

export function purposesEqual(a: unknown, b: ConsentPurposes): boolean {
  const left = parseConsentPurposes(a);
  return left !== null &&
    CONSENT_PURPOSES.every((purpose) => left[purpose] === b[purpose]);
}

/**
 * Why a stored consent cannot authorize child-data writes, or null when it can.
 * Recording is fail-closed: a malformed or older document is not silently
 * treated as the current consent.
 */
export function consentRefusal(
  record: Record<string, unknown> | null | undefined,
  uid: string,
): ConsentRefusal | null {
  if (!record) {
    return { code: "consent_required", requiredTextVersion: CURRENT_CONSENT_TEXT_VERSION };
  }
  const acceptedTextVersion =
    typeof record.textVersion === "string" ? record.textVersion : undefined;
  const outdated = (): ConsentRefusal => ({
    code: "consent_outdated",
    requiredTextVersion: CURRENT_CONSENT_TEXT_VERSION,
    ...(acceptedTextVersion ? { acceptedTextVersion } : {}),
  });

  if (record.schemaVersion !== 1) return outdated();
  if (record.uid !== uid) return outdated();
  if (record.acceptedAt === undefined || record.acceptedAt === null) return outdated();
  if (typeof record.textVersion !== "string" ||
      !(SUPPORTED_CONSENT_TEXT_VERSIONS as readonly string[]).includes(record.textVersion)) {
    return outdated();
  }
  if (!(CONSENT_ORIGINS as readonly string[]).includes(String(record.origin))) {
    return outdated();
  }
  if (!parseConsentPurposes(record.purposes)) return outdated();
  return null;
}
