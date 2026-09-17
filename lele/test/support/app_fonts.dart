import 'dart:io';

import 'package:flutter/services.dart';

/// Widget tests use a fallback font whose glyphs are far wider than Baloo 2.
/// Measuring text against it would exaggerate every wrap and shrink, so load
/// the real bundled faces before measuring anything.
///
/// This matters for more than wrapping. A row that splits its free space
/// between flex children leaves dead space only when a loose child is
/// *narrower* than its share — with the fat fallback font the dashboard's
/// status chip filled its share exactly at 430dp, so a geometry test there
/// measured perfectly aligned while the shipped build was 81px out.
Future<void> loadAppFonts() async {
  for (final family in const {
    'Baloo 2': ['Baloo2-Bold.ttf', 'Baloo2-ExtraBold.ttf'],
    'Nunito': ['Nunito-Bold.ttf', 'Nunito-SemiBold.ttf', 'Nunito-Regular.ttf'],
  }.entries) {
    final loader = FontLoader(family.key);
    for (final file in family.value) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}
