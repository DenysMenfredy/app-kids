import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/consent/parent_consent.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../application/auth_controller.dart';

/// Blocks the authenticated app until the parent accepts the current terms.
///
/// The backend fails closed on child writes (ADR 0020). This gate is the
/// client half: it reads the server-owned consent record and shows the
/// existing terms statement when the record is missing or from an old
/// version. It does not invent legal copy.
class ParentConsentGate extends ConsumerWidget {
  const ParentConsentGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(parentConsentStatusProvider);
    // A failed read is not proof of missing consent; the server still fails
    // closed on the calls that matter. Only the explicit status blocks.
    final required = status.asData?.value.required ?? false;
    if (!required) return child;

    return Stack(
      children: [
        child,
        const Positioned.fill(child: Material(child: ParentConsentScreen())),
      ],
    );
  }
}

class ParentConsentScreen extends ConsumerStatefulWidget {
  const ParentConsentScreen({super.key});

  @override
  ConsumerState<ParentConsentScreen> createState() =>
      _ParentConsentScreenState();
}

/// Asks for the current terms from a flow that hit `consent_required`.
///
/// Returns true only after the server recorded the acceptance. The caller can
/// then retry the action that was blocked.
Future<bool> showParentConsentDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ParentConsentDialog(),
  );
  return accepted == true;
}

class _ParentConsentDialog extends ConsumerStatefulWidget {
  const _ParentConsentDialog();

  @override
  ConsumerState<_ParentConsentDialog> createState() =>
      _ParentConsentDialogState();
}

class _ParentConsentDialogState extends ConsumerState<_ParentConsentDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(parentConsentServiceProvider).record();
      if (!mounted) return;
      acceptParentConsent(ref);
      Navigator.of(context).pop(true);
    } catch (error) {
      logConsentFailure(error);
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível registrar o aceite. Verifique a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cream,
      title: const Text('Aceite os termos atuais'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Para continuar, precisamos registrar o seu aceite dos termos '
            'atuais.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Aceito os Termos de Uso e a Política de Privacidade. Seus dados '
            'e os do seu filho estão protegidos (LGPD).',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.redDark),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Agora não'),
        ),
        TextButton(
          onPressed: _busy ? null : _accept,
          child: Text(_busy ? 'Registrando...' : 'Aceitar e continuar'),
        ),
      ],
    );
  }
}

class _ParentConsentScreenState extends ConsumerState<ParentConsentScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(parentConsentServiceProvider).record();
      if (!mounted) return;
      acceptParentConsent(ref);
    } catch (error) {
      logConsentFailure(error);
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível registrar o aceite. Verifique a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() => ref.read(authControllerProvider).signOut();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.tealPale,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      size: 38,
                      color: AppColors.tealDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Precisamos do seu aceite',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.screenTitle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Para criar o perfil da criança e salvar o progresso dela, '
                    'precisamos registrar o seu aceite dos termos atuais.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                    child: Text(
                      'Aceito os Termos de Uso e a Política de Privacidade. '
                      'Seus dados e os do seu filho estão protegidos (LGPD).',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.redDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  LeleButton(
                    label: _busy ? 'Registrando...' : 'Aceitar e continuar',
                    enabled: !_busy,
                    onPressed: _busy ? null : _accept,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _busy ? null : _signOut,
                    child: const Text('Sair da conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
