import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_text_field.dart';
import '../application/auth_controller.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';
import '../domain/sign_in_outcome.dart';
import 'apple_account_prompt.dart';
import 'apple_sign_in_button.dart';
import 'google_sign_in_button.dart';
import 'or_divider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    final nameError = validateName(_nameController.text);
    final emailError = validateEmail(_emailController.text);
    final passwordError = validatePassword(_passwordController.text);
    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return nameError == null && emailError == null && passwordError == null;
  }

  void _showFailure(AuthFailure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signUpWithGoogle() =>
      _withProvider(() => ref.read(authControllerProvider).signInWithGoogle());

  Future<void> _signUpWithApple() => _withProvider(
    () => ref.read(authControllerProvider).signInWithApple(),
    appleSignIn: true,
  );

  /// A provider tap on the sign-up screen is the same call as on sign-in —
  /// Google decides whether this is a new account, not the screen it was
  /// tapped from. A parent who already has one is simply signed in.
  Future<void> _withProvider(
    Future<SignInOutcome> Function() action, {
    bool appleSignIn = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await action();
      if (!mounted) return;
      if (appleSignIn &&
          outcome == SignInOutcome.created &&
          AppConfig.useFirebase) {
        final continueWithApple = await showAppleAccountCreationPrompt(context);
        if (!mounted) return;
        if (continueWithApple != true) {
          await ref.read(authControllerProvider).signOut();
          if (mounted) {
            final messenger = ScaffoldMessenger.of(context);
            context.goNamed(AppRoutes.login);
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Entre na sua conta existente e conecte o Apple ID nas opções da conta.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
      switch (outcome) {
        case SignInOutcome.created:
          context.goNamed(AppRoutes.profileSetup);
        case SignInOutcome.returning:
          context.goNamed(AppRoutes.dashboard);
        case SignInOutcome.cancelled:
          break;
      }
    } on AuthFailure catch (failure) {
      if (mounted) _showFailure(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    if (_busy || !_validate()) return;
    setState(() => _busy = true);
    final name = _nameController.text.trim();
    try {
      await ref
          .read(authControllerProvider)
          .signUp(
            name: name,
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted && AppConfig.useFirebase) {
        context.goNamed(
          AppRoutes.emailVerification,
          queryParameters: const {'next': 'new-child', 'send': 'true'},
        );
      } else if (mounted) {
        context.goNamed(AppRoutes.profileSetup);
      }
    } on AuthFailure catch (failure) {
      if (mounted) _showFailure(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              Text('Criar conta', style: AppTextStyles.screenTitle),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Conta para os pais — leva menos de 2 minutos.',
                style: AppTextStyles.subtitle,
              ),
              const SizedBox(height: AppSpacing.xxl),
              LeleTextField(
                hint: 'Seu nome',
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
                errorText: _nameError,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                onSubmitted: (_) => _emailFocus.requestFocus(),
              ),
              const SizedBox(height: AppSpacing.md),
              LeleTextField(
                hint: 'E-mail',
                controller: _emailController,
                focusNode: _emailFocus,
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
                onSubmitted: (_) => _signUp(),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: AppColors.textFaint,
                    size: 22,
                  ),
                  tooltip: _obscurePassword
                      ? 'Mostrar senha'
                      : 'Esconder senha',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _LgpdNotice(),
              const SizedBox(height: AppSpacing.xl),
              LeleButton(
                label: _busy ? 'Criando conta...' : 'Criar conta',
                enabled: !_busy,
                color: _busy ? AppColors.borderMuted : AppColors.orange,
                shadowColor: _busy
                    ? AppColors.textDisabled
                    : AppColors.orangeDark,
                onPressed: _signUp,
              ),
              const SizedBox(height: AppSpacing.md),
              // Google asks for the provider to be offered where accounts
              // are created, not only where they are entered. A parent who
              // starts here and taps Google ends up in exactly the same
              // place as one who fills the form: profile setup.
              const OrDivider(),
              const SizedBox(height: AppSpacing.md),
              if (AppleSignInButton.isSupported) ...[
                AppleSignInButton(
                  onPressed: _busy ? null : _signUpWithApple,
                  label: 'Continuar com Apple',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              GoogleSignInButton(
                onPressed: _busy ? null : _signUpWithGoogle,
                label: 'Criar conta com Google',
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Já tem conta? ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: _busy
                              ? null
                              : () => context.goNamed(AppRoutes.login),
                          child: Text(
                            'Entrar',
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

class _LgpdNotice extends StatelessWidget {
  const _LgpdNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(AppRadius.bar),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              'Aceito os Termos de Uso e a Política de Privacidade. Seus '
              'dados e os do seu filho estão protegidos (LGPD).',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
