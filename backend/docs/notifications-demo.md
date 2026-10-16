# Local notification demo and regression checks

The parent dashboard's **Avisos e lembretes** opens notification settings.
Choose **Ativar avisos neste aparelho**, allow the OS prompt if it appears,
then **Mostrar demonstração**. Open the Android notification tray to see
**Lelê • Demonstração**. Tapping it returns to the authenticated parent panel.
This is an immediate local notification, not a scheduled mission or FCM push.
Sound follows system volume, Do Not Disturb and notification cooldown settings.

Run the normal demo-emulator app with:

```sh
cd lele
flutter run --dart-define=USE_FIREBASE=true --dart-define=USE_EMULATOR=true
```

Run controller/widget regressions and all app tests:

```sh
cd lele
flutter test test/notification_flow_test.dart
flutter analyze
flutter test
```

With `backend/dev.sh` already serving the local demo emulators, use Node 22:

```sh
cd backend/functions
npm run build
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
npm run test:notifications:smoke
```

The smoke test refuses non-loopback emulator hosts, uses only `demo-letrando`,
creates disposable accounts and installation IDs, simulates the FCM transport,
and deletes only its own fixtures. It never sends a real remote push.

Rules regressions use separate ports and project:

```sh
cd backend/test/rules
npm test
```

For a real dev push, first replace placeholder FlutterFire configuration for
the dev project, register Android signing/App Check, and configure APNs push
capability/signing and its Firebase key on iOS. Build without `USE_EMULATOR`,
sign in and opt in on a test device. Do not use production data/credentials.
Never treat SDK acceptance as proof a device displayed a notification.
See ADR 0016 for ownership, retry and release limitations.
