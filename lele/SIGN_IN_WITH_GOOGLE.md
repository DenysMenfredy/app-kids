# Sign in with Google — flow, and the setup it still needs

## What the app does

A provider tap is a sign-in and a sign-up at once, so the repository returns
a `SignInOutcome` rather than `void` and the screen routes on it:

| Outcome     | Where the parent goes | Why |
|-------------|----------------------|-----|
| `created`   | profile setup        | Firebase minted the account. No child, no assessment — the same onboarding an e-mail sign-up gets. |
| `returning` | dashboard            | The account already existed. |
| `cancelled` | nowhere              | They closed the sheet. Not a failure, so no red banner. |

`created` comes from `additionalUserInfo.isNewUser`, which is the only
reliable signal — the screen the button was tapped from does not decide it.
Both the sign-in and sign-up screens offer the provider, and both honour the
same three outcomes.

The provider is configured, not bare:

```dart
GoogleAuthProvider()
  ..addScope('email')
  ..addScope('profile')
  ..setCustomParameters({'prompt': 'select_account'});
```

`prompt: select_account` matters on a family device. Without it Google
silently reuses whichever account signed in last, so the second parent to
try is handed the first parent's identity with no chooser.

The parent's name needs no client handling: Firebase populates
`displayName` from the Google profile, and `onUserCreated` mirrors it into
`users/{uid}.displayName`, which is what `parentNameProvider` reads.

## What is still missing — it cannot work yet

`lib/firebase_options.dart` is still the placeholder that throws, and
neither native config file exists:

```
MISSING  android/app/google-services.json
MISSING  ios/Runner/GoogleService-Info.plist
```

These carry per-project credentials and can only come from the Firebase
console:

```sh
dart pub global activate flutterfire_cli
flutterfire configure --project=letrando-dev
```

Then, per platform:

1. **Android** — add the signing SHA-1 *and* SHA-256 for every build you
   sign (debug keystore, upload key, and Play App Signing) to the Firebase
   project. Google sign-in fails on Android with a bare
   `ApiException: 10` when a fingerprint is missing, which says nothing
   about fingerprints.
2. **iOS** — add the `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` as
   a URL scheme in the Runner target.
3. **Web** — Firebase Hosting domains are pre-authorised; any other origin
   must be added under Authentication → Settings → Authorized domains.
4. **Firebase console** — Authentication → Sign-in method → enable Google.

## One open decision: which SDK drives the sheet

Today this uses `firebase_auth`'s `signInWithProvider`, which opens a
browser tab (Custom Tabs / `ASWebAuthenticationSession`). It works on every
platform with no extra SDK and is what the Apple button uses too.

Google's current guidance on Android is **Credential Manager**, which the
`google_sign_in` 7.x package wraps. That gives the native account sheet
instead of a browser hop, and is a visibly better flow.

It was not adopted here because it could not be verified: without the config
files above there is no way to exercise a real Google sign-in from this
machine, and a migration written blind — `serverClientId` on Android, the
GIS client id in `web/index.html`, and a different `initialize`/`authenticate`
API — is not something to ship untested.

Revisit once `flutterfire configure` has run. The flow above is deliberately
SDK-agnostic: `SignInOutcome` and the routing stay as they are, and only
`FirebaseAuthRepository.signInWithGoogle` changes.
