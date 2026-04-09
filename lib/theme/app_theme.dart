import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          brightness: Brightness.dark,
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          secondaryContainer: AppColors.secondaryContainer,
          tertiary: AppColors.tertiary,
          onTertiary: AppColors.onTertiary,
          tertiaryContainer: AppColors.tertiaryContainer,
          error: AppColors.error,
          onError: AppColors.onError,
          errorContainer: AppColors.errorContainer,
          onErrorContainer: AppColors.onErrorContainer,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
          inverseSurface: AppColors.inverseSurface,
          onInverseSurface: AppColors.inverseOnSurface,
          inversePrimary: AppColors.inversePrimary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
            bodyColor: AppColors.onSurface, displayColor: AppColors.onSurface),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.background.withAlpha(204),
          indicatorColor: AppColors.primaryContainer,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              );
            }
            return GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.outline,
            );
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.onPrimaryContainer,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceContainer,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primaryContainer,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primary,
          onPrimaryContainer: Colors.white,
          secondary: AppColors.secondaryContainer,
          onSecondary: Colors.black,
          tertiary: AppColors.tertiaryContainer,
          onTertiary: Colors.white,
          error: AppColors.error,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF101820),
          onSurfaceVariant: Color(0xFF56606A),
          outline: Color(0xFF7A8793),
          outlineVariant: Color(0xFFCCD3DA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F6FA),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      );
}
