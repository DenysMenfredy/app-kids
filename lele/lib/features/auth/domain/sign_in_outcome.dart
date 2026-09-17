/// What a provider sign-in actually resolved to.
///
/// "Sign in with Google" is one button doing three different things, and the
/// screen behind it has to tell them apart. Returning it as a value keeps
/// that decision out of the repository, which has no business knowing about
/// routes.
enum SignInOutcome {
  /// Firebase minted a new account. This parent has no child profile and no
  /// assessment yet, so they need the same onboarding an e-mail sign-up
  /// gets — not the dashboard, which would be a family that does not exist.
  created,

  /// An account that already existed. Straight to the dashboard.
  returning,

  /// The parent closed the Google sheet. Not a failure: nothing went wrong,
  /// they changed their mind, and showing them a red error for it is the
  /// app calling them clumsy.
  cancelled,
}
