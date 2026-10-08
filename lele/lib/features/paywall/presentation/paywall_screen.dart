import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../auth/application/auth_controller.dart';
import '../application/checkout_controller.dart';
import '../domain/checkout_failure.dart';
import '../domain/plan.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selectedPlanId = 'annual';
  bool _busy = false;

  /// App plan ids → backend/Stripe plan ids (domain/plans.ts).
  static const _backendPlanIds = {
    'monthly': 'founder_monthly',
    'quarterly': 'founder_quarterly',
    'annual': 'founder_annual',
  };

  Future<void> _startCheckout() async {
    if (_busy) return;
    if (ref.read(authControllerProvider).requiresEmailVerification) {
      context.goNamed(
        AppRoutes.emailVerification,
        queryParameters: const {'next': 'paywall'},
      );
      return;
    }
    final checkout = ref.read(checkoutControllerProvider);
    if (!checkout.paymentsEnabled) {
      return;
    }
    setState(() => _busy = true);
    try {
      await checkout.start(_backendPlanIds[_selectedPlanId]!);
    } on CheckoutFailure catch (failure) {
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
    final paymentsEnabled = ref
        .watch(checkoutControllerProvider)
        .paymentsEnabled;
    final needsEmailVerification = ref
        .watch(authControllerProvider)
        .requiresEmailVerification;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.md,
            AppSpacing.xxl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.goNamed(AppRoutes.dashboard),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      '← Voltar',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    'PREÇO DE FUNDADOR',
                    style: AppTextStyles.baloo(
                      12,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Desbloqueie toda a\njornada de leitura',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(height: 1.25),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Benefit('Todos os 7 módulos até as histórias'),
              const SizedBox(height: AppSpacing.sm),
              const _Benefit('Biblioteca de livros desbloqueáveis'),
              const SizedBox(height: AppSpacing.sm),
              const _Benefit('Relatórios de progresso para os pais'),
              const SizedBox(height: AppSpacing.lg),
              for (final plan in founderPlans) ...[
                _PlanCard(
                  plan: plan,
                  selected: plan.id == _selectedPlanId,
                  onTap: () => setState(() => _selectedPlanId = plan.id),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.xs),
              LeleButton(
                label: !paymentsEnabled
                    ? 'Assinaturas em breve'
                    : needsEmailVerification
                    ? 'Confirme seu e-mail para continuar'
                    : _busy
                    ? 'Abrindo pagamento...'
                    : 'Começar teste grátis de 7 dias',
                fontSize: 19,
                color: AppColors.purple,
                shadowColor: AppColors.purpleDark,
                enabled: paymentsEnabled && !_busy,
                onPressed: _startCheckout,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Cancele quando quiser. O 1º módulo é sempre gratuito.',
                textAlign: TextAlign.center,
                style: AppTextStyles.nunito(
                  12,
                  color: AppColors.textFaint,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.md,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(AppRadius.bar),
          ),
          child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: selected ? AppColors.selectedFill : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: selected ? AppColors.orange : AppColors.border,
                width: 3,
              ),
            ),
            child: Row(
              spacing: AppSpacing.md,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppColors.orange
                          : AppColors.borderMuted,
                      width: 3,
                    ),
                  ),
                  child: selected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.orange,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subheading,
                      ),
                      Text(
                        plan.subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Capped rather than Flexible: alongside the Expanded above
                // it would take half the free space, use only as much as the
                // price needs, and leave the remainder as dead space after
                // it — which pushed the price 204px in from the card edge on
                // a tablet.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    plan.price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subheading.copyWith(
                      color: AppColors.orangeDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (plan.badge != null)
            Positioned(
              top: -11,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  plan.badge!,
                  style: AppTextStyles.micro.copyWith(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
