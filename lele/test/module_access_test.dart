import 'package:flutter_test/flutter_test.dart';
import 'package:lele/features/learning/domain/module_access.dart';

void main() {
  test('module one stays available to a Firebase account without Premium', () {
    expect(
      canOpenModule(moduleNumber: 1, premium: false, firebaseEnabled: true),
      isTrue,
    );
  });

  test('later modules fail closed until Premium is active', () {
    expect(
      canOpenModule(moduleNumber: 2, premium: false, firebaseEnabled: true),
      isFalse,
    );
    expect(
      canOpenModule(moduleNumber: 2, premium: true, firebaseEnabled: true),
      isTrue,
    );
  });

  test('offline demo mode remains playable', () {
    expect(
      canOpenModule(moduleNumber: 3, premium: false, firebaseEnabled: false),
      isTrue,
    );
  });
}
