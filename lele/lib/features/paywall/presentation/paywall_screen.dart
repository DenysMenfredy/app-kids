import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../data/subscription_service.dart';
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
    if (!AppConfig.useFirebase) {
      // Demo mode: no payments backend — keep the prototype behavior.
      context.goNamed(AppRoutes.dashboard);
      return;
    }
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(subscriptionServiceProvider)
          .createCheckoutSession(_backendPlanIds[_selectedPlanId]!);
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const CheckoutFailure('Não foi possível abrir o pagamento.');
      }
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.goNamed(AppRoutes.dashboard),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '← Voltar',
                      style: AppTextStyles.nunito(
                        15,
                        weight: FontWeight.w800,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 14),
              Text(
                'Desbloqueie toda a\njornada de leitura',
                textAlign: TextAlign.center,
                style: AppTextStyles.baloo(26, height: 1.25),
              ),
              const SizedBox(height: 14),
              const _Benefit('Todos os 7 módulos até as histórias'),
              const SizedBox(height: 8),
              const _Benefit('Biblioteca de livros desbloqueáveis'),
              const SizedBox(height: 8),
              const _Benefit('Relatórios de progresso para os pais'),
              const SizedBox(height: 16),
              for (final plan in founderPlans) ...[
                _PlanCard(
                  plan: plan,
                  selected: plan.id == _selectedPlanId,
                  onTap: () => setState(() => _selectedPlanId = plan.id),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 2),
              LeleButton(
                label: _busy
                    ? 'Abrindo pagamento...'
                    : 'Começar teste grátis de 7 dias',
                fontSize: 19,
                color: AppColors.purple,
                shadowColor: AppColors.purpleDark,
                enabled: !_busy,
                onPressed: _startCheckout,
              ),
              const SizedBox(height: 12),
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
      spacing: 10,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.nunito(14, weight: FontWeight.w700),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? AppColors.selectedFill : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.orange : AppColors.border,
                width: 3,
              ),
            ),
            child: Row(
              spacing: 12,
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
                      Text(plan.name, style: AppTextStyles.baloo(17)),
                      Text(
                        plan.subtitle,
                        style: AppTextStyles.nunito(
                          13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  plan.price,
                  style: AppTextStyles.baloo(18, color: AppColors.orangeDark),
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
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  plan.badge!,
                  style: AppTextStyles.baloo(11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
