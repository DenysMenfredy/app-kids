import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/audio/feedback_cues.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/activity_scaffold.dart';
import '../../../../core/widgets/lele_button.dart';
import '../../application/lesson_content_provider.dart';
import '../../application/lesson_controller.dart';
import '../../application/lesson_session_controller.dart';
import '../../application/lesson_stats_controller.dart';
import '../../domain/lesson.dart';
import '../widgets/highlighted_instruction.dart';

class TraceActivityScreen extends ConsumerStatefulWidget {
  const TraceActivityScreen({super.key});

  @override
  ConsumerState<TraceActivityScreen> createState() =>
      _TraceActivityScreenState();
}

class _TraceActivityScreenState extends ConsumerState<TraceActivityScreen> {
  final List<List<Offset>> _strokes = [];
  DateTime? _strokeStartedAt;
  bool _finishing = false;

  int get _pointCount =>
      _strokes.fold(0, (total, stroke) => total + stroke.length);

  bool get _hasTraced => _pointCount >= 2;

  void _startStroke(Offset point) {
    _strokeStartedAt ??= DateTime.now();
    setState(() => _strokes.add([point]));
  }

  void _extendStroke(Offset point) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(point));
  }

  void _clear() => setState(() {
    _strokes.clear();
    _strokeStartedAt = null;
  });

  Future<void> _finish(LessonContent content) async {
    if (!_hasTraced || _finishing) return;
    setState(() => _finishing = true);
    final elapsed = _strokeStartedAt == null
        ? 100
        : DateTime.now().difference(_strokeStartedAt!).inMilliseconds;
    final saved = await ref
        .read(lessonSessionProvider)
        .recordAttempt(content.trace.id, {
          'strokeCount': _strokes.length.clamp(1, 20),
          'pointCount': _pointCount.clamp(2, 1000),
          'durationMillis': elapsed.clamp(100, 120000).toInt(),
        });
    if (!mounted) return;
    if (!saved) {
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível guardar seu desenho. Tente novamente.',
          ),
        ),
      );
      return;
    }
    ref.read(lessonStatsProvider.notifier).recordCorrect();
    // Captured before navigating: this screen is disposed by the time the
    // timer below fires, and reading from `ref` after that throws, which
    // silently cost the child the hand-off cue.
    final tts = ref.read(ttsServiceProvider);
    unawaited(ref.read(feedbackServiceProvider).play(FeedbackCue.correct));
    unawaited(tts.speak('Que capricho!'));
    context.goNamed(ref.read(lessonFlowProvider).nextRoute(ActivityType.trace));
    // Hand off to the next activity by speaking its word.
    Future.delayed(const Duration(milliseconds: 700), () {
      tts.speak(content.listen.speech);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(currentLessonContentProvider).value;
    if (content == null) return const ActivityLoading();
    final activity = content.trace;
    final flow = ref.watch(lessonFlowProvider);
    return ActivityScaffold(
      progress: flow.progressOf(ActivityType.trace),
      onClose: () => context.goNamed(AppRoutes.childHome),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          HighlightedInstruction(
            instruction: activity.instruction,
            token: activity.letter,
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 280,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  border: Border.all(
                    color: AppColors.border,
                    width: 3,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          activity.letter,
                          // Not AppTextStyles: a stroked glyph needs
                          // `foreground`, and TextStyle asserts that
                          // `color` is null when it is set.
                          style: TextStyle(
                            fontFamily: AppTextStyles.balooFamily,
                            fontSize: 240,
                            fontWeight: FontWeight.w800,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 4
                              ..color = AppColors.border,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Semantics(
                          label:
                              'Área de desenho. Cubra a letra '
                              '${activity.letter} com o dedo.',
                          child: GestureDetector(
                            onPanStart: (d) => _startStroke(d.localPosition),
                            onPanUpdate: (d) => _extendStroke(d.localPosition),
                            child: CustomPaint(
                              painter: _TracePainter(strokes: _strokes),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Limpar o desenho',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: _clear,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.border, width: 3),
                      ),
                      child: Text(
                        'Limpar',
                        style: AppTextStyles.subheading.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: LeleButton(
                  label: _finishing ? 'Guardando...' : 'Pronto!',
                  height: 56,
                  fontSize: 19,
                  borderRadius: 20,
                  color: _hasTraced ? AppColors.teal : AppColors.borderMuted,
                  shadowColor: _hasTraced
                      ? AppColors.tealDark
                      : AppColors.textDisabled,
                  enabled: _hasTraced && !_finishing,
                  onPressed: () => _finish(content),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 8, Paint()..color = AppColors.orange);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) => true;
}
