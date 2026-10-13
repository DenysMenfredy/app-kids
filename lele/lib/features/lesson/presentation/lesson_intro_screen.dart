import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_icon_button.dart';
import '../../learning/application/journey_provider.dart';
import '../application/lesson_content_provider.dart';
import '../application/lesson_controller.dart';
import '../application/lesson_session_controller.dart';
import '../domain/lesson.dart';
import 'activity_presentation.dart';

class LessonIntroScreen extends ConsumerStatefulWidget {
  const LessonIntroScreen({super.key});

  @override
  ConsumerState<LessonIntroScreen> createState() => _LessonIntroScreenState();
}

class _LessonIntroScreenState extends ConsumerState<LessonIntroScreen> {
  @override
  void initState() {
    super.initState();
    // A new run must reauthorize content online, not reuse a previous run's
    // protected payload after access expired or the publisher edited it.
    ref.invalidate(pendingLessonProvider);
    ref.invalidate(lessonIntroContentProvider);
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(lessonIntroContentProvider);
    return Scaffold(
      body: SafeArea(
        child: AdaptiveWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.md,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: LeleIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => context.goNamed(AppRoutes.childHome),
                    semanticLabel: 'Sair da lição',
                    alignment: Alignment.centerLeft,
                  ),
                ),
                Expanded(
                  child: content.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    ),
                    error: (error, _) => _LoadFailed(
                      onRetry: () => ref.invalidate(lessonIntroContentProvider),
                      onDiscard: ref.watch(pendingLessonProvider).value == null
                          ? null
                          : () async {
                              final discarded = await ref
                                  .read(lessonSessionProvider)
                                  .discardPending();
                              if (mounted) {
                                if (discarded) {
                                  ref.invalidate(pendingLessonProvider);
                                  ref.invalidate(lessonIntroContentProvider);
                                } else {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Não foi possível reiniciar. Tente novamente.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                    data: (data) => _Lesson(
                      lesson: data.lesson,
                      hasPending: data.pending != null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Lesson extends ConsumerStatefulWidget {
  const _Lesson({required this.lesson, required this.hasPending});

  final LessonContent lesson;
  final bool hasPending;

  @override
  ConsumerState<_Lesson> createState() => _LessonState();
}

class _LessonState extends ConsumerState<_Lesson> {
  bool _starting = false;

  Future<void> _start({bool restart = false}) async {
    if (_starting) return;
    setState(() => _starting = true);
    final session = ref.read(lessonSessionProvider);
    var index = 0;
    var started = false;
    if (widget.hasPending && !restart) {
      final recovered = await session.resume();
      started = recovered != null;
      index = recovered?.nextActivityIndex ?? 0;
    } else {
      if (restart && !await session.discardPending()) {
        if (mounted) _failed();
        return;
      }
      started = await session.start(
        lessonId: widget.lesson.id,
        contentVersion: widget.lesson.contentVersion,
      );
    }
    if (!mounted) return;
    if (started) {
      if (index >= widget.lesson.activityTypes.length) {
        final reward = await session.complete();
        if (!mounted) return;
        if (reward != null) {
          session.publishReward(reward);
          context.goNamed(AppRoutes.reward);
          return;
        }
        _failed();
        return;
      }
      if (index == 0) {
        unawaited(ref.read(ttsServiceProvider).speak(widget.lesson.tap.speech));
      }
      context.goNamed(
        ref
            .read(lessonFlowProvider)
            .routeOf(widget.lesson.activityTypes[index]),
      );
    } else {
      _failed();
    }
  }

  void _failed() {
    setState(() => _starting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível salvar ou continuar. Verifique a conexão e tente novamente. '
          'Se a lição mudou, comece novamente.',
        ),
      ),
    );
    ref.invalidate(pendingLessonProvider);
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final lessonNumber =
        int.tryParse(lesson.id.replaceFirst('lesson_', '')) ??
        ref.watch(currentLessonNumberProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The lesson summary scrolls; "Começar!" stays on screen at every
        // size. A child should never have to hunt for the button that
        // starts the lesson — on a 320px phone it used to sit 515px below
        // the fold with nothing to scroll.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'LIÇÃO $lessonNumber · ${lesson.theme.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.eyebrow(AppColors.teal),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  lesson.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(height: 1.2),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${lesson.activityTypes.length} atividades · cerca de '
                  '${lesson.estimatedMinutes} minutos',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final type in lesson.activityTypes) ...[
                  _ActivityRow(presentation: activityPresentation[type]!),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.hasPending) ...[
          Text(
            'Há uma lição para continuar.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          TextButton(
            onPressed: _starting ? null : () => _start(restart: true),
            child: const Text('Começar novamente'),
          ),
        ],
        LeleButton(
          label: _starting
              ? 'Aguarde...'
              : widget.hasPending
              ? 'Continuar lição'
              : 'Começar!',
          enabled: !_starting,
          height: 60,
          fontSize: 21,
          onPressed: () => _start(),
        ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry, this.onDiscard});

  final VoidCallback onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Não conseguimos carregar a lição',
          textAlign: TextAlign.center,
          style: AppTextStyles.heading.copyWith(height: 1.25),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Verifique sua conexão e tente de novo.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Tentar de novo',
            style: AppTextStyles.subheading.copyWith(
              color: AppColors.orangeDark,
            ),
          ),
        ),
        if (onDiscard != null)
          TextButton(
            onPressed: onDiscard,
            child: const Text('Descartar lição e voltar ao percurso'),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.presentation});

  final ActivityPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        spacing: AppSpacing.lg,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: presentation.chipColor,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Icon(presentation.icon, size: 22, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(presentation.title, style: AppTextStyles.sectionTitle),
                Text(
                  presentation.subtitle,
                  style: AppTextStyles.nunito(
                    12,
                    weight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            presentation.duration,
            style: AppTextStyles.nunito(
              12,
              weight: FontWeight.w700,
              color: AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}
