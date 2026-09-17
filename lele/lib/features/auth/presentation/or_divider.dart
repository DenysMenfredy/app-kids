import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// The "ou" rule between the form and the provider buttons.
///
/// Shared because both auth screens now offer the same providers, and two
/// copies of a divider is how two screens start looking subtly different.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.md,
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 2)),
        Text(
          'ou',
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textFaint,
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 2)),
      ],
    );
  }
}
