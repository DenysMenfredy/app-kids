import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../session/application/child_provider.dart';
import '../../session/application/progress_provider.dart';
import '../data/weekly_learning_repository.dart';
import '../domain/learning_week.dart';

final weeklyLearningProvider = Provider<AsyncValue<LearningWeek>>((ref) {
  if (!AppConfig.useFirebase) {
    return AsyncData(LearningWeek.empty(DateTime.now()));
  }
  final auth = ref.watch(firebaseAuthUserProvider);
  final children = ref.watch(remoteChildrenProvider);
  if (auth.isLoading || children.isLoading) return const AsyncLoading();
  if (auth.hasError) return AsyncError(auth.error!, auth.stackTrace!);
  if (children.hasError) {
    return AsyncError(children.error!, children.stackTrace!);
  }
  final childId = ref.watch(activeChildIdProvider);
  if (auth.value == null ||
      !children.requireValue.any((child) => child.id == childId)) {
    return AsyncData(LearningWeek.empty(DateTime.now()));
  }
  return ref.watch(
    weeklyLearningQueryProvider((uid: auth.value!.uid, childId: childId)),
  );
});

final weeklyLearningQueryProvider = FutureProvider.autoDispose
    .family<LearningWeek, ({String uid, String childId})>((ref, scope) async {
      ref.watch(remoteProgressProvider);
      final week = await ref
          .watch(weeklyLearningRepositoryProvider)
          .load(scope.childId);
      if (!ref.mounted) return week;
      final refreshAfter = week.refreshAfterMilliseconds;
      if (refreshAfter != null) {
        final delay = Duration(
          milliseconds: refreshAfter,
        );
        final timer = Timer(
          delay.isNegative ? const Duration(seconds: 1) : delay,
          ref.invalidateSelf,
        );
        ref.onDispose(timer.cancel);
      }
      return week;
    });
