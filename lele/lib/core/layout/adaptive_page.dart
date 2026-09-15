import 'package:flutter/material.dart';

/// Material's window size classes — the vocabulary the rest of the app uses
/// to decide how much room it actually has.
///
/// The boundaries are the standard ones: a phone in portrait is compact, an
/// unfolded foldable or a small tablet lands in medium, a full tablet in
/// expanded. A phone in landscape is *not* compact by width, which is why
/// width alone never decides whether a layout can afford vertical space.
enum WindowClass { compact, medium, expanded }

WindowClass windowClassFor(double width) => width < 600
    ? WindowClass.compact
    : width < 840
    ? WindowClass.medium
    : WindowClass.expanded;

extension WindowClassContext on BuildContext {
  WindowClass get windowClass => windowClassFor(MediaQuery.sizeOf(this).width);

  bool get isCompact => windowClass == WindowClass.compact;

  /// True when there is genuinely little vertical room — a small phone, or
  /// any phone in landscape. Layouts use it to drop decoration rather than
  /// to change structure.
  bool get isShort => MediaQuery.sizeOf(this).height < 620;
}

/// Fills the screen when the content fits, scrolls when it does not.
///
/// The screens were written as fixed `Column`s, which works at the size they
/// were designed on and strands the primary button off the bottom everywhere
/// else: on a 320x568 phone the lesson's "Começar!" sat 515px below the
/// viewport with nothing to scroll, so a child simply could not start the
/// lesson. The designed layout — centring, `Spacer`, `Expanded` — is kept
/// whenever there is room, and degrades to a scroll only when there isn't.
///
/// It also caps the column width so a tablet or an unfolded foldable shows a
/// readable measure instead of one sentence stretched across 1000px.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.child,
    this.padding,
    this.maxContentWidth = 560,
    this.hasFlexibleChild = false,
  });

  final Widget child;
  final EdgeInsets? padding;

  /// Beyond this the column is centred rather than stretched.
  final double maxContentWidth;

  /// Set when [child] is a Column containing `Expanded`, `Flexible` or
  /// `Spacer`. Those need a bounded height, which a scroll view can only
  /// supply by measuring the intrinsic height first.
  final bool hasFlexibleChild;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? _defaultPadding(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // An unbounded parent means there is nothing to fill; fall back
            // to letting the content size itself.
            final minHeight = constraints.hasBoundedHeight
                ? (constraints.maxHeight - pad.vertical).clamp(
                    0.0,
                    double.infinity,
                  )
                : 0.0;

            var content = child;
            if (hasFlexibleChild) content = IntrinsicHeight(child: content);

            return SingleChildScrollView(
              padding: pad,
              // Nothing to scroll when it fits, so the bars never appear and
              // the layout is indistinguishable from the fixed one.
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Slightly roomier once there is room to be roomy.
  static EdgeInsets _defaultPadding(BuildContext context) => context.isCompact
      ? const EdgeInsets.fromLTRB(24, 12, 24, 20)
      : const EdgeInsets.fromLTRB(32, 20, 32, 28);
}

/// Caps and centres a column that manages its own vertical space.
///
/// Used by pages that must not scroll as a whole — a pinned action bar, a
/// full-bleed activity — but still should not stretch a line of text across
/// a tablet.
class AdaptiveWidth extends StatelessWidget {
  const AdaptiveWidth({super.key, required this.child, this.maxWidth = 560});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
