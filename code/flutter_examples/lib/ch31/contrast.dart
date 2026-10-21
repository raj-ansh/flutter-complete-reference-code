import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/material.dart' show ColorScheme;

// #docregion formula
/// Relative luminance as defined by WCAG 2: 0 is black, 1 is white.
double relativeLuminance(Color color) {
  // Each channel is first linearized: the stored values are gamma-encoded.
  double linear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * linear(color.r) +
      0.7152 * linear(color.g) +
      0.0722 * linear(color.b);
}

/// Contrast ratio between two colors, from 1 (identical) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}
// #enddocregion formula

// #docregion scheme
/// A text color and the color it is drawn on.
typedef ColorPair = ({String name, Color foreground, Color background});

List<ColorPair> pairsOf(ColorScheme s) => [
  (name: 'onPrimary / primary', foreground: s.onPrimary, background: s.primary),
  (
    name: 'onSecondary / secondary',
    foreground: s.onSecondary,
    background: s.secondary,
  ),
  (
    name: 'onTertiary / tertiary',
    foreground: s.onTertiary,
    background: s.tertiary,
  ),
  (name: 'onError / error', foreground: s.onError, background: s.error),
  (name: 'onSurface / surface', foreground: s.onSurface, background: s.surface),
  (
    name: 'onPrimaryContainer / primaryContainer',
    foreground: s.onPrimaryContainer,
    background: s.primaryContainer,
  ),
  (
    name: 'onSurfaceVariant / surface',
    foreground: s.onSurfaceVariant,
    background: s.surface,
  ),
  (name: 'primary / surface', foreground: s.primary, background: s.surface),
  (name: 'outline / surface', foreground: s.outline, background: s.surface),
];

/// The pairs whose contrast is below [minimum] (4.5 is the WCAG AA level for
/// normal-size text).
List<(ColorPair, double)> failingPairs(ColorScheme s, {double minimum = 4.5}) =>
    [
      for (final pair in pairsOf(s))
        if (contrastRatio(pair.foreground, pair.background) case final ratio
            when ratio < minimum)
          (pair, ratio),
    ];
// #enddocregion scheme
