import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/features/session/application/child_provider.dart';
import 'package:lele/features/session/domain/child_profile.dart';
import 'package:lele/features/session/domain/child_record.dart';
import 'package:lele/features/session/domain/primary_child_migration.dart';

const _primary = ChildRecord(
  id: 'primary',
  profile: ChildProfile(name: 'Sofia', age: 5, avatar: ChildAvatar.orange),
);

const _migrated = ChildRecord(
  id: 'child_server_1',
  profile: ChildProfile(name: 'Sofia', age: 5, avatar: ChildAvatar.orange),
);

const _other = ChildRecord(
  id: 'child_server_2',
  profile: ChildProfile(name: 'Caio', age: 6, avatar: ChildAvatar.teal),
);

PrimaryChildMigration _mapping({String? newChildId}) => PrimaryChildMigration(
  legacyId: 'primary',
  newChildId: newChildId ?? 'child_server_1',
  flowVersion: PrimaryChildMigration.flowVersionV1,
);

Map<String, Object?> _document({String status = 'migrated'}) => {
  'status': status,
  'legacyId': 'primary',
  'newChildId': 'child_server_1',
  'flowVersion': 'primary-migration-v1',
};

void main() {
  group('PrimaryChildMigration.fromMap', () {
    test('accepts the v1 migrated mapping', () {
      final migration = PrimaryChildMigration.fromMap(_document());
      expect(migration?.newChildId, 'child_server_1');
    });

    test('keeps legacy fallback for absent or rolled-back mappings', () {
      expect(PrimaryChildMigration.fromMap(null), isNull);
      expect(
        PrimaryChildMigration.fromMap(_document(status: 'rolled_back')),
        isNull,
      );
    });

    test('rejects malformed or unknown mappings', () {
      expect(
        PrimaryChildMigration.fromMap(
          _document()..['flowVersion'] = 'future-version',
        ),
        isNull,
      );
      expect(
        PrimaryChildMigration.fromMap(_document()..['newChildId'] = 'primary'),
        isNull,
      );
      expect(
        PrimaryChildMigration.fromMap(_document()..remove('newChildId')),
        isNull,
      );
    });
  });

  group('applyPrimaryChildMigration', () {
    test('hides the legacy primary when the new child exists', () {
      final result = applyPrimaryChildMigration(const [
        _primary,
        _migrated,
        _other,
      ], _mapping());
      expect(result.map((child) => child.id), [
        'child_server_1',
        'child_server_2',
      ]);
    });

    test('keeps primary for an old client with no mapping', () {
      final result = applyPrimaryChildMigration(const [_primary, _other], null);
      expect(result.map((child) => child.id), ['primary', 'child_server_2']);
    });

    test('keeps primary when the copied child is not present yet', () {
      final result = applyPrimaryChildMigration(const [
        _primary,
        _other,
      ], _mapping());
      expect(result.map((child) => child.id), ['primary', 'child_server_2']);
    });
  });

  group('resolveSelectedChild with a completed migration', () {
    test('a cached primary selection resolves to the migrated child', () {
      final selected = resolveSelectedChild(
        const AsyncData([_migrated, _other]),
        'primary',
        migratedNewChildId: 'child_server_1',
      );
      expect(selected.value?.id, 'child_server_1');
      expect(selected.value?.profile.name, 'Sofia');
    });

    test('an explicit server child selection is preserved', () {
      final selected = resolveSelectedChild(
        const AsyncData([_migrated, _other]),
        'child_server_2',
        migratedNewChildId: 'child_server_1',
      );
      expect(selected.value?.id, 'child_server_2');
    });

    test('old clients still select primary without the mapping', () {
      final selected = resolveSelectedChild(
        const AsyncData([_primary, _other]),
        'primary',
      );
      expect(selected.value?.id, 'primary');
    });
  });
}
