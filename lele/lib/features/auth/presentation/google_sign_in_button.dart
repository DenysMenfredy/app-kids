import 'package:flutter/material.dart';

/// "Sign in with Google", built to Google's branding guidelines.
///
/// <https://developers.google.com/identity/branding-guidelines>
///
/// This button is not ours to restyle. The guidelines are explicit that the
/// mark must be the asset Google ships — "you can't change the size or color
/// of the Google 'G' logo", and "don't create custom icons" — so the colours,
/// stroke and spacing below are Google's numbers rather than [AppColors] and
/// [AppSpacing], and they deliberately do not follow the app's design tokens.
/// Anything that looks like drift from the rest of the app here is the point.
///
/// What this replaced was a sweep-gradient circle: the right colours smeared
/// around a ring, which is precisely the "custom icon" the guidelines forbid.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Continuar com Google',
  });

  final VoidCallback? onPressed;

  /// One of the three sanctioned actions, localised. Google permits "Sign in
  /// with Google", "Sign up with Google" and "Continue with Google", and
  /// encourages translating them; it permits nothing else, so this is not a
  /// free-text slot.
  final String label;

  // --- Google's light theme specification -------------------------------
  static const _fill = Color(0xFFFFFFFF);
  static const _stroke = Color(0xFF747775);
  static const _textColor = Color(0xFF1F1F1F);
  static const _fontSize = 14.0;
  static const _lineHeight = 20.0;

  /// Android metrics: 12 before the logo, 10 between logo and text, 12 after.
  static const _edgePadding = 12.0;
  static const _logoGap = 10.0;

  /// The mark renders at 20dp. The asset is square with the glyph centred at
  /// its true proportions, so a square box cannot squash it.
  static const _logoSize = 20.0;

  /// Kept from the app's own shape language. Google publishes square,
  /// rounded and pill variants of this button, so the corner radius is one
  /// of the few things a caller is free to choose.
  static const _radius = 18.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: _edgePadding),
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: _stroke,
              // "1px | inside" — an outside stroke would eat into the
              // logo's clear space.
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/google/g_logo.png',
                width: _logoSize,
                height: _logoSize,
                // The mark carries no meaning the label does not already
                // give; announcing "Google" twice helps nobody.
                excludeFromSemantics: true,
              ),
              const SizedBox(width: _logoGap),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    // Google Sans Medium is specified and is not
                    // redistributable, so this falls back to the platform
                    // UI font at Google's size and colour rather than to a
                    // Lelê display face, which would read as a custom
                    // button.
                    fontSize: _fontSize,
                    height: _lineHeight / _fontSize,
                    fontWeight: FontWeight.w500,
                    color: _textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
