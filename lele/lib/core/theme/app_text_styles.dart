import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale: 'Baloo 2' for display/headings/buttons,
/// 'Nunito' for body copy — mirroring the design handoff.
abstract final class AppTextStyles {
  static const _baloo = 'Baloo 2';
  static const _nunito = 'Nunito';

  static TextStyle baloo(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.textDark,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: _baloo,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle nunito(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.textDark,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: _nunito,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Screen titles, e.g. "Que bom te ver!" / "Criar conta".
  static TextStyle get screenTitle => baloo(30);

  /// Section headings inside a screen.
  static TextStyle get sectionTitle => baloo(16);

  /// Muted body copy under titles.
  static TextStyle get subtitle =>
      nunito(15, color: AppColors.textMuted, height: 1.5);

  /// Small uppercase eyebrow labels.
  static TextStyle eyebrow(Color color) =>
      nunito(13, weight: FontWeight.w700, color: color, letterSpacing: 0.7);
}
