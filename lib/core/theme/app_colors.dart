import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════
//  ScanGo Design System — Tech App Color Tokens
//  Unified Brand Identity. Shared with patient app.
// ══════════════════════════════════════════════════════════════════

class AppColorTokens {
  // ─── Brand ─────────────────────────────────────────────────────
  final Color primary;         // Teal #1D9E75
  final Color primaryDark;
  final Color primaryDeep;
  final Color primaryLight;

  // ─── Accent ────────────────────────────────────────────────────
  final Color accent;          // Amber
  final Color accentLight;

  // ─── Backgrounds ───────────────────────────────────────────────
  final Color background;      // Light: #FAFAF7, Dark: #0F1729
  final Color backgroundWarm;  // Light: #F1EFE8, Dark: #0A0F1E
  final Color surface;         // Light: #FFFFFF, Dark: #1A2332
  final Color surfaceVariant;  // Light: #F5F5F2, Dark: #243044
  final Color surfaceElevated; // Light: #F0EEE7, Dark: #2C3A52

  // ─── Text ──────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnPrimary;

  // ─── Borders ───────────────────────────────────────────────────
  final Color border;
  final Color borderLight;

  // ─── Semantic ──────────────────────────────────────────────────
  final Color error;
  final Color errorBg;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color info;
  final Color infoBg;

  // ─── Shimmer ───────────────────────────────────────────────────
  final Color skeletonBase;
  final Color skeletonHighlight;

