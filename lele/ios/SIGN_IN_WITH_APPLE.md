# Sign in with Apple — remaining iOS setup

The Dart side is done: `AuthRepository.signInWithApple()` drives
`AppleAuthProvider` through Firebase Auth, and the button appears on iOS
only. None of it can work on a device until the four steps below are done,
and all four need a Mac, an Apple Developer account, or the Firebase
console — so they could not be done from here.

`Runner/Runner.entitlements` is written out with the right key, but **it is
not yet referenced by the Xcode project**. Step 2 is what wires it up.

## 1. Apple Developer portal

Enable the **Sign in with Apple** capability for the App ID
`br.com.lele.lele`, then regenerate the provisioning profile.

## 2. Xcode

Open `ios/Runner.xcworkspace` → Runner target → Signing & Capabilities →
**+ Capability** → Sign in with Apple.

Xcode sets `CODE_SIGN_ENTITLEMENTS` in `project.pbxproj` and points it at
`Runner/Runner.entitlements`. Adding the capability through Xcode rather
than editing the project file by hand is deliberate: it also updates the
provisioning profile, and a hand-edited `project.pbxproj` that is subtly
wrong breaks every iOS build.

Verify afterwards:

```sh
grep -c CODE_SIGN_ENTITLEMENTS ios/Runner.xcodeproj/project.pbxproj   # expect 2
```

## 3. Firebase console

Authentication → Sign-in method → enable **Apple**. For the native iOS flow
the Services ID / key fields can stay empty; they are only needed to extend
Apple sign-in to web or Android.

## 4. Build the two paths ADR 0005 requires

`backend/docs/adr/0005-apple-sign-in-identity-linking.md` settles what
happens when a parent picks Apple's "Hide My Email": the relay address
matches nothing, Firebase mints a new uid, and that account has no children
and no premium — while their Stripe subscription keeps renewing against the
uid they can no longer reach.

The ADR accepts that outcome as correct, and records two **release blockers**
that are not built yet:

- "Conectar Apple" in the parent area — `currentUser.linkWithProvider`,
  which attaches Apple to the account they are already signed into.
- A "Já tem uma conta?" prompt when an Apple sign-in lands on an account with
  no children and no entitlement, shown before they create a second child.

Shipping Apple sign-in without these means a paying parent can silently lose
access.
