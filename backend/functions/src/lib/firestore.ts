import { getFirestore, Firestore } from "firebase-admin/firestore";

/** Central place for collection paths so they never drift from the spec. */
export const paths = {
  user: (uid: string) => `users/${uid}`,
  children: (uid: string) => `users/${uid}/children`,
  childCreationRequests: (uid: string) =>
    `users/${uid}/childCreationRequests`,
  devices: (uid: string) => `users/${uid}/devices`,
  subscriptions: (uid: string) => `users/${uid}/subscriptions`,
  entitlements: (uid: string) => `users/${uid}/entitlements`,
  notifications: (uid: string) => `users/${uid}/notifications`,
  notificationPreferences: (uid: string) =>
    `users/${uid}/notificationPreferences`,
  learningProgress: (uid: string) => `users/${uid}/learningProgress`,
  activityAttempts: (uid: string) => `users/${uid}/activityAttempts`,
  sessions: (uid: string) => `users/${uid}/sessions`,
  /** Server-owned XP/coins/streak, one document per child. */
  gamification: (uid: string) => `users/${uid}/gamification`,
  /** Stored placement produced by an assessment, one per child. */
  assessmentResults: (uid: string) => `users/${uid}/assessmentResults`,
  webhookEvents: "webhookEvents",
  products: "products",
  /** Global assessment content (questions + placement bands). */
  assessments: "assessments",
  /** Global lesson content. */
  lessons: "lessons",
  /** Global activity content used for server-side answer scoring. */
  activities: "activities",
  /** Global module metadata used by the free/Premium access policy. */
  modules: "modules",
} as const;

/** Default entitlement document id — one active entitlement per user (MVP). */
export const PREMIUM_ENTITLEMENT_ID = "premium";

/** Default notification preferences document id. */
export const DEFAULT_PREFERENCES_ID = "default";

/** Assessment served to new families in the MVP. */
export const DEFAULT_ASSESSMENT_ID = "assessment_pre_literacy_v1";

let cached: Firestore | undefined;

export function db(): Firestore {
  cached ??= getFirestore();
  return cached;
}
