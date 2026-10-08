import { PaymentProviderId } from "../domain/subscription";

/**
 * Payment provider abstraction (spec §9). The subscription domain never
 * talks to Stripe directly — it talks to a PaymentProvider. Native store
 * billing (Apple/Google) plugs in later as additional implementations.
 */
export interface CheckoutSessionRequest {
  uid: string;
  email: string | undefined;
  planId: string;
  /** Present only while the backend holds this account's one-time trial. */
  trialReservationId?: string;
  successUrl: string;
  cancelUrl: string;
}

export interface CheckoutSession {
  id: string;
  url: string;
  expiresAt: number;
}

export interface PaymentProvider {
  readonly id: PaymentProviderId;

  /** Creates a hosted checkout; Premium still comes only from a webhook. */
  createCheckoutSession(request: CheckoutSessionRequest): Promise<CheckoutSession>;

  /** Creates a self-service billing portal session for an existing customer. */
  createCustomerPortalSession(
    providerCustomerId: string,
    returnUrl: string,
  ): Promise<string>;
}
