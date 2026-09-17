import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layer rules the feature folders are organised around.
///
/// These were documented but not enforced, and the presentation layer had
/// drifted into reaching straight past `application/` into `data/` in
/// thirteen places — every screen that needed a repository simply imported
/// one. Reading the imports is enough to keep that honest.
void main() {
  final lib = Directory('lib');

  List<({String path, List<String> imports})> dartFiles(
    bool Function(String path) where,
  ) {
    return lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => (path: f.path, imports: _importsOf(f)))
        .where((f) => where(f.path))
        .toList();
  }

  test('presentation never reaches into data', () {
    final offenders = <String>[];
    for (final file in dartFiles((p) => p.contains('/presentation/'))) {
      for (final import in file.imports) {
        if (import.contains('/data/') || import.startsWith('data/')) {
          offenders.add('${file.path} -> $import');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'A screen needing a repository wants a controller in application/ '
          'that owns the call, not a direct line to data/:\n'
          '${offenders.join('\n')}',
    );
  });

  test('domain stays free of Flutter and Firebase', () {
    const banned = [
      'package:flutter/',
      'package:cloud_firestore/',
      'package:cloud_functions/',
      'package:firebase_',
      'package:flutter_riverpod/',
    ];
    final offenders = <String>[];
    for (final file in dartFiles((p) => p.contains('/domain/'))) {
      for (final import in file.imports) {
        if (banned.any(import.startsWith)) {
          offenders.add('${file.path} -> $import');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'A Color or an IconData on a domain model is a rendering decision '
          'the backend cannot express; put it beside the widget that paints '
          'it:\n${offenders.join('\n')}',
    );
  });

  test('application builds no widgets', () {
    final offenders = <String>[];
    for (final file in dartFiles((p) => p.contains('/application/'))) {
      for (final import in file.imports) {
        if (import == 'package:flutter/material.dart' ||
            import == 'package:flutter/widgets.dart') {
          offenders.add('${file.path} -> $import');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

List<String> _importsOf(File file) {
  final pattern = RegExp(r"""^\s*import\s+['"]([^'"]+)['"]""", multiLine: true);
  return pattern
      .allMatches(file.readAsStringSync())
      .map((m) => m.group(1)!)
      .toList();
}
