import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/consent/parent_consent.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/features/auth/presentation/parent_consent_gate.dart';

class _FakeConsentService implements ParentConsentService {
  int records = 0;
  bool failRecord = false;

  @override
  Future<ParentConsentResult> record() async {
    records++;
    if (failRecord) throw StateError('offline');
    return const ParentConsentResult(
      changed: true,
      textVersion: currentConsentTextVersion,
    );
  }

  @override
  Future<ParentConsentStatus> status() async =>
      const ParentConsentStatus(required: true);
}

void main() {
  group('consent version is pinned to the backend', () {
    final source = File(
      '../backend/functions/src/domain/consent.ts',
    ).readAsStringSync();

    test('text version matches CURRENT_CONSENT_TEXT_VERSION', () {
      final match = RegExp(
        'CURRENT_CONSENT_TEXT_VERSION = "([^"]+)"',
      ).firstMatch(source);
      expect(match?.group(1), currentConsentTextVersion);
    });

    test('purpose keys match CONSENT_PURPOSES', () {
      final match = RegExp(
        r'CONSENT_PURPOSES = \[([^\]]+)\]',
      ).firstMatch(source);
      expect(match, isNotNull);
      final purposes = RegExp(
        '"([^"]+)"',
      ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toSet();
      expect(purposes, currentConsentPurposes.keys.toSet());
    });
  });

  group('parentConsentStatusFrom', () {
    Map<String, Object?> current() => {
      'schemaVersion': 1,
      'textVersion': currentConsentTextVersion,
      'uid': 'parent-1',
      'acceptedAt': DateTime.utc(2026, 11, 27),
    };

    test('accepts a current record for the signed-in parent', () {
      final status = parentConsentStatusFrom(data: current(), uid: 'parent-1');
      expect(status.required, isFalse);
    });

    test('requires consent when the record is missing', () {
      final status = parentConsentStatusFrom(data: null, uid: 'parent-1');
      expect(status.required, isTrue);
      expect(status.acceptedVersion, isNull);
    });

    test('requires re-consent for an older version and reports it', () {
      final data = current()..['textVersion'] = 'd07-placeholder-v0';
      final status = parentConsentStatusFrom(data: data, uid: 'parent-1');
      expect(status.required, isTrue);
      expect(status.acceptedVersion, 'd07-placeholder-v0');
      expect(status.requiredVersion, currentConsentTextVersion);
    });

    test('rejects a record copied from another uid', () {
      final status = parentConsentStatusFrom(data: current(), uid: 'parent-2');
      expect(status.required, isTrue);
    });

    test('rejects malformed records', () {
      final data = current()..remove('acceptedAt');
      expect(
        parentConsentStatusFrom(data: data, uid: 'parent-1').required,
        isTrue,
      );
    });
  });

  group('consent refusal mapping', () {
    test('accepts both consent refusal codes', () {
      expect(
        isParentConsentRefusal(
          code: 'failed-precondition',
          details: {'code': 'consent_required'},
        ),
        isTrue,
      );
      expect(
        isParentConsentRefusal(
          code: 'failed-precondition',
          details: {'code': 'consent_outdated', 'requiredTextVersion': 'v1'},
        ),
        isTrue,
      );
    });

    test('does not treat other failures as a legal gate', () {
      expect(
        isParentConsentRefusal(
          code: 'unavailable',
          details: {'code': 'consent_required'},
        ),
        isFalse,
      );
      expect(
        isParentConsentRefusal(
          code: 'failed-precondition',
          details: {'code': 'premium_required'},
        ),
        isFalse,
      );
      expect(
        isParentConsentRefusal(
          code: 'failed-precondition',
          details: 'not a map',
        ),
        isFalse,
      );
    });
  });

  group('FirebaseParentConsentService', () {
    test(
      'records version, purposes and origin, then treats uid as granted',
      () async {
        final calls = <Map<String, Object?>>[];
        final service = FirebaseParentConsentService(
          uid: () => 'parent-1',
          recordTransport: (payload) async {
            calls.add(payload);
            return {
              'ok': true,
              'changed': true,
              'textVersion': currentConsentTextVersion,
              'purposes': currentConsentPurposes,
              'origin': consentOrigin,
            };
          },
          statusTransport: (_) async => fail('status must not be read'),
        );

        final result = await service.record();
        expect(result.changed, isTrue);
        expect(calls.single, {
          'textVersion': currentConsentTextVersion,
          'purposes': currentConsentPurposes,
          'origin': 'parent_app',
        });
        expect((await service.status()).required, isFalse);
      },
    );

    test('reports a missing record as consent_required', () async {
      final service = FirebaseParentConsentService(
        uid: () => 'parent-1',
        recordTransport: (_) async => null,
        statusTransport: (_) async => null,
      );
      expect((await service.status()).required, isTrue);
    });

    test('treats old rules and offline reads as not blocking', () async {
      for (final code in ['permission-denied', 'unavailable']) {
        final service = FirebaseParentConsentService(
          uid: () => 'parent-1',
          recordTransport: (_) async => null,
          statusTransport: (_) async =>
              throw FirebaseException(plugin: 'cloud_firestore', code: code),
        );
        expect((await service.status()).required, isFalse, reason: code);
      }
    });

    test('rejects a malformed callable response', () async {
      final service = FirebaseParentConsentService(
        uid: () => 'parent-1',
        recordTransport: (_) async => {'ok': true},
        statusTransport: (_) async => null,
      );
      expect(service.record(), throwsStateError);
    });
  });

  testWidgets('the consent screen records the acceptance', (tester) async {
    final service = _FakeConsentService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [parentConsentServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ParentConsentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Precisamos do seu aceite'), findsOneWidget);
    expect(find.textContaining('Termos de Uso'), findsOneWidget);

    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();

    expect(service.records, 1);
    expect(tester.takeException(), isNull);
  });
}
