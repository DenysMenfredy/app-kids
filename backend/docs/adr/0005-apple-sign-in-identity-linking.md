# ADR 0005 — Apple sign-in may create a second account, and uid stays the only key

Date: 2026-09-17 · Status: accepted; Flutter implementation added 2026-10-08

Transport note (2026-10-16): ADR 0018 corrects native Google to the official
Google SDK plus Firebase credential exchange; Apple's Firebase provider path
and the UID/linking decisions below remain unchanged. Apple console/device
acceptance is deferred until the owner obtains Developer membership.

## Context

Sign in with Apple has been added to the iOS login screen. App Store review
guideline 4.8 requires it wherever another third-party sign-in is offered,
and the Google button makes that apply here, so this is not optional.

The client drives it the same way as Google —
`signInWithProvider(AppleAuthProvider())` — on the assumption stated in the
code that "Firebase links providers that share a verified email to the same
UID". That assumption holds for Google. **It does not hold for Apple**,
because Apple offers the parent *Hide My Email* at the moment of consent.
Choosing it returns an opaque relay address
(`something@privaterelay.appleid.com`) instead of the address they
registered with. The two emails genuinely differ, so Firebase does the only
correct thing available to it and mints a new account with a new uid.

Hide My Email cannot be turned off by the app. It is Apple's privacy
feature, offered to the user, and requesting the email scope does not
suppress it.

A new uid is not a cosmetic duplicate. Everything in this backend is keyed
by uid and nothing is keyed by email:

- `paths.user(uid)` and every subcollection under it — children,
  learningProgress, gamification, assessmentResults.
- `firestore.rules` authorises exclusively on `request.auth.uid == uid`.
- `onUserCreated` bootstraps a fresh profile per identity, including an
  explicit `entitlements/premium` document with `active: false`.

The sharpest edge is payment. At checkout the uid is written into the Stripe
session as `client_reference_id` and into subscription `metadata.uid`
(`stripe_provider.ts`), and the webhook reads it back to decide whose
entitlement to activate (`stripe_webhook.ts`). A subscription is therefore
bound permanently to the uid that paid it.

So a parent who subscribes with email/password in March and taps "Continuar
com Apple" in June, choosing Hide My Email, lands on a brand-new account
with no child profile, no progress, and premium inactive — while their
Stripe subscription keeps renewing happily against the uid they can no
longer reach. Nothing in the system detects this.

## Decision

1. **uid remains the only identity key. The backend never merges accounts on
   email.** Not as a simplification — as a boundary. A relay address cannot
   be matched to anything by construction, so email-merging would not even
   solve the case that motivates it. And merging two uids on an email match
   would move one family's children under another family's account, which is
   precisely the child-data boundary constraint §22.7 exists to prevent. An
   email address is not proof of ownership.

2. **A Hide My Email sign-in legitimately produces a separate account.** This
   is treated as correct behaviour, not a bug to be worked around. The parent
   chose not to share their address; the system takes them at their word.

3. **Linking is explicit, client-initiated, and only from an already
   authenticated session.** The supported path is
   `currentUser.linkWithProvider(AppleAuthProvider())` offered from the
   parent area — "Conectar Apple" — which attaches the Apple identity to the
   uid the parent is already signed into, relay address and all. Afterwards
   Apple sign-in resolves to the original uid. Linking is never inferred,
   never performed server-side, and never done on the strength of a matching
   email.

4. **Duplication is caught at the moment it happens, not months later.** When
   an Apple sign-in yields an account that has no children and no active
   entitlement, the app must offer "Já tem uma conta?" before the parent
   starts creating a second child profile. A parent who has just duplicated
   themselves is one tap from the original account; a parent who discovers it
   in June has lost their streak and their subscription.

## Consequences

- Apple sign-in ships on iOS and satisfies guideline 4.8.
- The Flutter client now offers an explicit Apple-linking action on the
  authenticated parent dashboard and prompts newly created Apple identities
  before child-profile onboarding. Choosing an existing account signs out
  and returns the parent to sign-in; it never merges UIDs based on email.
- Apple buttons use one of Apple's supported button titles consistently;
  the account-link action explains its purpose alongside the standard button.
- Firebase Auth creates a new identity before that prompt can appear. If the
  parent chooses the existing-account path, the new UID keeps its bootstrap
  profile but has no child/progress data and remains signed out. Deleting it
  would require a separate account-deletion flow and Apple credential
  revocation policy.
- These flows remain release gates until exercised on physical iOS with both
  email/Google accounts and existing Apple-linked accounts. A support
  procedure is also still needed for independently existing identities.
- A parent who duplicates anyway needs a support route. There is no
  self-service recovery: the Stripe subscription carries the old uid in
  immutable metadata, so re-pointing it is an operator action against Stripe
  plus a write to the new uid's entitlement. Worth a runbook before launch.
- The same reasoning applies to any future provider that can withhold a
  stable email. The rule to carry forward is that identity is the uid, and a
  provider that hides the email does not get a special case.
- Google sign-in is unaffected: it returns the parent's real verified
  address, so Firebase continues to resolve it to the existing uid.
