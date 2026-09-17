/// The spacing step the layouts are built on.
///
/// The screens were translated from a design handoff one at a time, which
/// left fifteen distinct gaps between 2 and 40 — 6 and 8 and 10 all doing
/// the same job on different screens. These are those values collapsed onto
/// a 4dp step, so a gap is chosen by role rather than re-measured per
/// screen.
abstract final class AppSpacing {
  /// Hairline gaps: a label sitting directly under its value.
  static const xs = 4.0;

  /// Related items inside one group.
  static const sm = 8.0;

  /// The default gap between siblings in a column.
  static const md = 12.0;

  /// Between a heading and the content it introduces.
  static const lg = 16.0;

  /// Between groups inside a section.
  static const xl = 20.0;

  /// Between sections.
  static const xxl = 24.0;

  /// Deliberate breathing room — above a primary action, or around art.
  static const xxxl = 40.0;

  /// The smallest square a child can reliably hit.
  ///
  /// Material asks for 48dp and Apple for 44pt. The header controls here
  /// were drawn at 36–40, which is inside both floors; for a 3–7-year-old
  /// with developing fine motor control it is the wrong side of the line.
  /// [LeleIconButton] keeps the drawn size and expands the *touch* area to
  /// this, so the design is unchanged and the target is not.
  static const minTapTarget = 48.0;
}
