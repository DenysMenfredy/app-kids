export interface EntitlementSnapshot {
  active?: unknown;
  features?: unknown;
  validFrom?: Date | null;
  validUntil?: Date | null;
}

/** D02: module one is free; later modules require a current entitlement. */
export function canAccessModule(
  moduleNumber: unknown,
  entitlement: EntitlementSnapshot | null,
  now: Date,
): boolean {
  if (moduleNumber === 1) return true;
  if (
    typeof moduleNumber !== "number" ||
    !Number.isInteger(moduleNumber) ||
    moduleNumber < 2 ||
    entitlement?.active !== true ||
    !Array.isArray(entitlement.features) ||
    !entitlement.features.includes("full_curriculum")
  ) {
    return false;
  }

  const validFrom = entitlement.validFrom;
  const validUntil = entitlement.validUntil;
  return validFrom instanceof Date &&
    validUntil instanceof Date &&
    validFrom.getTime() <= now.getTime() &&
    validUntil.getTime() > now.getTime();
}
