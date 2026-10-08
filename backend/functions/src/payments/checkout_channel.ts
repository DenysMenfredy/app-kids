/** Only an attested, explicitly registered web app may start Stripe Checkout.
 * Mobile beta apps cannot bypass their hidden purchase button by calling the
 * function directly. The sentinel also keeps checkout off in new projects.
 */
export function isApprovedWebCheckoutApp(
  configuredAppId: string,
  attestedAppId: string | undefined,
): boolean {
  return configuredAppId !== "disabled" &&
    configuredAppId.length > 0 &&
    configuredAppId === attestedAppId;
}
