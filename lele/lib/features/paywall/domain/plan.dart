import 'package:equatable/equatable.dart';

class Plan extends Equatable {
  const Plan({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.price,
    this.badge,
  });

  final String id;
  final String name;
  final String subtitle;
  final String price;
  final String? badge;

  @override
  List<Object?> get props => [id, name, subtitle, price, badge];
}

// Prices/periods must come from a configured native store catalog, not constants.
