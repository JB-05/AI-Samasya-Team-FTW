import 'package:flutter/material.dart';

/// =============================================================================
/// NEUROPLAY DESIGN SYSTEM
/// Human-centered, evidence-based, institutionally restrained
/// =============================================================================
/// 
/// Based on:
/// - NHS Digital Service Manual
/// - Gov.uk Design System
/// - Nielsen Norman Group (NN/g)
/// - WCAG 2.2 Accessibility Guidelines
/// =============================================================================

class AppColors {
  AppColors._();

  // Core palette (Dashboard-safe, no semantic color meaning)
  static const Color primary = Color(0xFF2F3E46);       // Academic, serious
  static const Color primaryDark = Color(0xFF1F2D33);   // Hover state
  static const Color secondary = Color(0xFF52796F);     // Calm support tone
  static const Color background = Color(0xFFF8F9FA);    // Paper-like
  static const Color surface = Color(0xFFFFFFFF);       // Content separation
  static const Color border = Color(0xFFE0E0E0);        // Low-contrast containment
  static const Color textPrimary = Color(0xFF1F2933);   // High readability
  static const Color textSecondary = Color(0xFF6B7280); // De-emphasis
  static const Color accent = Color(0xFF8E9AAF);        // Links/badges only (<5% usage)
  static const Color destructive = Color(0xFFB85C5C);   // Muted red for warnings

  // Functional (NOT semantic - no red/green meaning)
  static const Color muted = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
}

class AppRadius {
  AppRadius._();

  static const double input = 8;
  static const double button = 8;
  static const double card = 12;
  static const double message = 16;
}

/// Typography scale (locked)
/// - Inter typeface (UI-optimized, neutral, institutional)
/// - Sentence case only
/// - No italics for emphasis
/// - Line height ≥ 1.4
class AppTypography {
  AppTypography._();

  static const double appTitle = 22;
  static const double sectionHeader = 18;
  static const double cardTitle = 16;
  static const double body = 15;
  static const double bodySmall = 14;
  static const double secondary = 13;
  static const double disclaimer = 12;
}

/// Input decoration - restrained, form-like
InputDecoration appInputDecoration({
  required String label,
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
  );
}

/// Build the app theme - institutional, restrained
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
    ),
    textTheme: const TextTheme(
      // App title - 22px SemiBold (single instance)
      headlineLarge: TextStyle(
        inherit: true,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
        height: 1.4,
      ),
      // Section header - 18px Medium (sparse use)
      headlineMedium: TextStyle(
        inherit: true,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      // Card title - 16px Medium
      titleLarge: TextStyle(
        inherit: true,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      // Body text - 15px Regular
      bodyLarge: TextStyle(
        inherit: true,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      // Body small - 14px Regular
      bodyMedium: TextStyle(
        inherit: true,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      // Secondary/disclaimer - 12-13px Regular
      bodySmall: TextStyle(
        inherit: true,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      // Button labels
      labelLarge: TextStyle(
        inherit: true,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.4,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        inherit: true,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    ),
    // Cards: Flat, 1px border, no shadows
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    // Primary button: Solid, restrained
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    ),
    // Secondary button: Outline
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        minimumSize: const Size(44, 44), // WCAG tap target
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      hintStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.muted,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withOpacity(0.1),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          );
        }
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 24);
        }
        return const IconThemeData(color: AppColors.textSecondary, size: 24);
      }),
    ),
  );
}

/// Global disclaimer text (must always be visible)
const String kDisclaimer = 
    'Observed patterns only. Not a diagnostic tool. '
    'Consult qualified professionals for concerns.';
