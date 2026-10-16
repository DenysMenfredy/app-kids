import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/notification_ports.dart';
import '../domain/notification_preferences.dart';

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository(this.auth, this.firestore, this.functions);
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  void _check(String uid) {
    if (auth.currentUser?.uid != uid) throw StateError('Conta alterada.');
  }

  @override
  Future<NotificationPreferences> load(String uid) async {
    _check(uid);
    final snapshot = await firestore
        .doc('users/$uid/notificationPreferences/default')
        .get(const GetOptions(source: Source.server));
    return snapshot.exists
        ? NotificationPreferences.fromMap(snapshot.data()!)
        : const NotificationPreferences();
  }

  @override
  Future<void> save(String uid, NotificationPreferences preferences) async {
    _check(uid);
    await firestore.doc('users/$uid/notificationPreferences/default').set({
      ...preferences.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> register(String uid, Map<String, dynamic> installation) async {
    _check(uid);
    await functions.httpsCallable('registerDevice').call<void>(installation);
  }

  @override
  Future<void> unregister(String uid, Map<String, dynamic> installation) async {
    _check(uid);
    await functions.httpsCallable('unregisterDevice').call<void>(installation);
  }
}
