import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale: 'Baloo 2' for display/headings/buttons,
/// 'Nunito' for body copy — mirroring the design handoff.
///
/// Prefer the named steps below to the [baloo] and [nunito] factories. The
/// factories stay for one-off cases, but reaching for them with a literal
/// size is how the scale drifted in the first place: sixteen distinct Baloo
/// sizes between 10 and 42, several a single pixel apart on elements doing
/// the same job. Each step here is one of those clusters.
///
/// Override colour and line height with `copyWith`:
///
/// ```dart
/// Text(label, style: AppTextStyles.heading.copyWith(color: AppColors.orangeDark))
/// ```
abstract final class AppTextStyles {
  /// Exposed for the one case that cannot use the factories: a stroked
  /// glyph, which needs `foreground` and so must leave `color` unset.
  static const balooFamily = 'Baloo 2';

  static const _baloo = balooFamily;
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

  // --- Baloo: display, headings, buttons -------------------------------

  /// A single letter or word held up on its own — the answer tile in the
  /// match activity.
  static TextStyle get display => baloo(42);

  /// The one celebratory line on a screen that exists to celebrate.
  static TextStyle get headline => baloo(32);

  /// Screen titles, e.g. "Que bom te ver!" / "Criar conta".
  static TextStyle get screenTitle => baloo(30);

  /// The lead line of a screen that already has chrome above it.
  static TextStyle get title => baloo(27, height: 1.25);

  /// Activity instructions and card titles.
  static TextStyle get heading => baloo(23);

  /// Emphasised answers and inline call-outs.
  static TextStyle get subheading => baloo(18);

  /// Section headings inside a screen.
  static TextStyle get sectionTitle => baloo(16);

  /// Numbers in stat pills.
  static TextStyle get statValue => baloo(15);

  /// Badges sitting on top of artwork.
  static TextStyle get micro => baloo(11);

  // --- Baloo: the thing the child is actually reading ------------------
  //
  // Sized by what has to fit on the tile rather than by the heading scale
  // above, which is why these are their own steps.

  /// A single letter on a tap-to-answer tile.
  static TextStyle get letterGlyph => baloo(56);

  /// A whole word on a choice card, spaced out so the letters read singly.
  static TextStyle get wordGlyph => baloo(28, letterSpacing: 3.4);

  // --- Nunito: body copy ------------------------------------------------

  /// Input text and the default reading size.
  static TextStyle get body => nunito(16);

  /// Muted body copy under titles.
  static TextStyle get subtitle =>
      nunito(15, color: AppColors.textMuted, height: 1.5);

  /// Secondary copy: helper lines, captions, footnotes.
  static TextStyle get bodySmall => nunito(15);

  /// Small uppercase eyebrow labels.
  static TextStyle eyebrow(Color color) =>
      nunito(13, weight: FontWeight.w700, color: color, letterSpacing: 0.7);
}
