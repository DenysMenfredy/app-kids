import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_deletion_service.dart';
import '../domain/account_deletion.dart';

/// Application boundary for the account-deletion screen.
///
/// Keeps the screen away from the Firebase-backed data service while exposing
/// only what the UI needs to render and submit.
class AccountDeletionController {
  AccountDeletionController(this._ref);

  final Ref _ref;

  AccountDeletionService get _service =>
      _ref.read(accountDeletionServiceProvider);

  bool get supported => _service.supported;
  bool get isPasswordProvider => _service.isPasswordProvider;
  String? get email => _service.email;
  String? get providerId => _service.providerId;

  Future<void> reauthenticateWithPassword(String password) =>
      _service.reauthenticateWithPassword(password);

  Future<void> reauthenticateWithProvider() =>
      _service.reauthenticateWithProvider();

  Future<AccountDeletionResult> request(String requestId) =>
      _service.request(requestId);

  Future<void> clearLocalState() => _service.clearLocalState();
}

final accountDeletionControllerProvider = Provider<AccountDeletionController>(
  AccountDeletionController.new,
);
