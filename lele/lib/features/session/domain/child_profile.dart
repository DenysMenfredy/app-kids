import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Avatar palette offered during child profile creation.
///
/// The enum name is what the backend stores as `avatarId`, so these names
/// are part of the data contract — renaming one orphans existing children.
enum ChildAvatar { orange, teal, purple, yellow }

/// How each avatar is drawn wherever the child is represented.
extension ChildAvatarStyle on ChildAvatar {
  Color get color => switch (this) {
    ChildAvatar.orange => AppColors.orangeSoft,
    ChildAvatar.teal => AppColors.teal,
    ChildAvatar.purple => AppColors.purple,
    ChildAvatar.yellow => AppColors.yellow,
  };

  /// A darker shade of the same hue, so the smile reads on the face.
  Color get mouthColor => switch (this) {
    ChildAvatar.orange => AppColors.mouthBrown,
    ChildAvatar.teal => AppColors.tealDark,
    ChildAvatar.purple => AppColors.purpleDark,
    ChildAvatar.yellow => AppColors.yellowDark,
  };
}

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
