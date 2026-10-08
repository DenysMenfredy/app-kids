import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

initializeApp();

// Brazil market: run everything out of São Paulo (spec: Market Brazil).
setGlobalOptions({ region: "southamerica-east1", maxInstances: 10 });

// auth/
export { onUserCreated } from "./auth/on_user_created";

// payments/
export { createCheckoutSession } from "./payments/create_checkout_session";
export { createCustomerPortal } from "./payments/create_customer_portal";
export { stripeWebhook } from "./payments/stripe_webhook";

// subscriptions/
export { syncEntitlement } from "./subscriptions/sync_entitlement";

// notifications/
export { registerDevice } from "./notifications/register_device";
export { sendDailyReminders } from "./notifications/send_daily_reminders";

// learning/
export { completeLesson } from "./learning/complete_lesson";
export { submitAssessment } from "./learning/submit_assessment";
export { startLessonSession } from "./learning/start_lesson_session";
export { submitActivityAttempt } from "./learning/submit_activity_attempt";
export { updateProgress } from "./learning/update_progress";

// profiles/
export { createChildProfile } from "./profiles/create_child_profile";

// admin/
export { manageContent } from "./admin/manage_content";
export { setUserRole } from "./admin/set_user_role";
