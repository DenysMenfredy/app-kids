import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_text_field.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.goNamed(AppRoutes.dashboard);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) context.goNamed(AppRoutes.dashboard);
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
              ),
              const SizedBox(height: 12),
              LeleTextField(
                hint: 'Senha',
                controller: _passwordController,
                obscureText: true,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Esqueci minha senha',
                  style: AppTextStyles.nunito(
                    14,
                    weight: FontWeight.w700,
                    color: AppColors.orangeDark,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              LeleButton(label: 'Entrar', onPressed: _signIn),
              const SizedBox(height: 12),
              const _OrDivider(),
              const SizedBox(height: 12),
              _GoogleButton(onTap: _signInWithGoogle),
              const SizedBox(height: 40),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Não tem conta? ',
                    style: AppTextStyles.nunito(
                      15,
                      color: AppColors.textMuted,
                    ),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => context.goNamed(AppRoutes.register),
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

  final VoidCallback onTap;

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
            Text(
              'Continuar com Google',
              style: AppTextStyles.nunito(16, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
