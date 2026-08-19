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

/// Founder pricing from the product spec.
const founderPlans = [
  Plan(
    id: 'monthly',
    name: 'Mensal',
    subtitle: 'Cobrado todo mês',
    price: r'R$ 19,90',
  ),
  Plan(
    id: 'quarterly',
    name: 'Trimestral',
    subtitle: r'R$ 16,63/mês',
    price: r'R$ 49,90',
  ),
  Plan(
    id: 'annual',
    name: 'Anual',
    subtitle: r'R$ 12,49/mês · economize 37%',
    price: r'R$ 149,90',
    badge: 'MAIS POPULAR',
  ),
];
