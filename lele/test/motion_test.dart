import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/theme/app_colors.dart';
import 'package:lele/core/widgets/motion.dart';

/// Mounts [child], optionally telling the app the viewer has asked the
/// platform to keep motion to a minimum.
Future<void> pumpMotion(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    ),
  );
}

const _childKey = Key('shaken');

Widget shakeWith(Object? trigger, {bool reduceMotion = false}) => ShakeWidget(
  trigger: trigger,
  child: const SizedBox(key: _childKey, width: 60, height: 60),
);

void main() {
  group('ShakeWidget', () {
    testWidgets('moves the child when the trigger changes', (tester) async {
      await pumpMotion(tester, shakeWith(1));
      final atRest = tester.getTopLeft(find.byKey(_childKey));

      await pumpMotion(tester, shakeWith(2));
      await tester.pump(const Duration(milliseconds: 90));

      expect(
        tester.getTopLeft(find.byKey(_childKey)),
        isNot(atRest),
        reason: 'a miss has to be visible, not just audible',
      );

      // And settles back exactly where it started.
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(_childKey)), atRest);
    });

    testWidgets('swings wide enough to read across a room', (tester) async {
      await pumpMotion(tester, shakeWith(1));
      final atRest = tester.getTopLeft(find.byKey(_childKey));

      await pumpMotion(tester, shakeWith(2));
      var furthest = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        final dx = (tester.getTopLeft(find.byKey(_childKey)).dx - atRest.dx)
            .abs();
        if (dx > furthest) furthest = dx;
      }
      expect(furthest, greaterThan(8));
      await tester.pumpAndSettle();
    });

    testWidgets('stays still when the viewer asked for less motion', (
      tester,
    ) async {
      await pumpMotion(tester, shakeWith(1), reduceMotion: true);
      final atRest = tester.getTopLeft(find.byKey(_childKey));

      await pumpMotion(tester, shakeWith(2), reduceMotion: true);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.getTopLeft(find.byKey(_childKey)), atRest);
      }
    });
  });

  group('BurstOverlay', () {
    Widget burstWith(Object? trigger, {required VoidCallback onTap}) =>
        BurstOverlay(
          trigger: trigger,
          colors: AppColors.celebration,
          child: GestureDetector(
            onTap: onTap,
            // Opaque because the real tiles underneath a burst are painted
            // containers; a bare SizedBox has no hit area of its own.
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(key: _childKey, width: 80, height: 80),
          ),
        );

    testWidgets('runs an animation when fired', (tester) async {
      var taps = 0;
      await pumpMotion(tester, burstWith(null, onTap: () => taps++));
      await tester.pumpAndSettle();

      await pumpMotion(tester, burstWith('A', onTap: () => taps++));
      await tester.pump();
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'the burst should be in flight',
      );
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('never swallows a tap meant for the card underneath', (
      tester,
    ) async {
      var taps = 0;
      await pumpMotion(tester, burstWith(null, onTap: () => taps++));
      await pumpMotion(tester, burstWith('A', onTap: () => taps++));
      await tester.pump(const Duration(milliseconds: 100));

      // Mid-burst, the child is still the thing being tapped.
      await tester.tap(find.byKey(_childKey));
      expect(taps, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('fires on arrival when the trigger is already set', (
      tester,
    ) async {
      // How the reward screen celebrates: nothing changes, the screen just
      // appears.
      await pumpMotion(tester, burstWith('reward', onTap: () {}));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('an arrival burst is skipped under reduced motion', (
      tester,
    ) async {
      await pumpMotion(
        tester,
        burstWith('reward', onTap: () {}),
        reduceMotion: true,
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('does not fire when the viewer asked for less motion', (
      tester,
    ) async {
      await pumpMotion(
        tester,
        burstWith(null, onTap: () {}),
        reduceMotion: true,
      );
      await tester.pumpAndSettle();

      await pumpMotion(
        tester,
        burstWith('A', onTap: () {}),
        reduceMotion: true,
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('CountUp', () {
    Widget counter(int value, {Duration? duration}) => CountUp(
      value: value,
      duration: duration ?? const Duration(milliseconds: 600),
      builder: (context, current) => Text('$current'),
    );

    testWidgets('climbs to the value instead of arriving at it', (
      tester,
    ) async {
      await pumpMotion(tester, counter(50));
      expect(find.text('0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      final midway = int.parse(tester.widget<Text>(find.byType(Text)).data!);
      expect(midway, greaterThan(0));
      expect(midway, lessThan(50));

      await tester.pumpAndSettle();
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('arrives immediately when the viewer asked for less motion', (
      tester,
    ) async {
      await pumpMotion(tester, counter(50), reduceMotion: true);
      expect(
        find.text('50'),
        findsOneWidget,
        reason: 'the number still has to be right, just not animated',
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
