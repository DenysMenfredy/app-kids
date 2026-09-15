import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_text_field.dart';
import '../../session/application/session_controller.dart';
import '../data/auth_repository.dart';
import '../domain/credentials.dart';

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

  Future<void> _signUp() async {
    if (_busy || !_validate()) return;
    setState(() => _busy = true);
    final name = _nameController.text.trim();
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            name: name,
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // The name the parent just gave is what the dashboard greets them by,
      // here and on every device they sign in from.
      ref.read(sessionProvider.notifier).setParentName(name);
      if (mounted) context.goNamed(AppRoutes.profileSetup);
    } on AuthFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
              const SizedBox(height: 8),
              Text(
                'Conta para os pais — leva menos de 2 minutos.',
                style: AppTextStyles.subtitle,
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 18),
              const _LgpdNotice(),
              const SizedBox(height: 18),
              LeleButton(
                label: _busy ? 'Criando conta...' : 'Criar conta',
                enabled: !_busy,
                color: _busy ? AppColors.borderMuted : AppColors.orange,
                shadowColor: _busy
                    ? AppColors.textDisabled
                    : AppColors.orangeDark,
                onPressed: _signUp,
              ),
              const SizedBox(height: 40),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Já tem conta? ',
                    style: AppTextStyles.nunito(15, color: AppColors.textMuted),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: _busy
                              ? null
                              : () => context.goNamed(AppRoutes.login),
                          child: Text(
                            'Entrar',
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

class _LgpdNotice extends StatelessWidget {
  const _LgpdNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(7),
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
              style: AppTextStyles.nunito(
                13,
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
