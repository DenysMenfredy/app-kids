/** Plan v2 retires every external acquisition channel, even an old approved ID. */
export function isApprovedWebCheckoutApp(
  _configuredAppId: string,
  _attestedAppId: string | undefined,
): boolean {
  return false;
}
