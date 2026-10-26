import 'package:flutter/material.dart';

/// Skill Matrix palette — aligned with Packages workplace apps (cyan/teal).
abstract final class SkillMatrixTheme {
  SkillMatrixTheme._();

  static const brandPrimary = Color(0xFF0891B2);
  static const brandDark = Color(0xFF0E7490);
  static const brandTint = Color(0xFFE0F2FE);
  static const scaffoldTop = Color(0xFFF0F9FF);
  static const scaffoldBottom = Color(0xFFF8FAFC);
  static const ink = Color(0xFF0F172A);
  static const slate = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const warningBg = Color(0xFFFFF7ED);
  static const warningBorder = Color(0xFFFED7AA);
  static const success = Color(0xFF059669);
  static const gap = Color(0xFFDC2626);

  static const headerGradient = [
    Color(0xFF0E7490),
    Color(0xFF0891B2),
    Color(0xFF22D3EE),
  ];

  static const scaffoldGradient = [
    scaffoldTop,
    scaffoldBottom,
  ];
}
