import 'dart:math';

/// Server-visible states of an account-deletion request (ADR 0022/0023).
enum AccountDeletionStatus { requested, processing, completed, failed }

AccountDeletionStatus? accountDeletionStatusFrom(Object? value) {
  return switch (value) {
    'requested' => AccountDeletionStatus.requested,
    'processing' => AccountDeletionStatus.processing,
    'completed' => AccountDeletionStatus.completed,
    'failed' => AccountDeletionStatus.failed,
    _ => null,
  };
}

String accountDeletionStatusLabel(AccountDeletionStatus status) {
  return switch (status) {
    AccountDeletionStatus.requested => 'Solicitada',
    AccountDeletionStatus.processing => 'Em processamento',
    AccountDeletionStatus.completed => 'Concluída',
    AccountDeletionStatus.failed => 'Falhou e será tentada novamente',
  };
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.status,
    required this.requestId,
    required this.changed,
  });

  final AccountDeletionStatus status;
  final String requestId;
  final bool changed;
}

enum AccountDeletionFailureCode {
  reauthRequired,
  pending,
  sessionRevocationFailed,
  invalidState,
  unavailable,
  unsupportedProvider,
  unknown,
}

class AccountDeletionFailure implements Exception {
  const AccountDeletionFailure(this.code, this.message);

  final AccountDeletionFailureCode code;
  final String message;

  @override
  String toString() => 'AccountDeletionFailure($code): $message';
}

/// Maps the callable's typed details without trusting arbitrary server text.
AccountDeletionFailure accountDeletionFailureFrom({
  required String code,
  Object? details,
}) {
  String? detailCode;
  if (details is Map) {
    final typed = Map<Object?, Object?>.from(details);
    final value = typed['code'];
    if (value is String) detailCode = value;
  }

  if (code == 'failed-precondition' && detailCode == 'reauth_required') {
    return const AccountDeletionFailure(
      AccountDeletionFailureCode.reauthRequired,
      'Confirme sua senha ou entre novamente com o Google antes de excluir a conta.',
    );
  }
  if (detailCode == 'account_deletion_pending') {
    return const AccountDeletionFailure(
      AccountDeletionFailureCode.pending,
      'Já existe uma solicitação de exclusão em andamento para esta conta.',
    );
  }
  if (code == 'internal' && detailCode == 'session_revocation_failed') {
    return const AccountDeletionFailure(
      AccountDeletionFailureCode.sessionRevocationFailed,
      'A solicitação foi registrada, mas não foi possível encerrar todas as sessões. Tente novamente.',
    );
  }
  if (detailCode == 'deletion_state_invalid') {
    return const AccountDeletionFailure(
      AccountDeletionFailureCode.invalidState,
      'Não foi possível ler o estado da exclusão. Fale com o suporte.',
    );
  }
  if (code == 'unavailable' || code == 'deadline-exceeded') {
    return const AccountDeletionFailure(
      AccountDeletionFailureCode.unavailable,
      'Não foi possível falar com o servidor. Verifique a conexão e tente novamente.',
    );
  }
  return const AccountDeletionFailure(
    AccountDeletionFailureCode.unknown,
    'Não foi possível solicitar a exclusão agora. Tente novamente.',
  );
}

/// Bounded, client-generated idempotency key accepted by the callable.
String newAccountDeletionRequestId([Random? random]) {
  final source = random ?? Random.secure();
  return List.generate(
    16,
    (_) => source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Parses the callable response and rejects a missing or unknown status.
AccountDeletionResult accountDeletionResultFrom(Object? data) {
  if (data is! Map) {
    throw const AccountDeletionFailure(
      AccountDeletionFailureCode.unknown,
      'Resposta inválida do servidor.',
    );
  }
  final map = Map<Object?, Object?>.from(data);
  final status = accountDeletionStatusFrom(map['status']);
  final requestId = map['requestId'];
  if (status == null || requestId is! String || requestId.isEmpty) {
    throw const AccountDeletionFailure(
      AccountDeletionFailureCode.unknown,
      'Resposta inválida do servidor.',
    );
  }
  return AccountDeletionResult(
    status: status,
    requestId: requestId,
    changed: map['changed'] == true,
  );
}
