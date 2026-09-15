import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
            height: widget.height,
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
                Text(
                  widget.label!,
                  style: TextStyle(
                    fontFamily: 'Baloo 2',
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w700,
                    color: widget.textColor,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
