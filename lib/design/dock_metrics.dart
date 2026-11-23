import 'package:flutter/widgets.dart';

/// THE DOCK'S FOOTPRINT, IN ONE PLACE.
///
/// Every tab scrolls under the same thing: a 58 dp floating glass pill
/// (8 dp above the system navigation inset) with the mic nested in a
/// cradle in its middle, rising 33 dp above the bar. Lists used to end with a
/// hard-coded 120 dp of padding, which was 2 dp short on the owner's
/// phone and ~32 dp short on phones with 3-button navigation: the last
/// card ended under the mic. Everything that has to clear the dock asks
/// here instead of guessing.
abstract final class Dock {
  /// The floating navbar's height (HomeShell's _FloatingDock).
  static const double barHeight = 58;

  /// THE FLOATING NAVBAR (2026-11-22): the pill floats this far above the
  /// system navigation and this far in from each side. Lowered from 22
  /// (owner, 2026-11-23: "move the navbar a bit down").
  static const double floatGap = 8;
  static const double sideMargin = 16;

  /// THE CRADLE (2026-11-22, Manish's mockup): the mic's centre sits this
  /// far below the bar's top edge, in a smooth dip of this radius with
  /// rounded shoulders; the tabs leave this much room for it.
  static const double micDrop = 2;
  static const double cradleRadius = 39;
  static const double cradleFillet = 11;
  static const double cradleGap = 96;

  /// How far the mic (35 dp visible radius) rises above the bar.
  static const double orbRise = 35 - micDrop;

  /// Bottom padding that keeps content clear of the bar AND the mic.
  ///
  /// Inside HomeShell's body (extendBody) MediaQuery padding.bottom is
  /// already the bar plus the system inset; outside the shell it is just
  /// the inset, so the same call stays sensible on a pushed screen.
  static double clearance(BuildContext context, {double gap = 18}) =>
      MediaQuery.paddingOf(context).bottom + orbRise + gap;
}
