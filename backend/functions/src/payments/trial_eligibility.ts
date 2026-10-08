import { randomUUID } from "node:crypto";

import {
  FieldValue,
  Firestore,
  Timestamp,
} from "firebase-admin/firestore";

import { paths } from "../lib/firestore";

const RESERVATION_WINDOW_MS = 25 * 60 * 60 * 1000;
const SESSION_EXPIRY_GRACE_MS = 5 * 60 * 1000;
export const TRIAL_DURATION_DAYS = 7;

export type TrialClaim =
  | { status: "reserved"; reservationId: string }
  | {
      status: "reservation_needs_reconciliation";
      reservationId: string;
      sessionId: string;
    }
  | { status: "unavailable" }
  | { status: "checkout_in_progress" }
  | { status: "subscription_exists" };

/**
 * Reserves the account's only seven-day trial in the same transaction that
 * checks its subscription history. A second concurrent Checkout cannot claim
 * another trial, and any previous subscription permanently consumes eligibility.
 */
export async function claimTrialForCheckout(
  firestore: Firestore,
  uid: string,
): Promise<TrialClaim> {
  const trialRef = firestore.doc(paths.billingTrial(uid));
  const subscriptionQuery = firestore.collection(paths.subscriptions(uid));
  const customerHistory = firestore
    .collection(paths.stripeCustomers)
    .where("uid", "==", uid);
  const reservationId = randomUUID();
  const now = Date.now();

  return firestore.runTransaction(async (transaction) => {
    const [trialSnapshot, subscriptions, customers] = await Promise.all([
      transaction.get(trialRef),
      transaction.get(subscriptionQuery),
      transaction.get(customerHistory),
    ]);

    if (
      subscriptions.docs.some((doc) =>
        ["active", "trialing", "past_due"].includes(doc.get("status")),
      )
    ) {
      return { status: "subscription_exists" };
    }
    // A completed Stripe Checkout creates the server-side customer mapping
    // before its subscription webhook is processed. Fail closed during that
    // short reconciliation window rather than creating a duplicate session.
    if (customers.size > 0 && subscriptions.size === 0) {
      return { status: "subscription_exists" };
    }

    const state = trialSnapshot.get("state");
    if (state === "consumed") return { status: "unavailable" };

    if (
      subscriptions.size > 0 ||
      customers.size > 0 ||
      (trialSnapshot.exists && state !== "reserved" && state !== "eligible")
    ) {
      transaction.set(
        trialRef,
        {
          state: "consumed",
          consumedReason: "subscription_history",
          consumedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return { status: "unavailable" };
    }

    if (state === "reserved") {
      const expiry = trialSnapshot.get("reservationExpiresAt") as
        | Timestamp
        | undefined;
      if (expiry && expiry.toMillis() > now) {
        return { status: "checkout_in_progress" };
      }
      const sessionId = trialSnapshot.get("checkoutSessionId");
      const existingReservationId = trialSnapshot.get("reservationId");
      if (
        typeof sessionId === "string" &&
        typeof existingReservationId === "string"
      ) {
        return {
          status: "reservation_needs_reconciliation",
          reservationId: existingReservationId,
          sessionId,
        };
      }
    }

    transaction.set(
      trialRef,
      {
        state: "reserved",
        reservationId,
        reservedAt: FieldValue.serverTimestamp(),
        reservationExpiresAt: Timestamp.fromMillis(now + RESERVATION_WINDOW_MS),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { status: "reserved", reservationId };
  });
}

/** Extends a still-open Stripe session's reservation after a stale local lease. */
export async function refreshTrialReservation(
  firestore: Firestore,
  uid: string,
  reservationId: string,
  sessionId: string,
  expiresAt: number,
): Promise<void> {
  const ref = firestore.doc(paths.billingTrial(uid));
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (
      snapshot.get("state") !== "reserved" ||
      snapshot.get("reservationId") !== reservationId
    ) {
      throw new Error("Trial reservation changed before Checkout was saved");
    }
    const expiry = Math.max(
      expiresAt * 1000 + SESSION_EXPIRY_GRACE_MS,
      Date.now() + 60 * 1000,
    );
    transaction.update(ref, {
      checkoutSessionId: sessionId,
      reservationExpiresAt: Timestamp.fromMillis(expiry),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

/** Releases only the exact abandoned session; late events cannot free a new claim. */
export async function releaseTrialReservation(
  firestore: Firestore,
  uid: string,
  reservationId: string,
): Promise<void> {
  const ref = firestore.doc(paths.billingTrial(uid));
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (
      snapshot.get("state") !== "reserved" ||
      snapshot.get("reservationId") !== reservationId
    ) {
      return;
    }
    transaction.update(ref, {
      state: "eligible",
      reservationId: FieldValue.delete(),
      checkoutSessionId: FieldValue.delete(),
      reservationExpiresAt: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

/** Trial or paid subscription creation consumes the account's trial forever. */
export async function consumeTrialEligibility(
  firestore: Firestore,
  uid: string,
  details: { subscriptionId?: string; reservationId?: string },
): Promise<void> {
  const ref = firestore.doc(paths.billingTrial(uid));
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (snapshot.get("state") === "consumed") return;
    transaction.set(
      ref,
      {
        state: "consumed",
        consumedReason: details.subscriptionId
          ? "subscription_created"
          : "checkout_completed",
        ...(details.subscriptionId
          ? { consumedBySubscriptionId: details.subscriptionId }
          : {}),
        ...(details.reservationId
          ? { consumedReservationId: details.reservationId }
          : {}),
        consumedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}
