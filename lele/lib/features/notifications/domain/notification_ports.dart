import 'notification_preferences.dart';

abstract interface class NotificationPlatform {
  bool get supported;
  String get platform;
  Future<void> initialize({
    required void Function() onOpen,
    required void Function() onTokenRefresh,
  });
  Future<bool> allowed();
  Future<bool> requestPermission();
  Future<void> showDemo();
  Future<String?> token();
  Future<void> stopRemote();
  Future<void> clear();
  void dispose();
}

abstract interface class NotificationRepository {
  Future<NotificationPreferences> load(String uid);
  Future<void> save(String uid, NotificationPreferences preferences);
  Future<void> register(String uid, Map<String, dynamic> installation);
  Future<void> unregister(String uid, Map<String, dynamic> installation);
}
