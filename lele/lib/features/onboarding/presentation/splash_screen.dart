import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_mascot.dart';
import '../../../core/widgets/motion.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.orangeBright, AppColors.orange],
          ),
        ),
        child: SafeArea(
          child: AdaptivePage(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FloatingWidget(
                  child: LeleMascot(
                    semanticLabel: 'O mascote Lelê',
                    size: 150,
                    withEars: true,
                    withShadow: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Lelê',
                  style: AppTextStyles.baloo(
                    46,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Aprender a ler brincando',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.orangePale,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const _ShapeStrip(),
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(
                  width: double.infinity,
                  child: LeleButton(
                    label: 'Começar',
                    color: Colors.white,
                    shadowColor: Colors.black26,
                    textColor: AppColors.orangeDark,
                    onPressed: () => context.goNamed(AppRoutes.welcome),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapeStrip extends StatelessWidget {
  const _ShapeStrip();

  @override
  Widget build(BuildContext context) {
    Widget shape(Color color, {bool round = false, double angle = 0}) {
      return Transform.rotate(
        angle: angle,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(round ? 7 : 5),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        shape(AppColors.yellow, angle: 0.17),
        shape(AppColors.teal, round: true),
        shape(AppColors.purple, angle: -0.21),
      ],
    );
  }
}
