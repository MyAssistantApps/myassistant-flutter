import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// THE APP'S TWO TYPEFACES, CHOSEN BY THE PERSON (the Design agent,
/// 2026-10-31). Headings were Space Grotesk and body text Manrope, both
/// bundled (runtime font fetching is off, core/bundled_fonts.dart). A
/// look may name one family for all text: one of the bundled two, or
/// Roboto — the phone's own font, which needs no file.
abstract final class NeonFonts {
  static const bundled = ['Space Grotesk', 'Manrope'];
  static String display = 'Space Grotesk';
  static String body = 'Manrope';

  /// Null: the app's own pairing.
  static void use(String? family) {
    display = family ?? 'Space Grotesk';
    body = family ?? 'Manrope';
  }

  static bool _system(String f) => !bundled.contains(f);
}

/// A heading's style in the person's display font — the same arguments
/// GoogleFonts.spaceGrotesk took, so every heading follows their choice.
TextStyle displayFont({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  final family = NeonFonts.display;
  if (NeonFonts._system(family)) {
    return (textStyle ?? const TextStyle()).copyWith(
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }
  return GoogleFonts.getFont(
    family,
    textStyle: textStyle,
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}

/// [base] in the person's body font.
TextTheme bodyTextTheme(TextTheme base) {
  final family = NeonFonts.body;
  if (NeonFonts._system(family)) return base;
  return GoogleFonts.getTextTheme(family, base);
}

/// One style in the body font — the same arguments GoogleFonts.manrope took.
TextStyle bodyFont({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  final family = NeonFonts.body;
  if (NeonFonts._system(family)) {
    return (textStyle ?? const TextStyle()).copyWith(
      color: color, backgroundColor: backgroundColor, fontSize: fontSize, fontWeight: fontWeight,
      fontStyle: fontStyle, letterSpacing: letterSpacing, wordSpacing: wordSpacing,
      textBaseline: textBaseline, height: height, locale: locale, foreground: foreground,
      background: background, shadows: shadows, fontFeatures: fontFeatures, decoration: decoration,
      decorationColor: decorationColor, decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }
  return GoogleFonts.getFont(family,
      textStyle: textStyle, color: color, backgroundColor: backgroundColor, fontSize: fontSize,
      fontWeight: fontWeight, fontStyle: fontStyle, letterSpacing: letterSpacing,
      wordSpacing: wordSpacing, textBaseline: textBaseline, height: height, locale: locale,
      foreground: foreground, background: background, shadows: shadows, fontFeatures: fontFeatures,
      decoration: decoration, decorationColor: decorationColor, decorationStyle: decorationStyle,
      decorationThickness: decorationThickness);
}
