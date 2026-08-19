import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/activity_scaffold.dart';
import '../../../../core/widgets/lele_button.dart';
import '../../application/lesson_controller.dart';
import '../../domain/lesson.dart';

const _letter = 'A';

class TraceActivityScreen extends ConsumerStatefulWidget {
  const TraceActivityScreen({super.key});

  @override
  ConsumerState<TraceActivityScreen> createState() =>
      _TraceActivityScreenState();
}

class _TraceActivityScreenState extends ConsumerState<TraceActivityScreen> {
  final List<List<Offset>> _strokes = [];

  bool get _hasTraced => _strokes.isNotEmpty;

  void _startStroke(Offset point) {
    setState(() => _strokes.add([point]));
  }

  void _extendStroke(Offset point) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(point));
  }

  void _clear() => setState(_strokes.clear);

  void _finish() {
    if (!_hasTraced) return;
    ref.read(ttsServiceProvider).speak('Que capricho!');
    context.goNamed(
      ref.read(lessonFlowProvider).nextRoute(ActivityType.trace),
    );
    Future.delayed(const Duration(milliseconds: 700), () {
      ref.read(ttsServiceProvider).speak('bola');
    });
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(lessonFlowProvider);
    return ActivityScaffold(
      progress: flow.progressOf(ActivityType.trace),
      onClose: () => context.goNamed(AppRoutes.childHome),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Text.rich(
            TextSpan(
              text: 'Trace a letra ',
              style: AppTextStyles.baloo(23),
              children: [
                TextSpan(
                  text: _letter,
                  style: AppTextStyles.baloo(23, color: AppColors.orangeDark),
                ),
                TextSpan(
                  text: ' com o dedo',
                  style: AppTextStyles.baloo(23),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 280,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.border,
                    width: 3,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          _letter,
                          style: TextStyle(
                            fontFamily: 'Baloo 2',
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
                        child: GestureDetector(
                          onPanStart: (d) => _startStroke(d.localPosition),
                          onPanUpdate: (d) => _extendStroke(d.localPosition),
                          child: CustomPaint(
                            painter: _TracePainter(strokes: _strokes),
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
            spacing: 12,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _clear,
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 3),
                    ),
                    child: Text(
                      'Limpar',
                      style: AppTextStyles.baloo(
                        18,
                        weight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: LeleButton(
                  label: 'Pronto!',
                  height: 56,
                  fontSize: 19,
                  borderRadius: 20,
                  color: _hasTraced ? AppColors.teal : AppColors.borderMuted,
                  shadowColor:
                      _hasTraced ? AppColors.tealDark : AppColors.textDisabled,
                  enabled: _hasTraced,
                  onPressed: _finish,
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
