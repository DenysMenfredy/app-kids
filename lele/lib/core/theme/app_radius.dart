/// Corner radii, by the kind of thing being rounded.
///
/// Fourteen distinct values between 5 and 28 were in use, several of them a
/// pixel or two apart on elements that play the same role. These are the six
/// steps that remain.
abstract final class AppRadius {
  /// Progress bars and the smallest badges.
  static const bar = 8.0;

  /// Chips and inline pills.
  static const chip = 12.0;

  /// Icon buttons and other small controls.
  static const control = 14.0;

  /// Text inputs.
  static const field = 18.0;

  /// Cards and tiles.
  static const card = 22.0;

  /// Full-width panels and activity surfaces.
  static const panel = 26.0;
}
