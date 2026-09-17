import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/firebase/firebase_emulators.dart';
import 'core/storage/local_storage.dart';
import 'features/session/application/demo_progress_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (AppConfig.useFirebase) {
    await Firebase.initializeApp(
      // Emulator runs use throwaway demo credentials, so local development
      // needs no `flutterfire configure` and can't reach a real project.
      options: AppConfig.useEmulator
          ? demoFirebaseOptions
          : DefaultFirebaseOptions.currentPlatform,
    );
    if (AppConfig.useEmulator) await connectToEmulators();
  }
  final prefs = await SharedPreferences.getInstance();
  // XP, coins and the streak belong to the backend once it is on. Drop any
  // copy a demo run left on this device, so local storage cannot sit there
  // showing 120 XP while the dashboard shows the 200 the child earned.
  await DemoProgress.dropBackendOwnedCopy(prefs);
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const LeleApp(),
    ),
  );
}
