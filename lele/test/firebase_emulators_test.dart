import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/firebase/firebase_emulators.dart';

void main() {
  test(
    'demo options pass the Android Firebase Installations syntax checks',
    () {
      // Native callable setup requests an installation ID before sending the
      // HTTP request. Short placeholders work for Auth REST calls but throw
      // IllegalArgumentException here, even with a Functions emulator URL.
      expect(demoFirebaseOptions.apiKey, matches(RegExp(r'^A[\w-]{38}$')));
      expect(demoFirebaseOptions.appId, contains(':'));
      expect(demoFirebaseOptions.projectId, startsWith('demo-'));
    },
  );
}
