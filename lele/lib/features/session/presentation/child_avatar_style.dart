import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/child_profile.dart';

/// How each avatar is drawn wherever the child is represented.
///
/// Kept out of the domain model: [ChildAvatar]'s names are a backend data
/// contract, while these colours are only how the app happens to paint
/// them today.
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
