import { logger } from "firebase-functions/v2";
import { redactChildIdentifiers } from "./log_sanitizer";

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
  logger.info(message, { domain, ...redactChildIdentifiers(fields) as object });
}

export function logError(
  domain: Parameters<typeof log>[0],
  message: string,
  fields: Record<string, unknown> = {},
): void {
  logger.error(message, { domain, ...redactChildIdentifiers(fields) as object });
}
