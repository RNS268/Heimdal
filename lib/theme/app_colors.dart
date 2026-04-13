import 'package:flutter/material.dart';

abstract final class AppColors {
  static bool _isDark = true;

  static void setBrightness(Brightness brightness) {
    _isDark = brightness == Brightness.dark;
  }

  static bool get isDark => _isDark;

  static Color get primary => _isDark ? darkPrimary : const Color(0xFF2346D5);
  static Color get primaryContainer =>
      _isDark ? darkPrimaryContainer : const Color(0xFF4361EE);
  static Color get onPrimary => _isDark ? darkOnPrimary : Colors.white;
  static Color get onPrimaryContainer =>
      _isDark ? darkOnPrimaryContainer : Colors.white;

  static Color get secondary =>
      _isDark ? darkSecondary : const Color(0xFF5A6BBF);
  static Color get secondaryContainer =>
      _isDark ? darkSecondaryContainer : const Color(0xFFE8EBFF);
  static Color get onSecondary => _isDark ? darkOnSecondary : Colors.white;
  static Color get onSecondaryContainer =>
      _isDark ? darkOnSecondaryContainer : const Color(0xFF191C1E);

  static Color get tertiary => _isDark ? darkTertiary : const Color(0xFFFFB786);
  static Color get tertiaryContainer =>
      _isDark ? darkTertiaryContainer : const Color(0xFFFFD8A4);
  static Color get onTertiary =>
      _isDark ? darkOnTertiary : const Color(0xFF502400);
  static Color get onTertiaryContainer =>
      _isDark ? darkOnTertiaryContainer : const Color(0xFF502400);

  static Color get error => _isDark ? darkError : const Color(0xFFBA1A1A);
  static Color get errorContainer =>
      _isDark ? darkErrorContainer : const Color(0xFFFFDAD6);
  static Color get onError => _isDark ? darkOnError : Colors.white;
  static Color get onErrorContainer =>
      _isDark ? darkOnErrorContainer : const Color(0xFF410002);

  static Color get background =>
      _isDark ? darkBackground : const Color(0xFFF7F9FB);
  static Color get surface => _isDark ? darkSurface : const Color(0xFFF7F9FB);
  static Color get surfaceDim =>
      _isDark ? darkSurfaceDim : const Color(0xFFF7F9FB);
  static Color get surfaceContainerLowest =>
      _isDark ? darkSurfaceContainerLowest : Colors.white;
  static Color get surfaceContainerLow =>
      _isDark ? darkSurfaceContainerLow : const Color(0xFFF2F4F6);
  static Color get surfaceContainer =>
      _isDark ? darkSurfaceContainer : const Color(0xFFECEEF2);
  static Color get surfaceContainerHigh =>
      _isDark ? darkSurfaceContainerHigh : const Color(0xFFE3E6EA);
  static Color get surfaceContainerHighest =>
      _isDark ? darkSurfaceContainerHighest : const Color(0xFFD7DAE0);
  static Color get surfaceBright =>
      _isDark ? darkSurfaceBright : const Color(0xFFCCD3DA);
  static Color get surfaceVariant =>
      _isDark ? darkSurfaceVariant : const Color(0xFFE3E6EA);

  static Color get onSurface =>
      _isDark ? darkOnSurface : const Color(0xFF191C1E);
  static Color get onSurfaceVariant =>
      _isDark ? darkOnSurfaceVariant : const Color(0xFF56606A);
  static Color get onBackground =>
      _isDark ? darkOnBackground : const Color(0xFF191C1E);
  static Color get outline => _isDark ? darkOutline : const Color(0xFF7A8793);
  static Color get outlineVariant =>
      _isDark ? darkOutlineVariant : const Color(0xFFC4C5D7);

  static Color get inverseSurface =>
      _isDark ? darkInverseSurface : const Color(0xFFDDE2F6);
  static Color get inverseOnSurface =>
      _isDark ? darkInverseOnSurface : const Color(0xFF2A303F);
  static Color get inversePrimary =>
      _isDark ? darkInversePrimary : const Color(0xFFADC6FF);

  static Color get success => _isDark ? darkSuccess : const Color(0xFF2E7D32);
  static Color get warning => _isDark ? darkWarning : const Color(0xFFED6C02);
  static Color get warningContainer =>
      _isDark ? darkWarningContainer : const Color(0xFFFFD8A4);

  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  static LinearGradient get errorGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [error, const Color(0xFFFF6B6B)],
  );

  static const Color darkBackground = Color(0xFF0D1321);
  static const Color darkSurfaceDim = Color(0xFF0D1321);
  static const Color darkSurfaceVariant = Color(0xFF2F3544);

  static const Color darkPrimary = Color(0xFFADC6FF);
  static const Color darkPrimaryContainer = Color(0xFF4D8EFF);
  static const Color darkOnPrimary = Color(0xFF002E6A);
  static const Color darkOnPrimaryContainer = Color(0xFF00285D);

  static const Color darkSecondary = Color(0xFFB1C6F9);
  static const Color darkSecondaryContainer = Color(0xFF304671);
  static const Color darkOnSecondary = Color(0xFF182F59);
  static const Color darkOnSecondaryContainer = Color(0xFFE8EBFF);

  static const Color darkTertiary = Color(0xFFFFB786);
  static const Color darkTertiaryContainer = Color(0xFFDF7412);
  static const Color darkOnTertiary = Color(0xFF502400);
  static const Color darkOnTertiaryContainer = Color(0xFF502400);

  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);

  static const Color darkSurface = Color(0xFF0D1321);
  static const Color darkSurfaceContainerLowest = Color(0xFF080E1C);
  static const Color darkSurfaceContainerLow = Color(0xFF151B29);
  static const Color darkSurfaceContainer = Color(0xFF191F2E);
  static const Color darkSurfaceContainerHigh = Color(0xFF242A39);
  static const Color darkSurfaceContainerHighest = Color(0xFF2F3544);
  static const Color darkSurfaceBright = Color(0xFF333948);

  static const Color darkOnSurface = Color(0xFFDDE2F6);
  static const Color darkOnSurfaceVariant = Color(0xFFC2C6D6);
  static const Color darkOnBackground = Color(0xFFDDE2F6);
  static const Color darkOutline = Color(0xFF8C909F);
  static const Color darkOutlineVariant = Color(0xFF424754);

  static const Color darkInverseSurface = Color(0xFFDDE2F6);
  static const Color darkInverseOnSurface = Color(0xFF2A303F);
  static const Color darkInversePrimary = Color(0xFF005AC2);

  static const Color darkSuccess = Color(0xFFB1F9B1);
  static const Color darkWarning = Color(0xFFFFB786);
  static const Color darkWarningContainer = Color(0xFFDF7412);
}
