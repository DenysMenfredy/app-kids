import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_text_field.dart';
import '../data/auth_repository.dart';
import '../domain/credentials.dart';

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
          .read(authRepositoryProvider)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.goNamed(AppRoutes.dashboard);
    });
  }

  Future<void> _signInWithGoogle() => _run(() async {
    await ref.read(authRepositoryProvider).signInWithGoogle();
    if (mounted) context.goNamed(AppRoutes.dashboard);
  });

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
          .read(authRepositoryProvider)
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
              const SizedBox(height: 8),
              Text(
                'Entre para continuar a jornada de leitura.',
                style: AppTextStyles.subtitle,
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _busy ? null : _resetPassword,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Esqueci minha senha',
                      style: AppTextStyles.nunito(
                        14,
                        weight: FontWeight.w700,
                        color: AppColors.orangeDark,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              LeleButton(
                label: _busy ? 'Entrando...' : 'Entrar',
                enabled: !_busy,
                color: _busy ? AppColors.borderMuted : AppColors.orange,
                shadowColor: _busy
                    ? AppColors.textDisabled
                    : AppColors.orangeDark,
                onPressed: _signIn,
              ),
              const SizedBox(height: 12),
              const _OrDivider(),
              const SizedBox(height: 12),
              _GoogleButton(onTap: _busy ? null : _signInWithGoogle),
              const SizedBox(height: 40),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Não tem conta? ',
                    style: AppTextStyles.nunito(15, color: AppColors.textMuted),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: _busy
                              ? null
                              : () => context.goNamed(AppRoutes.register),
                          child: Text(
                            'Criar conta',
                            style: AppTextStyles.nunito(
                              15,
                              weight: FontWeight.w800,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 2)),
        Text(
          'ou',
          style: AppTextStyles.nunito(
            13,
            weight: FontWeight.w700,
            color: AppColors.textFaint,
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 2)),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFFEA4335),
                    Color(0xFFFBBC05),
                    Color(0xFF34A853),
                    Color(0xFF4285F4),
                    Color(0xFFEA4335),
                  ],
                  stops: [0.25, 0.5, 0.75, 1.0, 1.0],
                ),
              ),
            ),
            Flexible(
              child: Text(
                'Continuar com Google',
                style: AppTextStyles.nunito(16, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
