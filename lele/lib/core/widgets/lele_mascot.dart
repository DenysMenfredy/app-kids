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
  });

  final double size;
  final Color color;
  final Color mouthColor;
  final bool withEars;
  final bool withShadow;

  @override
  Widget build(BuildContext context) {
    final s = size / 150;
    return SizedBox(
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

extension on AnimationController {
  /// Starts or stops a looping decoration animation depending on the
  /// platform's reduce-motion setting.
  void syncLoopWithReducedMotion(BuildContext context,
      {bool reverse = false}) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      stop();
      value = 0;
    } else if (!isAnimating) {
      repeat(reverse: reverse);
    }
  }
}

/// Gentle vertical float, mirroring the `lele-float` keyframes.
class FloatingWidget extends StatefulWidget {
  const FloatingWidget({super.key, required this.child, this.offset = 10});

  final Widget child;
  final double offset;

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.syncLoopWithReducedMotion(context, reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          -widget.offset * Curves.easeInOut.transform(_controller.value),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Slow scale pulse, mirroring the `lele-pulse` keyframes.
class PulsingWidget extends StatefulWidget {
  const PulsingWidget({super.key, required this.child});

  final Widget child;

  @override
  State<PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<PulsingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.syncLoopWithReducedMotion(context, reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// Pop-in entrance, mirroring the `lele-pop` keyframes.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child});

  final Widget child;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.4),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Horizontal shake for wrong answers, mirroring the `lele-shake` keyframes.
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({super.key, required this.child, required this.trigger});

  final Widget child;

  /// Change this value to replay the shake.
  final Object? trigger;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != null && widget.trigger != oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 0 → -7px at 25% → +7px at 75% → 0
        final dx = t == 0 || t == 1
            ? 0.0
            : -7 * _wave(t, 0.25) + 7 * _wave(t, 0.75);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }

  double _wave(double t, double center) {
    final d = (t - center).abs();
    return d > 0.25 ? 0 : 1 - d / 0.25;
  }
}
