const CHILD_IDENTIFIER_KEYS = new Set([
  "childid",
  "childuid",
  "childprofileid",
]);

/** Removes child identifiers from structured logs and analytics payloads. */
export function redactChildIdentifiers(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(redactChildIdentifiers);
  }
  if (typeof value !== "object" || value === null || value instanceof Date) {
    return value;
  }

  return Object.fromEntries(
    Object.entries(value).flatMap(([key, nestedValue]) => {
      const normalizedKey = key.toLowerCase().replace(/[_-]/g, "");
      return CHILD_IDENTIFIER_KEYS.has(normalizedKey)
        ? []
        : [[key, redactChildIdentifiers(nestedValue)]];
    }),
  );
}
