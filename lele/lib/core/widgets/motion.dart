import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Motion shared across the app.
///
/// These are the app's reusable animations, kept apart from the mascot they
/// used to live beside: a shake belongs to whatever is being shaken.
///
/// Everything here answers to the platform's reduce-motion setting. A child
/// who needs that setting still needs the feedback, so the rule is that
/// motion is dropped while colour, sound and haptics carry the message on
/// their own.
bool _reducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

extension MotionController on AnimationController {
  /// Starts or stops a looping decoration animation depending on the
  /// platform's reduce-motion setting.
  void syncLoopWithReducedMotion(BuildContext context, {bool reverse = false}) {
    if (_reducedMotion(context)) {
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
  const PulsingWidget({super.key, required this.child, this.scale = 1.05});

  final Widget child;

  /// How far the pulse swells. The default is the designed idle breath; a
  /// larger value is for something asking to be tapped.
  final double scale;

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
      scale: Tween(
        begin: 1.0,
        end: widget.scale,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
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

/// A "no, not that one" wobble.
///
/// Wider and longer than a form-field shake on purpose. This is the only
/// visual a pre-reader gets when they miss, so it swings far enough to be
/// unmistakable across a room and tilts as it goes, the way a head shakes
/// rather than the way a slider snaps.
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({
    super.key,
    required this.child,
    required this.trigger,
    this.amplitude = 13,
    this.tilt = 0.035,
  });

  final Widget child;

  /// Change this value to replay the shake.
  final Object? trigger;

  /// Peak horizontal travel, in logical pixels.
  final double amplitude;

  /// Peak rotation in radians. Zero keeps the motion purely lateral.
  final double tilt;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// Three full swings, decaying — a wobble that settles rather than
  /// stopping dead.
  static const _swings = 3;

  @override
  void didUpdateWidget(ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != null && widget.trigger != oldWidget.trigger) {
      if (_reducedMotion(context)) return;
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
        if (t == 0 || t == 1) return child!;
        // Damped sine: full swing at the start, nothing left at the end.
        final decay = math.pow(1 - t, 1.6).toDouble();
        final swing = math.sin(t * math.pi * 2 * _swings) * decay;
        return Transform.rotate(
          angle: widget.tilt * swing,
          child: Transform.translate(
            offset: Offset(widget.amplitude * swing, 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// One fleck thrown out by a [BurstOverlay].
class _Fleck {
  _Fleck(this.angle, this.distance, this.radius, this.color, this.delay);

  final double angle;
  final double distance;
  final double radius;
  final Color color;

  /// 0..0.3 — staggering the start stops the burst reading as one ring.
  final double delay;
}

/// Throws a short burst of colour out of the middle of [child].
///
/// The reward for a right answer used to be the tile turning green. This is
/// the other half: something that happens *to* the screen, so getting it
/// right feels like an event rather than a state change.
class BurstOverlay extends StatefulWidget {
  const BurstOverlay({
    super.key,
    required this.child,
    required this.trigger,
    required this.colors,
    this.flecks = 14,
  });

  final Widget child;

  /// Change this value to fire a burst.
  final Object? trigger;

  /// Palette the flecks are drawn from, cycled in order.
  final List<Color> colors;

  final int flecks;

  @override
  State<BurstOverlay> createState() => _BurstOverlayState();
}

class _BurstOverlayState extends State<BurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  List<_Fleck> _burst = const [];
  bool _fired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A trigger that is already set on the first build fires on arrival —
    // which is how a screen that exists to celebrate gets its burst without
    // having to fake a state change. A card whose trigger starts null is
    // unaffected.
    if (!_fired && widget.trigger != null) _fire();
  }

  @override
  void didUpdateWidget(BurstOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != null && widget.trigger != oldWidget.trigger) _fire();
  }

  void _fire() {
    if (_reducedMotion(context)) return;
    _fired = true;
    setState(() => _burst = _makeBurst());
    _controller.forward(from: 0);
  }

  List<_Fleck> _makeBurst() {
    // Seeded so a burst is reproducible in a test, jittered so two bursts
    // in a row do not look stamped from the same template.
    final random = math.Random(widget.trigger.hashCode);
    return [
      for (var i = 0; i < widget.flecks; i++)
        _Fleck(
          // Spread evenly, then nudged, so there are no bald patches.
          (i / widget.flecks) * 2 * math.pi +
              (random.nextDouble() - 0.5) * 0.45,
          0.55 + random.nextDouble() * 0.45,
          3 + random.nextDouble() * 4,
          widget.colors[i % widget.colors.length],
          random.nextDouble() * 0.3,
        ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        widget.child,
        // Never intercepts a tap: the child underneath stays answerable
        // while the burst is still in the air.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _BurstPainter(
                  progress: _controller.value,
                  flecks: _burst,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.flecks});

  final double progress;
  final List<_Fleck> flecks;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1 || flecks.isEmpty) return;

    final centre = size.center(Offset.zero);
    final reach = size.shortestSide * 0.9;

    for (final fleck in flecks) {
      // Each fleck runs its own clock, started late by its delay.
      final local = ((progress - fleck.delay) / (1 - fleck.delay)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0) continue;

      final eased = Curves.easeOutCubic.transform(local);
      final travel = reach * fleck.distance * eased;
      final offset = Offset(
        math.cos(fleck.angle) * travel,
        math.sin(fleck.angle) * travel,
      );
      // Fades over the back half, and shrinks as it fades.
      final fade = local < 0.5 ? 1.0 : 1 - (local - 0.5) * 2;

      canvas.drawCircle(
        centre + offset,
        fleck.radius * (0.4 + 0.6 * fade),
        Paint()..color = fleck.color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.flecks != flecks;
}

/// Counts up to [value] instead of snapping to it.
///
/// XP and coins are the part of the reward screen a child watches, so the
/// number climbing is the reward — arriving already-correct is not.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;
  final Duration duration;
  final Widget Function(BuildContext context, int value) builder;

  @override
  Widget build(BuildContext context) {
    if (_reducedMotion(context)) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => builder(context, current.round()),
    );
  }
}
