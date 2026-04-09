import 'package:flutter/material.dart';

/// Design system color palette for HEIMDALL - "The Precision Pilot"
/// All colors from Section 2.1 of the specification
abstract final class AppColors {
  static const Color background = Color(0xFF0D1321);
  static const Color surface = Color(0xFF0D1321);
  static const Color surfaceDim = Color(0xFF0D1321);
  static const Color surfaceContainerLowest = Color(0xFF080E1C);
  static const Color surfaceContainerLow = Color(0xFF151B29);
  static const Color surfaceContainer = Color(0xFF191F2E);
  static const Color surfaceContainerHigh = Color(0xFF242A39);
  static const Color surfaceContainerHighest = Color(0xFF2F3544);
  static const Color surfaceBright = Color(0xFF333948);
  static const Color surfaceVariant = Color(0xFF2F3544);

  static const Color primary = Color(0xFFADC6FF);
  static const Color primaryContainer = Color(0xFF4D8EFF);
  static const Color onPrimary = Color(0xFF002E6A);
  static const Color onPrimaryContainer = Color(0xFF00285D);

  static const Color secondary = Color(0xFFB1C6F9);
  static const Color secondaryContainer = Color(0xFF304671);
  static const Color onSecondary = Color(0xFF182F59);

  static const Color tertiary = Color(0xFFFFB786);
  static const Color tertiaryContainer = Color(0xFFDF7412);
  static const Color onTertiary = Color(0xFF502400);

  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFF690005);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  static const Color onSurface = Color(0xFFDDE2F6);
  static const Color onSurfaceVariant = Color(0xFFC2C6D6);
  static const Color onBackground = Color(0xFFDDE2F6);
  static const Color outline = Color(0xFF8C909F);
  static const Color outlineVariant = Color(0xFF424754);

  static const Color inverseSurface = Color(0xFFDDE2F6);
  static const Color inverseOnSurface = Color(0xFF2A303F);
  static const Color inversePrimary = Color(0xFF005AC2);

  static const Color success = Color(0xFFB1F9B1);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [error, Color(0xFFFF6B6B)],
  );
}
