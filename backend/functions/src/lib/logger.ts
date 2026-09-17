import { logger } from "firebase-functions/v2";

/**
 * Structured logging helper (spec §20: structured logs). Every log line
 * carries a `domain` so Cloud Logging queries can slice by area.
 */
export function log(
  domain:
    | "auth"
    | "payments"
    | "subscriptions"
    | "notifications"
    | "learning"
    | "analytics"
    | "admin",
  message: string,
  fields: Record<string, unknown> = {},
): void {
  logger.info(message, { domain, ...fields });
}

export function logError(
  domain: Parameters<typeof log>[0],
  message: string,
  fields: Record<string, unknown> = {},
): void {
  logger.error(message, { domain, ...fields });
}
