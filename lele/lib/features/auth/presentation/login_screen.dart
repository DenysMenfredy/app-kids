import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_text_field.dart';
import '../application/auth_controller.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';
import '../domain/sign_in_outcome.dart';
import 'apple_sign_in_button.dart';
import 'google_sign_in_button.dart';
import 'or_divider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  String? _emailError;
  String? _passwordError;
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Fills in the per-field errors and reports whether the form may be sent.
  bool _validate() {
    final emailError = validateEmail(_emailController.text);
    final passwordError = validatePassword(_passwordController.text);
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return emailError == null && passwordError == null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on AuthFailure catch (failure) {
      _showMessage(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (!_validate()) return;
    await _run(() async {
      await ref
          .read(authControllerProvider)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.goNamed(AppRoutes.dashboard);
    });
  }

  Future<void> _signInWithGoogle() => _run(
    () async => _continueFrom(
      await ref.read(authControllerProvider).signInWithGoogle(),
    ),
  );

  Future<void> _signInWithApple() => _run(
    () async =>
        _continueFrom(await ref.read(authControllerProvider).signInWithApple()),
  );

  /// Sends the parent wherever the sign-in actually left them.
  ///
  /// A provider button is a sign-in and a sign-up at once, and the two need
  /// different screens next. Sending everyone to the dashboard — which is
  /// what this did — dropped a brand-new parent onto a summary of a family
  /// that does not exist yet: no child, no assessment, nothing to show.
  void _continueFrom(SignInOutcome outcome) {
    if (!mounted) return;
    switch (outcome) {
      case SignInOutcome.created:
        // The same door an e-mail sign-up goes through.
        context.goNamed(AppRoutes.profileSetup);
      case SignInOutcome.returning:
        context.goNamed(AppRoutes.dashboard);
      case SignInOutcome.cancelled:
        // They closed the sheet. Leave the screen exactly as it was.
        break;
    }
  }

  /// A reset needs only the e-mail, so the password error is cleared first.
  Future<void> _resetPassword() async {
    final emailError = validateEmail(_emailController.text);
    setState(() {
      _emailError = emailError;
      _passwordError = null;
    });
    if (emailError != null) return;

    await _run(() async {
      await ref
          .read(authControllerProvider)
          .sendPasswordReset(_emailController.text);
      _showMessage(
        'Enviamos um link de recuperação para '
        '${_emailController.text.trim()}.',
      );
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 32, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Que bom te ver!', style: AppTextStyles.screenTitle),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Entre para continuar a jornada de leitura.',
                style: AppTextStyles.subtitle,
              ),
              const SizedBox(height: AppSpacing.xxl),
              LeleTextField(
                hint: 'E-mail',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: AppSpacing.md),
              LeleTextField(
                hint: 'Senha',
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                enabled: !_busy,
                errorText: _passwordError,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                onSubmitted: (_) => _signIn(),
                suffixIcon: _PasswordToggle(
                  obscured: _obscurePassword,
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _busy ? null : _resetPassword,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      'Esqueci minha senha',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.orangeDark,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              LeleButton(
                label: _busy ? 'Entrando...' : 'Entrar',
                enabled: !_busy,
                color: _busy ? AppColors.borderMuted : AppColors.orange,
                shadowColor: _busy
                    ? AppColors.textDisabled
                    : AppColors.orangeDark,
                onPressed: _signIn,
              ),
              const SizedBox(height: AppSpacing.md),
              const OrDivider(),
              const SizedBox(height: AppSpacing.md),
              // Review guideline 4.8 asks for Sign in with Apple to be
              // offered on equivalent terms to any other third-party
              // sign-in: same size, same shape, immediately adjacent.
              if (AppleSignInButton.isSupported) ...[
                AppleSignInButton(onPressed: _busy ? null : _signInWithApple),
                const SizedBox(height: AppSpacing.md),
              ],
              GoogleSignInButton(onPressed: _busy ? null : _signInWithGoogle),
              const SizedBox(height: AppSpacing.xxxl),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Não tem conta? ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: _busy
                              ? null
                              : () => context.goNamed(AppRoutes.register),
                          child: Text(
                            'Criar conta',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.orangeDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordToggle extends StatelessWidget {
  const _PasswordToggle({required this.obscured, required this.onPressed});

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        color: AppColors.textFaint,
        size: 22,
      ),
      tooltip: obscured ? 'Mostrar senha' : 'Esconder senha',
    );
  }
}
