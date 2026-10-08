import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../application/auth_controller.dart';
import '../domain/auth_failure.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.nextStep,
    this.sendOnOpen = false,
  });

  /// The onboarding destination to resume after verification.
  final String nextStep;
  final bool sendOnOpen;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with WidgetsBindingObserver {
  static const _resendCooldown = 60;

  Timer? _cooldownTimer;
  int _secondsToResend = 0;
  bool _sending = false;
  bool _checking = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.sendOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_sendVerificationEmail());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkVerification());
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_sending || _secondsToResend > 0) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      await ref.read(authControllerProvider).sendEmailVerification();
      if (!mounted) return;
      setState(
        () => _message = 'Link enviado. Confira também a pasta de spam.',
      );
      _startCooldown();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsToResend = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsToResend <= 1) {
        timer.cancel();
        setState(() => _secondsToResend = 0);
      } else {
        setState(() => _secondsToResend--);
      }
    });
  }

  Future<void> _checkVerification() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final verified = await ref
          .read(authControllerProvider)
          .refreshEmailVerification();
      if (verified && mounted) _continueAfterVerification();
      if (!verified && mounted) {
        setState(() {
          _message =
              'Ainda não encontramos a confirmação. Abra o link e tente novamente.';
        });
      }
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _continueAfterVerification() {
    switch (widget.nextStep) {
      case 'new-child':
        context.goNamed(AppRoutes.profileSetup);
      case 'add-child':
        context.goNamed(
          AppRoutes.profileSetup,
          queryParameters: const {'new': 'true'},
        );
      case 'edit-child':
        context.goNamed(
          AppRoutes.profileSetup,
          queryParameters: const {'edit': 'true'},
        );
      case 'paywall':
        context.goNamed(AppRoutes.paywall);
      default:
        context.goNamed(AppRoutes.dashboard);
    }
  }

  Future<void> _switchAccount() async {
    await ref.read(authControllerProvider).signOut();
    if (mounted) context.goNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authControllerProvider).currentUserEmail;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xxxl,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.orangePale,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 42,
                      color: AppColors.orangeDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Confirme seu e-mail',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.screenTitle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Confirme ${email ?? 'o endereço de e-mail da sua conta'} '
                    'para cadastrar ou editar o perfil da criança e iniciar '
                    'uma assinatura. Se ainda não recebeu o link, toque em '
                    '“Reenviar link de confirmação”.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LeleButton(
                    label: _checking ? 'Verificando...' : 'Já confirmei',
                    enabled: !_checking && !_sending,
                    onPressed: _checkVerification,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _sending || _secondsToResend > 0
                        ? null
                        : _sendVerificationEmail,
                    child: Text(
                      _sending
                          ? 'Enviando link...'
                          : _secondsToResend > 0
                          ? 'Reenviar link em ${_secondsToResend}s'
                          : 'Reenviar link de confirmação',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.orangeDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_message case final message?) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: message.startsWith('Link enviado')
                            ? AppColors.tealDark
                            : AppColors.redDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: TextButton(
                      onPressed: _sending || _checking ? null : _switchAccount,
                      child: Text(
                        'Usar outra conta',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textFaint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
