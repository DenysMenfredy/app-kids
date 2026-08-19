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
  successUrl: string;
  cancelUrl: string;
}

export interface PaymentProvider {
  readonly id: PaymentProviderId;

  /** Creates a hosted checkout for the plan; returns the redirect URL. */
  createCheckoutSession(request: CheckoutSessionRequest): Promise<string>;

  /** Creates a self-service billing portal session for an existing customer. */
  createCustomerPortalSession(
    providerCustomerId: string,
    returnUrl: string,
  ): Promise<string>;
}
