import { FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";
import Stripe from "stripe";

import { paths } from "../lib/firestore";

/** Persists the authenticated UID/session relation before returning Checkout. */
export async function recordCheckoutSession(
  firestore: Firestore,
  input: {
    uid: string;
    planId: string;
    sessionId: string;
    expiresAt: number;
    trialReservationId?: string;
  },
): Promise<void> {
  const checkoutRef = firestore
    .collection(paths.stripeCheckoutSessions)
    .doc(input.sessionId);
  const trialRef = firestore.doc(paths.billingTrial(input.uid));

  await firestore.runTransaction(async (transaction) => {
    const checkout = await transaction.get(checkoutRef);
    const trial = input.trialReservationId
      ? await transaction.get(trialRef)
      : undefined;
    if (checkout.exists) throw new Error("Checkout session mapping already exists");
    if (
      input.trialReservationId &&
      (trial?.get("state") !== "reserved" ||
        trial.get("reservationId") !== input.trialReservationId)
    ) {
      throw new Error("Trial reservation changed before Checkout was saved");
    }

    transaction.create(checkoutRef, {
      uid: input.uid,
      planId: input.planId,
      state: "open",
      ...(input.trialReservationId
        ? { trialReservationId: input.trialReservationId }
        : {}),
      expiresAt: Timestamp.fromMillis(input.expiresAt * 1000),
      createdAt: FieldValue.serverTimestamp(),
    });
    if (input.trialReservationId) {
      transaction.update(trialRef, {
        checkoutSessionId: input.sessionId,
        reservationExpiresAt: Timestamp.fromMillis(
          input.expiresAt * 1000 + 5 * 60 * 1000,
        ),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
}

/**
 * Binds the Stripe customer only from a server-created Checkout session map.
 * A migration fallback validates server-authored signed Checkout identity
 * fields for legacy sessions; subscription-owner recovery requires an exact
 * previously mirrored subscription/customer match.
 */
export async function recordStripeCustomerFromCheckout(
  firestore: Firestore,
  session: Stripe.Checkout.Session,
): Promise<string> {
  const customerId =
    typeof session.customer === "string"
      ? session.customer
      : session.customer?.id;
  if (!customerId) throw new Error(`Checkout ${session.id} has no customer`);

  const checkoutRef = firestore
    .collection(paths.stripeCheckoutSessions)
    .doc(session.id);
  const checkout = await checkoutRef.get();
  let uid = checkout.get("uid") as string | undefined;
  const recoveredLegacySession = !uid;

  if (!uid) {
    const legacyUid = session.metadata?.uid;
    if (
      !legacyUid ||
      !session.client_reference_id ||
      session.client_reference_id !== legacyUid
    ) {
      throw new Error(`Checkout ${session.id} has no server mapping`);
    }
    const user = await firestore.doc(paths.user(legacyUid)).get();
    if (!user.exists) {
      throw new Error(`Checkout ${session.id} references no existing parent`);
    }
    uid = legacyUid;
  }

  if (
    (session.client_reference_id && session.client_reference_id !== uid) ||
    (session.metadata?.uid && session.metadata.uid !== uid)
  ) {
    throw new Error(`Checkout ${session.id} identity metadata does not match`);
  }

  const customerRef = firestore
    .collection(paths.stripeCustomers)
    .doc(customerId);
  await firestore.runTransaction(async (transaction) => {
    const [customer, sessionMapping] = await Promise.all([
      transaction.get(customerRef),
      transaction.get(checkoutRef),
    ]);
    const mappedUid = customer.get("uid");
    if (mappedUid && mappedUid !== uid) {
      throw new Error(`Stripe customer ${customerId} is already mapped`);
    }
    if (sessionMapping.exists && sessionMapping.get("uid") !== uid) {
      throw new Error(`Checkout ${session.id} mapping changed`);
    }
    const previousCustomerId = sessionMapping.get("customerId");
    if (previousCustomerId && previousCustomerId !== customerId) {
      throw new Error(`Checkout ${session.id} customer mapping changed`);
    }
    transaction.set(
      customerRef,
      {
        uid,
        provider: "stripe",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    transaction.set(
      checkoutRef,
      {
        uid,
        customerId,
        state: "completed",
        ...(recoveredLegacySession ? { recoveredLegacySession: true } : {}),
        completedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
  return uid;
}

/** Resolves ownership from the backend-created customer map, never metadata alone. */
export async function resolveStripeSubscriptionOwner(
  firestore: Firestore,
  subscription: Stripe.Subscription,
): Promise<string> {
  const customerId =
    typeof subscription.customer === "string"
      ? subscription.customer
      : subscription.customer.id;
  const customerRef = firestore
    .collection(paths.stripeCustomers)
    .doc(customerId);
  const customer = await customerRef.get();
  const mappedUid = customer.get("uid");
  if (typeof mappedUid === "string" && mappedUid.length > 0) return mappedUid;

  const legacyUid = subscription.metadata?.uid;
  if (legacyUid) {
    const legacySubscription = await firestore
      .collection(paths.subscriptions(legacyUid))
      .doc(subscription.id)
      .get();
    if (
      legacySubscription.exists &&
      legacySubscription.get("provider") === "stripe" &&
      legacySubscription.get("providerCustomerId") === customerId
    ) {
      await customerRef.create({
        uid: legacyUid,
        provider: "stripe",
        recoveredFromSubscriptionId: subscription.id,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return legacyUid;
    }
  }
  throw new Error(`Stripe customer ${customerId} has no server-side UID mapping`);
}
