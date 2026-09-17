import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/lesson.dart';

/// An activity instruction with its letter drawn in the accent colour —
/// "Toque na letra **B**", "Trace a letra **L** com o dedo".
class HighlightedInstruction extends StatelessWidget {
  const HighlightedInstruction({
    super.key,
    required this.instruction,
    required this.token,
  });

  final String instruction;
  final String token;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.heading;
    final parts = highlightSplit(instruction, token);
    if (parts == null) {
      return Text(instruction, textAlign: TextAlign.center, style: style);
    }
    return Text.rich(
      TextSpan(
        text: parts.before,
        style: style,
        children: [
          TextSpan(
            text: token,
            style: AppTextStyles.heading.copyWith(color: AppColors.orangeDark),
          ),
          TextSpan(text: parts.after, style: style),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
