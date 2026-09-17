import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// The small rounded square that closes, goes back, or opens a menu.
///
/// Six screens each drew their own: a [GestureDetector] around a 36–40dp
/// [Container] with a panel fill and an icon. Two problems came with the
/// copy-paste. Every one of them was below the 48dp minimum touch target —
/// on a raw [GestureDetector] nothing supplies the padding a Material
/// button would — and none but the dashboard's carried a semantic label, so
/// a screen reader announced the child's way out of a lesson as nothing at
/// all.
///
/// The drawn size is unchanged. [AppSpacing.minTapTarget] is applied to the
/// touch area around it, which is the part a child has to hit.
///
/// Where the button sits against a margin, pass [alignment] so the grown
/// touch area extends inward only. Centring it there leaves the painted box
/// a few pixels short of the edge, visibly out of line with the cards below
/// — the tap target must not be what decides where the button is drawn.
class LeleIconButton extends StatelessWidget {
  const LeleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 40,
    this.iconSize = 22,
    this.background = AppColors.panel,
    this.foreground = AppColors.textMuted,
    this.borderRadius = AppRadius.control,
    this.alignment = Alignment.center,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Announced by screen readers. Required: every control on a screen a
  /// child navigates alone needs to say what it does.
  final String semanticLabel;

  /// The size of the visible square, which may be smaller than the target.
  final double size;

  final double iconSize;
  final Color background;
  final Color foreground;
  final double borderRadius;

  /// Where the painted box sits inside the touch target. Use
  /// [Alignment.centerLeft] or [Alignment.centerRight] for a button against
  /// a screen margin, so it lines up with the content below it.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final target = math.max(size, AppSpacing.minTapTarget);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: GestureDetector(
        // Opaque so the whole target responds, not just the painted square.
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: target,
          height: target,
          child: Align(
            alignment: alignment,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Icon(icon, size: iconSize, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
