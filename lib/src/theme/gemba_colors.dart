import 'package:flutter/material.dart';

/// Packages brand palette for Digital Gemba (aligned with PDF report).
abstract final class GembaColors {
  static const brandDark = Color(0xFF006BA6);
  static const brandPrimary = Color(0xFF008FD5);
  static const brandLight = Color(0xFF4DB8E8);
  static const brandTint = Color(0xFFE8F4FC);
  static const ink = Color(0xFF006BA6);
  static const slate = Color(0xFF64748B);
  static const border = Color(0xFFD6EAF8);

  static const scaffoldGradient = [
    brandTint,
    Color(0xFFE2E8F0),
  ];

  static const headerGradient = [
    brandDark,
    brandPrimary,
    brandLight,
  ];

  static const headerGradientSimple = [
    brandDark,
    brandPrimary,
  ];
}
