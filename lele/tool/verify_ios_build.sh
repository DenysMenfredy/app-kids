#!/bin/sh
# Invoked before the Flutter Xcode build. Never print public config values or keys.
set -eu
cd "${SRCROOT:?SRCROOT missing}/.."
if [ "${CONFIGURATION:-}" = "Release" ]; then
  "${FLUTTER_ROOT:?FLUTTER_ROOT missing}/bin/cache/dart-sdk/bin/dart" \
    tool/verify_firebase_config.dart "--defines=${DART_DEFINES:-}" --platform=ios --release
else
  "${FLUTTER_ROOT:?FLUTTER_ROOT missing}/bin/cache/dart-sdk/bin/dart" \
    tool/verify_firebase_config.dart "--defines=${DART_DEFINES:-}" --platform=ios
fi
