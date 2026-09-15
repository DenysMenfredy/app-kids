import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_mascot.dart';
import '../../lesson/data/lesson_sync_service.dart';
import '../../session/application/child_provider.dart';
import '../../session/application/progress_provider.dart';
import '../../session/domain/child_profile.dart';

class RewardScreen extends ConsumerWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childProvider);
    final progress = ref.watch(progressProvider);
    // What the backend actually granted. Null means the call is still in
    // flight or didn't land; the standard reward is the honest default.
    final reward = ref.watch(lastLessonRewardProvider);
    final xpEarned = reward?.xpEarned ?? LessonReward.demo.xpEarned;
    final coinsEarned = reward?.coinsEarned ?? LessonReward.demo.coinsEarned;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cream, Color(0xFFFFF0DE)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _ConfettiLayer()),
            SafeArea(
              child: AdaptivePage(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: PopIn(
                        child: LeleMascot(
                          size: 130,
                          color: child.avatar.color,
                          mouthColor: child.avatar.mouthColor,
                          withEars: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Parabéns, ${child.name}!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.baloo(32),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Você completou a lição de hoje',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.nunito(
                        16,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 12,
                      children: [
                        // An equal share each, so the three tiles shrink
                        // together rather than pushing the last one off.
                        Expanded(
                          child: _RewardStat(
                            value: '+$xpEarned',
                            label: '★ XP',
                            color: AppColors.purple,
                          ),
                        ),
                        Expanded(
                          child: _RewardStat(
                            value: '+$coinsEarned',
                            label: 'moedas',
                            color: AppColors.yellowDark,
                          ),
                        ),
                        Expanded(
                          child: _RewardStat(
                            value: '⚡ ${progress.streak}',
                            label: 'dias',
                            color: AppColors.orangeDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _UnlockedBookBanner(
                      onTap: () => context.goNamed(AppRoutes.books),
                    ),
                    const SizedBox(height: 16),
                    LeleButton(
                      label: 'Continuar',
                      onPressed: () => context.goNamed(AppRoutes.childHome),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardStat extends StatelessWidget {
  const _RewardStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.baloo(24, color: color)),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.nunito(
              12,
              weight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockedBookBanner extends StatelessWidget {
  const _UnlockedBookBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.purplePale,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.purpleBorder, width: 2),
        ),
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 36,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.purple, AppColors.purpleBright],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                border: Border(
                  left: BorderSide(color: AppColors.purpleDark, width: 5),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Novo livro desbloqueado!',
                    style: AppTextStyles.baloo(15, color: AppColors.purpleDark),
                  ),
                  Text(
                    '"O Sapo Bocudo" te espera',
                    style: AppTextStyles.nunito(
                      12,
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 26,
              color: AppColors.purple,
            ),
          ],
        ),
      ),
    );
  }
}

/// Falling confetti, mirroring the CSS `lele-fall` animation.
class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer();

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiPiece {
  _ConfettiPiece(int i)
    : x = (4 + (i * 6.7) % 92) / 100,
      size = 8.0 + (i % 3) * 4,
      color = _colors[i % _colors.length],
      isCircle = i.isOdd,
      duration = 2.6 + (i % 4) * 0.5,
      delay = i * 0.23;

  static const _colors = [
    AppColors.orange,
    AppColors.teal,
    AppColors.purple,
    AppColors.yellow,
    AppColors.red,
  ];

  final double x;
  final double size;
  final Color color;
  final bool isCircle;
  final double duration;
  final double delay;
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  static final _pieces = List.generate(14, _ConfettiPiece.new);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(
            pieces: _pieces,
            elapsedSeconds: _controller.value * 60,
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.pieces, required this.elapsedSeconds});

  final List<_ConfettiPiece> pieces;
  final double elapsedSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final local = elapsedSeconds - piece.delay;
      if (local < 0) continue;
      final t = (local % piece.duration) / piece.duration;
      final y = -40 + t * (size.height + 100);
      final opacity = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()..color = piece.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(piece.x * size.width, y);
      canvas.rotate(t * 3 * math.pi);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: piece.size,
        height: piece.size,
      );
      if (piece.isCircle) {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.elapsedSeconds != elapsedSeconds;
}
