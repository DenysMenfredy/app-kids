import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Lelê mascot face: a round body with white eyes, dark pupils, a smiling
/// mouth and optional ears. All positions scale from the 150px reference
/// design so the mascot can render at any size.
class LeleMascot extends StatelessWidget {
  const LeleMascot({
    super.key,
    required this.size,
    this.color = AppColors.mascotCream,
    this.mouthColor = AppColors.mouthBrown,
    this.withEars = false,
    this.withShadow = false,
    this.semanticLabel,
  });

  final double size;
  final Color color;
  final Color mouthColor;
  final bool withEars;
  final bool withShadow;

  /// Set where the mascot carries meaning rather than decorating — the
  /// splash and the reward screen, where it is the only thing on screen.
  /// Left null the face is drawn from bare [Container]s and reaches a
  /// screen reader as nothing, which is the right outcome for a border
  /// ornament.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = size / 150;
    final face = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (withEars) ...[
            _ear(left: 22 * s, s: s),
            _ear(right: 22 * s, s: s),
          ],
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: withShadow
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        offset: Offset(0, 8 * s),
                      ),
                    ]
                  : null,
            ),
          ),
          _eye(left: 36 * s, s: s),
          _eye(right: 36 * s, s: s),
          Positioned(
            top: 92 * s,
            left: 57 * s,
            child: Container(
              width: 36 * s,
              height: 18 * s,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: mouthColor, width: 4 * s),
                  right: BorderSide(color: mouthColor, width: 4 * s),
                  bottom: BorderSide(color: mouthColor, width: 4 * s),
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(36 * s),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (semanticLabel == null) return face;
    return Semantics(image: true, label: semanticLabel, child: face);
  }

  Widget _ear({double? left, double? right, required double s}) {
    return Positioned(
      top: -14 * s,
      left: left,
      right: right,
      child: Container(
        width: 34 * s,
        height: 34 * s,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _eye({double? left, double? right, required double s}) {
    return Positioned(
      top: 48 * s,
      left: left,
      right: right,
      child: Container(
        width: 26 * s,
        height: 26 * s,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 12 * s,
          height: 12 * s,
          decoration: const BoxDecoration(
            color: AppColors.textDark,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
