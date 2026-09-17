import 'package:equatable/equatable.dart';

/// Avatar palette offered during child profile creation.
///
/// The enum name is what the backend stores as `avatarId`, so these names
/// are part of the data contract — renaming one orphans existing children.
enum ChildAvatar { orange, teal, purple, yellow }

/// Reads the `avatarId` the backend stored, falling back to the default
/// rather than throwing on an unknown value.
ChildAvatar childAvatarFromId(String? id) {
  return ChildAvatar.values.firstWhere(
    (avatar) => avatar.name == id,
    orElse: () => ChildProfile.defaultProfile.avatar,
  );
}

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
