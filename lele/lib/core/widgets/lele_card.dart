import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A white panel with a soft border — the app's default container for a
/// group of related content.
///
/// The same decoration was rebuilt roughly a dozen times across seven
/// screens, each picking its own corner radius, so cards that sit next to
/// each other in the same column did not quite match.
class LeleCard extends StatelessWidget {
  const LeleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.borderWidth = 2,
    this.borderRadius = AppRadius.card,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  /// Set to `null` for a fill with no outline.
  final Color? borderColor;

  /// 2 everywhere the parent is reading; 3 on the play surfaces a child
  /// touches, where the outline is part of the toy.
  final double borderWidth;

  final double borderRadius;

  /// When set, the whole card becomes one tap target.
  final VoidCallback? onTap;

  /// Announced in place of the card's contents when it is tappable.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      ),
    );
  }
}
