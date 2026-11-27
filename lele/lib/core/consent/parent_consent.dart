import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../firebase/firebase_providers.dart';

/// Version identifier currently accepted by the backend (ADR 0020).
///
/// This is not legal copy: it mirrors `CURRENT_CONSENT_TEXT_VERSION` in
/// `backend/functions/src/domain/consent.ts`. A test keeps both literals in
/// sync. A new version requires re-consent, which the gate below handles.
const currentConsentTextVersion = 'd07-placeholder-v1';

/// Where the app collected the acceptance. Allowlisted by the backend.
const consentOrigin = 'parent_app';

/// Optional purposes are recorded, not inferred. The current checkbox covers
/// the base child-data consent only, so every optional purpose stays false
/// until the app asks for it explicitly (PR14/PR13).
const currentConsentPurposes = <String, bool>{
  'notifications': false,
  'marketing': false,
  'analytics': false,
};

/// What the signed-in parent still needs to do before child data can be
/// written.
class ParentConsentStatus {
  const ParentConsentStatus({
    required this.required,
    this.acceptedVersion,
    this.requiredVersion = currentConsentTextVersion,
  });

  static const granted = ParentConsentStatus(required: false);

  final bool required;
  final String? acceptedVersion;
  final String requiredVersion;
}

/// Pure mapping from the server-owned consent document.
///
/// Anything missing, malformed or from another version fails closed: the app
/// must ask for the current terms instead of assuming consent.
ParentConsentStatus parentConsentStatusFrom({
  required Map<String, Object?>? data,
  required String uid,
}) {
  if (data == null) return const ParentConsentStatus(required: true);
  final acceptedVersion = data['textVersion'];
  final versionMatches =
      acceptedVersion is String && acceptedVersion == currentConsentTextVersion;
  final valid =
      versionMatches &&
      data['schemaVersion'] == 1 &&
      data['uid'] == uid &&
      data['acceptedAt'] != null;
  if (valid) return const ParentConsentStatus(required: false);
  return ParentConsentStatus(
    required: true,
    acceptedVersion: acceptedVersion is String ? acceptedVersion : null,
  );
}

/// True when a callable refused because child data needs current consent.
///
/// The backend sends `failed-precondition` with a `code` in `details`
/// (`consent_required` or `consent_outdated`). Other failures keep their
/// existing handling; this must not turn a network error into a legal gate.
bool isParentConsentFailure(Object error) {
  if (error is! FirebaseFunctionsException) return false;
  return isParentConsentRefusal(code: error.code, details: error.details);
}

/// Pure form of the callable refusal check, kept testable without building a
/// platform exception.
bool isParentConsentRefusal({required String code, Object? details}) {
  if (code != 'failed-precondition' || details is! Map) return false;
  final typed = Map<Object?, Object?>.from(details);
  final refusal = typed['code'];
  return refusal == 'consent_required' || refusal == 'consent_outdated';
}

/// Result of `recordParentConsent`. `changed` is false for an idempotent
/// retry with the same version and purposes.
class ParentConsentResult {
  const ParentConsentResult({required this.changed, required this.textVersion});

  final bool changed;
  final String textVersion;
}

typedef ConsentRecordTransport =
    Future<Map<String, Object?>?> Function(Map<String, Object?> payload);
typedef ConsentStatusTransport =
    Future<Map<String, Object?>?> Function(String uid);

abstract interface class ParentConsentService {
  Future<ParentConsentResult> record();

  Future<ParentConsentStatus> status();
}

/// The app runs without Firebase in local demo mode; there is no server
/// consent to record and no child data leaves the device.
class NoopParentConsentService implements ParentConsentService {
  const NoopParentConsentService();

  @override
  Future<ParentConsentResult> record() async => const ParentConsentResult(
    changed: false,
    textVersion: currentConsentTextVersion,
  );

  @override
  Future<ParentConsentStatus> status() async => ParentConsentStatus.granted;
}

class FirebaseParentConsentService implements ParentConsentService {
  FirebaseParentConsentService({
    required this.uid,
    required this.recordTransport,
    required this.statusTransport,
  });

  final String? Function() uid;
  final ConsentRecordTransport recordTransport;
  final ConsentStatusTransport statusTransport;

  /// Avoids a second read right after a successful write in the same session.
  String? _recordedUid;

  @override
  Future<ParentConsentResult> record() async {
    final currentUid = uid();
    if (currentUid == null) {
      throw StateError('A parent must be signed in.');
    }

    final response = await recordTransport({
      'textVersion': currentConsentTextVersion,
      'purposes': Map<String, bool>.from(currentConsentPurposes),
      'origin': consentOrigin,
    });
    if (response == null || response['ok'] != true) {
      throw StateError('recordParentConsent returned an invalid response.');
    }
    final changed = response['changed'];
    final version = response['textVersion'];
    if (changed is! bool || version is! String) {
      throw StateError('recordParentConsent returned an invalid response.');
    }
    _recordedUid = currentUid;
    return ParentConsentResult(changed: changed, textVersion: version);
  }

  @override
  Future<ParentConsentStatus> status() async {
    final currentUid = uid();
    if (currentUid == null) return ParentConsentStatus.granted;
    if (_recordedUid == currentUid) return ParentConsentStatus.granted;
    try {
      final data = await statusTransport(currentUid);
      return parentConsentStatusFrom(data: data, uid: currentUid);
    } on FirebaseException catch (error) {
      // Rules from before T08a deny this path and a transient offline read
      // cannot be treated as missing consent. Both cases keep the app usable;
      // the gated callables still fail closed on the server.
      if (error.code == 'permission-denied' || error.code == 'unavailable') {
        return ParentConsentStatus.granted;
      }
      rethrow;
    }
  }
}

final parentConsentServiceProvider = Provider<ParentConsentService>((ref) {
  if (!AppConfig.useFirebase) return const NoopParentConsentService();

  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  final functions = ref.watch(functionsProvider);

  return FirebaseParentConsentService(
    uid: () => auth.currentUser?.uid,
    recordTransport: (payload) async {
      final result = await functions
          .httpsCallable('recordParentConsent')
          .call<dynamic>(payload);
      final data = result.data;
      return data is Map
          ? data.map((key, value) => MapEntry(key.toString(), value))
          : null;
    },
    statusTransport: (uid) async {
      final snapshot = await firestore
          .doc('users/$uid/consent/current')
          .get(const GetOptions(source: Source.server));
      return snapshot.data();
    },
  );
});

/// Whether the signed-in parent must accept the current terms before the app
/// lets them create a child or record learning progress.
final parentConsentStatusProvider = FutureProvider<ParentConsentStatus>((
  ref,
) async {
  if (!AppConfig.useFirebase) return ParentConsentStatus.granted;
  ref.watch(firebaseAuthUserProvider.select((state) => state.value?.uid));
  return ref.watch(parentConsentServiceProvider).status();
});

/// Clears the gate after the terms were accepted.
void acceptParentConsent(WidgetRef ref) {
  ref.invalidate(parentConsentStatusProvider);
}

/// Debug-only breadcrumb; never logs the parent uid or e-mail.
void logConsentFailure(Object error) {
  if (kDebugMode) debugPrint('parent consent unavailable: $error');
}
