import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography system using Inter font family
/// Sizes and weights from Section 2.2 of the specification
abstract final class AppTypography {
  static TextStyle get displayLg => GoogleFonts.inter(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.onSurface,
      );

  static TextStyle get displaySm => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineSm => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.onSurface,
      );

  static TextStyle get titleMd => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  static TextStyle get labelMd => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: AppColors.onSurface,
      );

  static TextStyle get labelSm => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: AppColors.outline,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
      );
}
