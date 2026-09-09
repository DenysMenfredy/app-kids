import { logger } from "firebase-functions/v2";

/**
 * Server-side product analytics (spec §17). Events are written as
 * structured Cloud Logging entries under the stable `letrando_event` tag;
 * a logging sink exports them to BigQuery (configured per environment).
 * Client-side events flow through Firebase Analytics in the app.
 */
export type ServerEventName =
  | "subscription_started"
  | "subscription_renewed"
  | "subscription_canceled"
  | "payment_failed"
  | "notification_sent"
  | "lesson_completed"
  | "assessment_completed";

export function trackServerEvent(
  event: ServerEventName,
  uid: string,
  params: Record<string, unknown> = {},
): void {
  logger.info("letrando_event", {
    event,
    uid,
    params,
    at: new Date().toISOString(),
  });
}
