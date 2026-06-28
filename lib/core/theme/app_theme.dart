import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// ScanGo Design System — Tech App Themes (Light + Dark)
class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════════════════════
  //  LIGHT THEME
  // ══════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Cairo',

      colorScheme: const ColorScheme.light(
        primary:            Color(0xFF1D9E75),
        onPrimary:          Color(0xFFFFFFFF),
        primaryContainer:   Color(0x1A1D9E75),
        onPrimaryContainer: Color(0xFF085041),
        secondary:          Color(0xFFD97B0A),
        onSecondary:        Color(0xFFFFFFFF),
        surface:            Color(0xFFFFFFFF),
        onSurface:          Color(0xFF1A1A1A),
        error:              Color(0xFFD44245),
        onError:            Color(0xFFFFFFFF),
        outline:            Color(0xFFE5E5E0),
        outlineVariant:     Color(0xFFEEEEE8),
        surfaceContainerHighest: Color(0xFFF5F5F2),
      ),

      scaffoldBackgroundColor: AppColors.light.background,

      // ─── AppBar ──────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x0D000000),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A), size: 24),
      ),

      // ─── Elevated Button (Standard 56px action buttons for outdoor use) ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D9E75),
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 56), // Larger button for outdoor use
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      // ─── Outlined Button ──────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A1A1A),
          minimumSize: const Size(88, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0xFFE5E5E0)),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ─── Text Button ─────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1D9E75),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ─── Input Fields ─────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E5E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E5E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD44245)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD44245), width: 2),
        ),
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Color(0xFF5A5A5A)),
        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Color(0xFF9CA3AF)),
        prefixIconColor: const Color(0xFF9CA3AF),
        suffixIconColor: const Color(0xFF9CA3AF),
      ),

      // ─── Card ─────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E5E0), width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
        shadowColor: const Color(0x0D000000),
      ),

      // ─── Divider ──────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEEEEE8),
        thickness: 1,
        space: 1,
      ),

      // ─── SnackBar ─────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        contentTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        actionTextColor: const Color(0xFF1D9E75),
      ),

      // ─── Dialog ───────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
        contentTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, color: Color(0xFF5A5A5A), height: 1.8),
      ),

      // ─── TabBar ───────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFF1D9E75),
        unselectedLabelColor: Color(0xFF9CA3AF),
        indicatorColor: Color(0xFF1D9E75),
        labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w400, fontSize: 13),
      ),

      // ─── Text Theme ───────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Cairo', fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF085041), height: 1.5),
        headlineLarge: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A), height: 1.5),
        headlineMedium: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A), height: 1.5),
        headlineSmall: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), height: 1.5),
        bodyLarge: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: Color(0xFF1A1A1A), height: 1.8),
        bodyMedium: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Color(0xFF5A5A5A), height: 1.8),
        bodySmall: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF5A5A5A), height: 1.6),
        labelLarge: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
        labelSmall: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF), height: 1.4),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DARK THEME
  // ══════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Cairo',

      colorScheme: const ColorScheme.dark(
        primary:            Color(0xFF1D9E75),
        onPrimary:          Color(0xFFFFFFFF),
        primaryContainer:   Color(0x261D9E75),
        onPrimaryContainer: Color(0xFF1D9E75),
        secondary:          Color(0xFFD97B0A),
        onSecondary:        Color(0xFFFFFFFF),
        surface:            Color(0xFF1A2332),
        onSurface:          Color(0xFFF0F0F0),
        error:              Color(0xFFD44245),
        onError:            Color(0xFFFFFFFF),
        outline:            Color(0x1AFFFFFF),
        outlineVariant:     Color(0x0FFFFFFF),
        surfaceContainerHighest: Color(0xFF243044),
      ),

      scaffoldBackgroundColor: AppColors.dark.background,

      // ─── AppBar ──────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A2332),
        foregroundColor: Color(0xFFF0F0F0),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF0F0F0),
        ),
        iconTheme: IconThemeData(color: Color(0xFFF0F0F0), size: 24),
      ),

      // ─── Elevated Button ─────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D9E75),
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 56), // Larger buttons for outdoor use
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      // ─── Outlined Button ──────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF0F0F0),
          minimumSize: const Size(88, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0x1AFFFFFF)),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ─── Text Button ─────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1D9E75),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ─── Input Fields ─────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF243044),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD44245)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD44245), width: 2),
        ),
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Color(0xFF94A3B8)),
        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Color(0xFF64748B)),
        prefixIconColor: const Color(0xFF64748B),
        suffixIconColor: const Color(0xFF64748B),
      ),

      // ─── Card ─────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: const Color(0xFF1A2332),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      // ─── Divider ──────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0x0FFFFFFF),
        thickness: 1,
        space: 1,
      ),

      // ─── SnackBar ─────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2C3A52),
        contentTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Color(0xFFF0F0F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        actionTextColor: const Color(0xFF1D9E75),
      ),

      // ─── Dialog ───────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFF0F0F0)),
        contentTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, color: Color(0xFF94A3B8), height: 1.8),
      ),

      // ─── TabBar ───────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFF1D9E75),
        unselectedLabelColor: Color(0xFF64748B),
        indicatorColor: Color(0xFF1D9E75),
        labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w400, fontSize: 13),
      ),

      // ─── Text Theme ───────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Cairo', fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF1D9E75), height: 1.5),
        headlineLarge: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFFF0F0F0), height: 1.5),
        headlineMedium: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFF0F0F0), height: 1.5),
        headlineSmall: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFF0F0F0), height: 1.5),
        bodyLarge: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: Color(0xFFF0F0F0), height: 1.8),
        bodyMedium: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Color(0xFF94A3B8), height: 1.8),
        bodySmall: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF94A3B8), height: 1.6),
        labelLarge: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFF0F0F0)),
        labelSmall: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B), height: 1.4),
      ),
    );
  }
}
