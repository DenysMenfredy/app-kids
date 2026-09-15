import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Rounded input with the design's cream border that turns orange on focus.
class LeleTextField extends StatelessWidget {
  const LeleTextField({
    super.key,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.errorText,
    this.suffixIcon,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
  });

  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  /// Shown under the field, in place of the usual border colour.
  final String? errorText;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      enabled: enabled,
      focusNode: focusNode,
      style: AppTextStyles.nunito(16, weight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.nunito(
          16,
          weight: FontWeight.w700,
          color: AppColors.textFaint,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        suffixIcon: suffixIcon,
        errorText: errorText,
        errorStyle: AppTextStyles.nunito(
          13,
          weight: FontWeight.w700,
          color: AppColors.red,
        ),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.orange),
        errorBorder: _border(AppColors.red),
        focusedErrorBorder: _border(AppColors.red),
      ),
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: 2),
    );
  }
}
