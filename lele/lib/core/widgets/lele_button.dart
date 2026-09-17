import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Chunky 3D button with a hard drop-shadow that presses down on touch,
/// matching the prototype's `box-shadow: 0 5px 0` + translateY(3px) effect.
class LeleButton extends StatefulWidget {
  const LeleButton({
    super.key,
    required this.onPressed,
    this.label,
    this.child,
    this.color = AppColors.orange,
    this.shadowColor = AppColors.orangeDark,
    this.textColor = Colors.white,
    this.height = 58,
    this.fontSize = 20,
    this.borderRadius = 22,
    this.enabled = true,
  }) : assert(label != null || child != null, 'Provide a label or a child');

  final VoidCallback? onPressed;
  final String? label;
  final Widget? child;
  final Color color;
  final Color shadowColor;
  final Color textColor;
  final double height;
  final double fontSize;
  final double borderRadius;
  final bool enabled;

  @override
  State<LeleButton> createState() => _LeleButtonState();
}

class _LeleButtonState extends State<LeleButton> {
  bool _pressed = false;

  static const _restDepth = 5.0;
  static const _pressedDepth = 2.0;

  @override
  Widget build(BuildContext context) {
    final depth = _pressed ? _pressedDepth : _restDepth;
    final offsetY = _pressed ? _restDepth - _pressedDepth : 0.0;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        child: Padding(
          padding: EdgeInsets.only(top: offsetY, bottom: _restDepth - offsetY),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            // A minimum rather than a fixed height: at a large text scale
            // the button grows instead of overflowing by two pixels.
            constraints: BoxConstraints(minHeight: widget.height),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(color: widget.shadowColor, offset: Offset(0, depth)),
              ],
            ),
            child:
                widget.child ??
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm,
                  ),
                  child: _ButtonLabel(
                    label: widget.label!,
                    fontSize: widget.fontSize,
                    color: widget.textColor,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// A button label that prefers one line, shrinks to fit, and stops shrinking
/// before it becomes unreadable.
///
/// Plain `Text` wrapped "Começar teste grátis de 7 dias" onto three lines at
/// a large text scale. A bare `FittedBox` fixed that by scaling the label to
/// a third of its size, which is worse — a 20pt call to action rendering at
/// about 6pt. So it scales down to [_minScale] and, only if that still does
/// not fit, uses a second line at that size.
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.label,
    required this.fontSize,
    required this.color,
  });

  final String label;
  final double fontSize;
  final Color color;

  /// Below this a label stops reading as a button and starts reading as fine
  /// print.
  static const _minScale = 0.78;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.baloo(
      fontSize,
      weight: FontWeight.w700,
      color: color,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout();

        final available = constraints.maxWidth;
        final natural = painter.width;
        final fits = natural <= available || !available.isFinite;
        final ratio = fits ? 1.0 : available / natural;

        if (ratio >= _minScale) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, softWrap: false, style: style),
          );
        }
        // Too long to shrink politely: two lines at the floor size.
        return Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontSize: fontSize * _minScale),
        );
      },
    );
  }
}
