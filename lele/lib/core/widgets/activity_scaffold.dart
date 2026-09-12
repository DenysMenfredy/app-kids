import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
  });

  final double progress;
  final VoidCallback onClose;
  final Widget child;
  final String? message;
  final Color messageColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
          child: Column(
            children: [
              Row(
                children: [
                  _CloseButton(onTap: onClose),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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
              Expanded(child: child),
              SizedBox(
                height: 52,
                child: Center(
                  child: Text(
                    message ?? '',
                    style: TextStyle(
                      fontFamily: 'Baloo 2',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
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

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.close_rounded, size: 20,
            color: AppColors.textMuted),
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

