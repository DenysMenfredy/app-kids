import 'package:flutter/material.dart';

import '../layout/adaptive_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'lele_icon_button.dart';

/// Shared chrome for child activities: close button + rounded progress bar,
/// content area and a fixed-height feedback message slot.
class ActivityScaffold extends StatelessWidget {
  const ActivityScaffold({
    super.key,
    required this.progress,
    required this.onClose,
    required this.child,
    this.message,
    this.messageColor = AppColors.textMuted,
    this.scrollableContent = false,
  });

  final double progress;
  final VoidCallback onClose;
  final Widget child;
  final String? message;
  final Color messageColor;

  /// Lets the activity body scroll when it cannot fit — a phone in
  /// landscape has barely 390px of height, and these layouts were drawn for
  /// three times that. Opt-in, because an activity whose body is a viewport
  /// (the tap grid) cannot report an intrinsic height and must not be
  /// measured this way.
  final bool scrollableContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.md,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  LeleIconButton(
                    icon: Icons.close_rounded,
                    onPressed: onClose,
                    semanticLabel: 'Sair da atividade',
                    size: 36,
                    iconSize: 20,
                    borderRadius: AppRadius.chip,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.bar),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: progress),
                        duration: const Duration(milliseconds: 400),
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 14,
                          backgroundColor: AppColors.panel,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: scrollableContent
                    ? AdaptivePage(
                        padding: EdgeInsets.zero,
                        maxContentWidth: 640,
                        hasFlexibleChild: true,
                        child: child,
                      )
                    // Capped either way, so letters do not sprawl across a
                    // tablet.
                    : AdaptiveWidth(maxWidth: 640, child: child),
              ),
              SizedBox(
                height: 52,
                child: Center(
                  child: Text(
                    message ?? '',
                    style: AppTextStyles.subheading.copyWith(
                      color: messageColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown if an activity is reached before its content has resolved. The
/// lesson intro loads and caches the lesson, so this is a safety net rather
/// than part of the normal flow.
class ActivityLoading extends StatelessWidget {
  const ActivityLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
    );
  }
}
