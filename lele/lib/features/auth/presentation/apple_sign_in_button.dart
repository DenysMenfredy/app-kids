import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// "Sign in with Apple", on the platform Apple asks for it.
///
/// <https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple>
///
/// The mark is drawn by `sign_in_with_apple`'s own button rather than by us.
/// Apple does not allow its logo to be recreated, and that package encodes
/// the guidelines directly — the title renders at 43% of the button height,
/// in `.SF Pro Text`, with the logo at Apple's proportions. Re-deriving that
/// geometry by hand is the mistake, not the shortcut.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Continuar com Apple',
  });

  final VoidCallback? onPressed;

  /// Localised, with one word left alone: Apple's guidelines translate the
  /// action but never the brand, so this is "Continuar com Apple" and never
  /// "Continuar com Maçã".
  final String label;

  /// Matched to the Google button rather than Apple's default 44pt. The
  /// guidelines allow the button to be scaled, and every proportion inside
  /// it — type size, logo, padding — is derived from the height, so scaling
  /// keeps the button correct while letting the two sign-in options sit
  /// together as a pair.
  static const _height = 54.0;

  /// Apple permits a corner radius that matches the rest of the UI.
  static const _radius = 18.0;

  /// True only on a real iOS device or simulator.
  ///
  /// `dart:io`'s Platform cannot be imported on web at all, so the check is
  /// [defaultTargetPlatform] guarded by [kIsWeb] — Flutter reports iOS for
  /// Safari on an iPhone, where this button would have nothing native to
  /// talk to.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return const SizedBox.shrink();

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: SignInWithAppleButton(
        onPressed: onPressed ?? () {},
        text: label,
        height: _height,
        // Black on the app's cream background, which is the contrast Apple
        // asks for on a light surface.
        style: SignInWithAppleButtonStyle.black,
        borderRadius: const BorderRadius.all(Radius.circular(_radius)),
      ),
    );
  }
}