  const AppColorTokens({
    required this.primary,
    required this.primaryDark,
    required this.primaryDeep,
    required this.primaryLight,
    required this.accent,
    required this.accentLight,
    required this.background,
    required this.backgroundWarm,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnPrimary,
    required this.border,
    required this.borderLight,
    required this.error,
    required this.errorBg,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.info,
    required this.infoBg,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  List<BoxShadow> get cardShadow => [
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  List<BoxShadow> get primaryGlow => [
    BoxShadow(color: primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4)),
  ];
}

class AppColors {
  AppColors._();

  // ─── Unified Status Colors (Non-negotiable) ───────────────────
  static const Color statusPending     = Color(0xFFD97B0A);
  static const Color statusPendingBg   = Color(0xFFFEF3E2);
  static const Color statusPendingBgDk = Color(0x26D97B0A);

  static const Color statusAccepted     = Color(0xFF2B7EC2);
  static const Color statusAcceptedBg   = Color(0xFFE6F0FA);
  static const Color statusAcceptedBgDk = Color(0x262B7EC2);

  static const Color statusAssigned     = Color(0xFF2B7EC2);
  static const Color statusAssignedBg   = Color(0xFFE6F0FA);
  static const Color statusAssignedBgDk = Color(0x262B7EC2);

  static const Color statusOnWay     = Color(0xFFD97B0A);
  static const Color statusOnWayBg   = Color(0xFFFEF3E2);
  static const Color statusOnWayBgDk = Color(0x26D97B0A);

  static const Color statusArrived     = Color(0xFF1D9E75);
  static const Color statusArrivedBg   = Color(0xFFE8F5F0);
  static const Color statusArrivedBgDk = Color(0x261D9E75);

  static const Color statusInProgress     = Color(0xFF1D9E75);
  static const Color statusInProgressBg   = Color(0xFFE8F5F0);
  static const Color statusInProgressBgDk = Color(0x261D9E75);

  static const Color statusCompleted     = Color(0xFF4D8C2C);
  static const Color statusCompletedBg   = Color(0xFFEFF6E8);
  static const Color statusCompletedBgDk = Color(0x264D8C2C);

  static const Color statusReportReady     = Color(0xFF4D8C2C);
  static const Color statusReportReadyBg   = Color(0xFFEFF6E8);
  static const Color statusReportReadyBgDk = Color(0x264D8C2C);

  static const Color statusCancelled     = Color(0xFFD44245);
  static const Color statusCancelledBg   = Color(0xFFFCE8E8);
  static const Color statusCancelledBgDk = Color(0x26D44245);

  // ─── Light Theme Tokens ───────────────────────────────────────
  static const AppColorTokens light = AppColorTokens(
    primary:       Color(0xFF1D9E75),
    primaryDark:   Color(0xFF16755A),
    primaryDeep:   Color(0xFF085041),
    primaryLight:  Color(0x1A1D9E75),
    accent:        Color(0xFFD97B0A),
    accentLight:   Color(0x1AD97B0A),
    background:     Color(0xFFFAFAF7),
    backgroundWarm: Color(0xFFF1EFE8),
    surface:        Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF5F5F2),
    surfaceElevated:Color(0xFFF0EEE7),
    textPrimary:   Color(0xFF1A1A1A),
    textSecondary: Color(0xFF5A5A5A),
    textMuted:     Color(0xFF9CA3AF),
    textOnPrimary: Color(0xFFFFFFFF),
    border:        Color(0xFFE5E5E0),
    borderLight:   Color(0xFFEEEEE8),
    error:      Color(0xFFD44245),
    errorBg:    Color(0xFFFCE8E8),
    success:    Color(0xFF4D8C2C),
    successBg:  Color(0xFFEFF6E8),
    warning:    Color(0xFFD97B0A),
    warningBg:  Color(0xFFFEF3E2),
    info:       Color(0xFF2B7EC2),
    infoBg:     Color(0xFFE6F0FA),
    skeletonBase:      Color(0xFFE8E8E4),
    skeletonHighlight: Color(0xFFF5F5F2),
  );

  // ─── Dark Theme Tokens ────────────────────────────────────────
  static const AppColorTokens dark = AppColorTokens(
    primary:       Color(0xFF1D9E75),
    primaryDark:   Color(0xFF16755A),
    primaryDeep:   Color(0xFF085041),
    primaryLight:  Color(0x261D9E75),
    accent:        Color(0xFFD97B0A),
    accentLight:   Color(0x26D97B0A),
    background:     Color(0xFF0F1729),
    backgroundWarm: Color(0xFF0A0F1E),
    surface:        Color(0xFF1A2332),
    surfaceVariant: Color(0xFF243044),
    surfaceElevated:Color(0xFF2C3A52),
    textPrimary:   Color(0xFFF0F0F0),
    textSecondary: Color(0xFF94A3B8),
    textMuted:     Color(0xFF64748B),
    textOnPrimary: Color(0xFFFFFFFF),
    border:        Color(0x1AFFFFFF),
    borderLight:   Color(0x0FFFFFFF),
    error:      Color(0xFFD44245),
    errorBg:    Color(0x26D44245),
    success:    Color(0xFF4D8C2C),
    successBg:  Color(0x264D8C2C),
    warning:    Color(0xFFD97B0A),
    warningBg:  Color(0x26D97B0A),
    info:       Color(0xFF2B7EC2),
    infoBg:     Color(0x262B7EC2),
    skeletonBase:      Color(0xFF1A2332),
    skeletonHighlight: Color(0xFF243044),
  );

  // ─── Status Helpers ───────────────────────────────────────────
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':       return statusPending;
      case 'accepted':      return statusAccepted;
      case 'assigned':      return statusAssigned;
      case 'on_way':        return statusOnWay;
      case 'arrived':       return statusArrived;
      case 'in_progress':   return statusInProgress;
      case 'completed':     return statusCompleted;
      case 'report_ready':  return statusReportReady;
      case 'cancelled':     return statusCancelled;
      default:              return const Color(0xFF9CA3AF);
    }
  }

  static Color getStatusBgColor(String status, {bool dark = false}) {
    switch (status) {
      case 'pending':       return dark ? statusPendingBgDk     : statusPendingBg;
      case 'accepted':      return dark ? statusAcceptedBgDk    : statusAcceptedBg;
      case 'assigned':      return dark ? statusAssignedBgDk    : statusAssignedBg;
      case 'on_way':        return dark ? statusOnWayBgDk       : statusOnWayBg;
      case 'arrived':       return dark ? statusArrivedBgDk     : statusArrivedBg;
      case 'in_progress':   return dark ? statusInProgressBgDk  : statusInProgressBg;
      case 'completed':     return dark ? statusCompletedBgDk   : statusCompletedBg;
      case 'report_ready':  return dark ? statusReportReadyBgDk : statusReportReadyBg;
      case 'cancelled':     return dark ? statusCancelledBgDk   : statusCancelledBg;
      default:              return dark ? const Color(0xFF1A2332) : const Color(0xFFF5F5F2);
    }
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending':       return 'قيد المراجعة';
      case 'accepted':      return 'تم القبول';
      case 'assigned':      return 'تم التعيين';
      case 'on_way':        return 'في الطريق';
      case 'arrived':       return 'وصل فريق المركز';
      case 'in_progress':   return 'جاري الفحص';
      case 'completed':     return 'اكتمل';
      case 'report_ready':  return 'التقرير جاهز';
      case 'cancelled':     return 'ملغي';
      default:              return status;
    }
  }
}

extension AppColorsExtension on BuildContext {
  AppColorTokens get colors {
    final brightness = Theme.of(this).brightness;
    return brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  }

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
