import 'child_record.dart';

/// Server-owned mapping written while the legacy `children/primary` document
/// is migrated to a server-issued child ID.
///
/// The app reads it only to avoid showing the same child twice. The mapping is
/// not trusted for authorization: Firestore callables and Rules remain the
/// authority. Anything malformed, absent or rolled back keeps the legacy
/// `primary` fallback for old clients.
class PrimaryChildMigration {
  const PrimaryChildMigration({
    required this.legacyId,
    required this.newChildId,
    required this.flowVersion,
  });

  static const statusMigrated = 'migrated';
  static const flowVersionV1 = 'primary-migration-v1';

  final String legacyId;
  final String newChildId;
  final String flowVersion;

  /// Parses a `users/{uid}/migrations/primaryChild` document. Returns null for
  /// absent, rolled-back or unrecognised mappings so callers keep the old path.
  static PrimaryChildMigration? fromMap(Map<String, Object?>? data) {
    if (data == null) return null;
    if (data['status'] != statusMigrated) return null;
    final legacyId = data['legacyId'];
    final newChildId = data['newChildId'];
    final flowVersion = data['flowVersion'];
    if (legacyId != 'primary' ||
        flowVersion != flowVersionV1 ||
        newChildId is! String ||
        newChildId.isEmpty ||
        newChildId == 'primary') {
      return null;
    }
    return PrimaryChildMigration(
      legacyId: legacyId as String,
      newChildId: newChildId,
      flowVersion: flowVersion as String,
    );
  }
}

/// Drops the legacy `primary` document only when the migration points at a
/// child that is actually present in the list. If the copy is missing, the
/// legacy document stays visible; the backend's rollback then matches what
/// the parent sees.
List<ChildRecord> applyPrimaryChildMigration(
  List<ChildRecord> children,
  PrimaryChildMigration? migration,
) {
  if (migration == null) return children;
  final hasMigratedChild = children.any(
    (child) => child.id == migration.newChildId,
  );
  if (!hasMigratedChild) return children;
  return List.unmodifiable(
    children.where((child) => child.id != migration.legacyId),
  );
}
