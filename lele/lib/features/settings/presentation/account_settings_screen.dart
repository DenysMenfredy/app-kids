import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../auth/application/auth_controller.dart';
import '../application/account_deletion_controller.dart';
import '../domain/account_deletion.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key, this.signOutOverride});

  /// Tests inject a sign-out without building the Firebase auth graph.
  final Future<void> Function()? signOutOverride;

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _showReauth = false;
  String? _error;
  AccountDeletionResult? _pending;
  String? _requestId;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmStart() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir sua conta?'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Serão apagados a conta do responsável, os perfis das crianças '
                'e o progresso de aprendizagem. Esta ação não pode ser desfeita.',
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'A exclusão da conta não cancela automaticamente uma assinatura '
                'feita na Google Play ou na App Store. Cancele na loja antes de '
                'continuar, se houver uma assinatura ativa.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        _showReauth = true;
        _error = null;
      });
    }
  }

  Future<void> _reauthWithPassword() async {
    if (_busy) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Informe sua senha para continuar.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountDeletionControllerProvider)
          .reauthenticateWithPassword(password);
      await _requestDeletion();
    } on AccountDeletionFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      }
    }
  }

  Future<void> _reauthWithProvider() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountDeletionControllerProvider)
          .reauthenticateWithProvider();
      await _requestDeletion();
    } on AccountDeletionFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      }
    }
  }

  Future<void> _requestDeletion() async {
    final service = ref.read(accountDeletionControllerProvider);
    final requestId = _requestId ?? newAccountDeletionRequestId();
    _requestId = requestId;
    try {
      final result = await service.request(requestId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pending = result;
      });
      if (result.status == AccountDeletionStatus.failed) {
        setState(
          () => _error =
              'A solicitação falhou e pode ser tentada novamente pelo suporte.',
        );
        return;
      }
      await _showPendingDialog(result);
    } on AccountDeletionFailure catch (failure) {
      if (!mounted) return;
      setState(() => _busy = false);
      switch (failure.code) {
        case AccountDeletionFailureCode.reauthRequired:
          setState(() {
            _showReauth = true;
            _error = failure.message;
          });
        case AccountDeletionFailureCode.sessionRevocationFailed:
          await _showRevocationFailure();
        case AccountDeletionFailureCode.pending:
          setState(
            () => _pending = const AccountDeletionResult(
              status: AccountDeletionStatus.requested,
              requestId: 'existing',
              changed: false,
            ),
          );
          await _showPendingDialog(_pending!);
        default:
          setState(() => _error = failure.message);
      }
    }
  }

  Future<void> _showPendingDialog(AccountDeletionResult result) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Conta em exclusão'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: ${accountDeletionStatusLabel(result.status)}.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'A solicitação foi registrada no servidor. O processamento '
                'continua fora do app e você será desconectado agora. '
                'A assinatura da loja, se existir, não é cancelada por aqui.',
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Não crie outra conta com os mesmos dados enquanto a exclusão '
                'estiver pendente.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Sair da conta'),
          ),
        ],
      ),
    );
    await _finishAndSignOut();
  }

  Future<void> _showRevocationFailure() async {
    if (!mounted) return;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Solicitação registrada'),
        content: const Text(
          'A conta já está bloqueada para novos dados, mas não foi possível '
          'encerrar todas as sessões. Tente novamente; a solicitação é '
          'idempotente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Sair da conta'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == true) {
      setState(() => _busy = true);
      await _requestDeletion();
    } else {
      await _finishAndSignOut();
    }
  }

  Future<void> _finishAndSignOut() async {
    final service = ref.read(accountDeletionControllerProvider);
    await service.clearLocalState();
    final signOut =
        widget.signOutOverride ??
        () => ref.read(authControllerProvider).signOut();
    await signOut();
  }

  Future<void> _openStoreSubscriptions() async {
    final uri = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a loja.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a loja.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(accountDeletionControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações da conta'),
        leading: IconButton(
          tooltip: 'Voltar ao painel',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(AppRoutes.dashboard),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            if (service.email != null && service.email!.isNotEmpty) ...[
              Text('Conta', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              Text(service.email!, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.xl),
            ],
            Text('Excluir conta', style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Apaga a conta do responsável, os perfis das crianças e o '
              'progresso de aprendizagem. Não é possível desfazer.',
              style: AppTextStyles.body.copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assinatura da loja', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Excluir a conta não cancela uma assinatura feita na '
                    'Google Play ou na App Store. Se você tem uma assinatura '
                    'ativa, cancele na loja antes de continuar.',
                    style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: _openStoreSubscriptions,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(
                      defaultTargetPlatform == TargetPlatform.iOS
                          ? 'Gerenciar assinaturas na App Store'
                          : 'Gerenciar assinaturas na Google Play',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!service.supported)
              Text(
                'A exclusão de conta exige uma conta conectada ao Firebase.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              )
            else if (_pending == null && !_showReauth)
              LeleButton(
                label: 'Excluir minha conta',
                color: AppColors.red,
                shadowColor: AppColors.redDark,
                onPressed: _busy ? null : _confirmStart,
              )
            else if (_pending == null) ...[
              Text(
                'Confirme sua identidade para continuar',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.md),
              if (service.isPasswordProvider) ...[
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _reauthWithPassword(),
                  decoration: const InputDecoration(
                    labelText: 'Senha da conta',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LeleButton(
                  label: _busy ? 'Confirmando...' : 'Confirmar e excluir',
                  color: AppColors.red,
                  shadowColor: AppColors.redDark,
                  enabled: !_busy,
                  onPressed: _reauthWithPassword,
                ),
              ] else ...[
                LeleButton(
                  label: _busy
                      ? 'Confirmando...'
                      : service.providerId == 'apple.com'
                      ? 'Confirmar com Apple'
                      : 'Confirmar com Google',
                  color: AppColors.red,
                  shadowColor: AppColors.redDark,
                  enabled: !_busy,
                  onPressed: _reauthWithProvider,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _showReauth = false),
                child: const Text('Cancelar'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.redDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
