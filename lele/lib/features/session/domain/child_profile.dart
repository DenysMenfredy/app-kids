import 'package:equatable/equatable.dart';

/// Avatar palette offered during child profile creation.
enum ChildAvatar { orange, teal, purple, yellow }

class ChildProfile extends Equatable {
  const ChildProfile({
    required this.name,
    required this.age,
    required this.avatar,
  });

  final String name;
  final int age;
  final ChildAvatar avatar;

  static const defaultProfile = ChildProfile(
    name: 'Sofia',
    age: 5,
    avatar: ChildAvatar.orange,
  );

  ChildProfile copyWith({String? name, int? age, ChildAvatar? avatar}) {
    return ChildProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      avatar: avatar ?? this.avatar,
    );
  }

  @override
  List<Object?> get props => [name, age, avatar];
}
