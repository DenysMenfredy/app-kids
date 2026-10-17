import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/plan.dart';

/// No store product IDs have been approved/configured yet. An empty catalog is
/// explicit unavailability, never a reason to invent prices or launch checkout.
/// F3 will supply store-localized products through the BillingRepository.
final storeCatalogProvider = Provider<List<Plan>>((ref) => const []);
