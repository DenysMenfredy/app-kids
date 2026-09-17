import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/assessment_repository.dart';
import '../domain/assessment.dart';

/// The assessment to present. Loaded once per onboarding run.
final assessmentContentProvider = FutureProvider<Assessment>(
  (ref) => ref.watch(assessmentRepositoryProvider).loadAssessment(),
);
