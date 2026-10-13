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
import '../../../../core/widgets/motion.dart';
import '../../application/lesson_content_provider.dart';
import '../../application/lesson_controller.dart';
import '../../application/lesson_session_controller.dart';
import '../../application/lesson_stats_controller.dart';
import '../../domain/lesson.dart';

class MatchActivityScreen extends ConsumerStatefulWidget {
  const MatchActivityScreen({super.key});

  @override
  ConsumerState<MatchActivityScreen> createState() =>
      _MatchActivityScreenState();
}

class _MatchActivityScreenState extends ConsumerState<MatchActivityScreen> {
  String? _selected;
  final Set<String> _matched = {};
  String? _wrong;
  int _wrongAttempts = 0;
  bool _done = false;
  bool _saving = false;
  bool _restored = false;

  void _onUppercaseTap(String letter) {
    if (_saving || _done || _matched.contains(letter)) return;
    ref.read(ttsServiceProvider).speak(letter);
    setState(() => _selected = letter);
  }

  Future<void> _onLowercaseTap(MatchActivity activity, String letter) async {
    final upper = letter.toUpperCase();
    if (_saving || _done || _matched.contains(upper) || _selected == null) {
      return;
    }
    final selected = _selected!;
    setState(() => _saving = true);
    final saved = await ref.read(lessonSessionProvider).recordAttempt(
      activity.id,
      {'upper': selected, 'lower': letter},
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível guardar sua resposta. Tente novamente.',
          ),
        ),
      );
      return;
    }
    if (upper == selected) {
      final all = _matched.length + 1 == activity.uppercase.length;
      ref.read(lessonStatsProvider.notifier).recordCorrect();
      unawaited(
        ref
            .read(feedbackServiceProvider)
            .play(all ? FeedbackCue.celebrate : FeedbackCue.correct),
      );
      unawaited(
        ref.read(ttsServiceProvider).speak(all ? 'Incrível!' : 'Isso!'),
      );
      setState(() {
        _matched.add(upper);
        _selected = null;
        _done = all;
      });
      if (all) {
        Future.delayed(const Duration(milliseconds: 1100), () {
          if (mounted) {
            context.goNamed(
              ref.read(lessonFlowProvider).nextRoute(ActivityType.match),
            );
          }
        });
      }
    } else {
      ref.read(lessonStatsProvider.notifier).recordWrong();
      // This activity said nothing at all on a wrong pair before.
      unawaited(ref.read(feedbackServiceProvider).play(FeedbackCue.wrong));
      setState(() {
        _wrong = letter;
        _wrongAttempts++;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrong = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(currentLessonContentProvider).value;
    if (content == null) return const ActivityLoading();
    final activity = content.match;
    if (!_restored) {
      _matched.addAll(
        ref.read(lessonRunProvider)?.completedItems[activity.id] ??
            const <String>{},
      );
      _restored = true;
    }
    final flow = ref.watch(lessonFlowProvider);
    return ActivityScaffold(
      progress: flow.progressOf(ActivityType.match),
      onClose: () => context.goNamed(AppRoutes.childHome),
      message: _done
          ? 'Incrível! ★'
          : _selected != null
          ? 'Agora toque na letra "${_selected!.toLowerCase()}"'
          : 'Toque numa letra grande',
      messageColor: _done ? AppColors.green : AppColors.textFaint,
      scrollableContent: true,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(activity.instruction, style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.xs),
          Text(
            activity.hint,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: AppSpacing.xxl,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpacing.lg,
                  children: [
                    for (final letter in activity.uppercase)
                      _MatchCard(
                        letter: letter,
                        color: AppColors.orangeDark,
                        matched: _matched.contains(letter),
                        selected: _selected == letter,
                        wrong: false,
                        wrongAttempts: 0,
                        onTap: () => _onUppercaseTap(letter),
                      ),
                  ],
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpacing.lg,
                  children: [
                    for (final letter in activity.lowercase)
                      _MatchCard(
                        letter: letter,
                        color: AppColors.teal,
                        matched: _matched.contains(letter.toUpperCase()),
                        selected: false,
                        wrong: _wrong == letter,
                        wrongAttempts: _wrongAttempts,
                        onTap: () => _onLowercaseTap(activity, letter),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.letter,
    required this.color,
    required this.matched,
    required this.selected,
    required this.wrong,
    required this.wrongAttempts,
    required this.onTap,
  });

  final String letter;
  final Color color;
  final bool matched;
  final bool selected;
  final bool wrong;
  final int wrongAttempts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = matched
        ? AppColors.greenPale
        : selected
        ? AppColors.orange
        : AppColors.surface;
    final borderColor = matched
        ? AppColors.greenBorder
        : selected
        ? AppColors.orangeDark
        : wrong
        ? AppColors.red
        : AppColors.border;
    final textColor = matched
        ? AppColors.greenMuted
        : selected
        ? Colors.white
        : wrong
        ? AppColors.red
        : color;

    return Semantics(
      button: true,
      selected: selected || matched,
      label: 'Letra $letter',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: BurstOverlay(
          trigger: matched ? letter : null,
          colors: AppColors.celebration,
          flecks: 10,
          child: ShakeWidget(
            trigger: wrong ? wrongAttempts : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: matched ? 0.7 : 1,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: selected ? 1.06 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 96,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: borderColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: matched
                            ? AppColors.greenBorder
                            : selected
                            ? AppColors.orangeDark
                            : AppColors.border,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    letter,
                    style: AppTextStyles.display.copyWith(color: textColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
