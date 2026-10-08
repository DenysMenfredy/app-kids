import 'package:equatable/equatable.dart';

import 'child_profile.dart';

/// A child profile together with the server-generated ID used to scope data.
class ChildRecord extends Equatable {
  const ChildRecord({required this.id, required this.profile});

  final String id;
  final ChildProfile profile;

  @override
  List<Object?> get props => [id, profile];
}
