import 'package:flutter/material.dart';

/// ScanGo Tech App — Midnight Blue + Electric Cyan
/// Ultra-modern dark theme for medical technicians.
class AppColors {
  AppColors._();

  // ─── Brand ───────────────────────────────────────────────
  static const Color primary    = Color(0xFF00C6FF);   // سيان إلكتريك
  static const Color primaryDark = Color(0xFF0090C8);
  static const Color primaryLight = Color(0x2000C6FF); // 12% opacity
  static const Color primaryGlow  = Color(0x5500C6FF);

  static const Color accent     = Color(0xFF7B61FF);   // بنفسجي عميق
  static const Color accentLight = Color(0x207B61FF);

  // ─── Gradients ────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7B61FF), Color(0xFF00C6FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF060618), Color(0xFF0A0F2E), Color(0xFF060618)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0E1230), Color(0xFF111440)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient appBarGradient = LinearGradient(
    colors: [Color(0xFF0A0F2E), Color(0xFF060618)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Backgrounds ─────────────────────────────────────────
  static const Color background      = Color(0xFF04040F);
  static const Color surface         = Color(0xFF0D1028);
  static const Color surfaceVariant  = Color(0xFF141836);
  static const Color surfaceElevated = Color(0xFF1A1F45);

  // ─── Text ────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8892B0);
  static const Color textMuted     = Color(0xFF4A5374);
  static const Color textOnPrimary = Color(0xFF04040F);

  // ─── Borders ─────────────────────────────────────────────
  static const Color border      = Color(0xFF1E2448);
  static const Color borderLight = Color(0xFF161B3C);
  static const Color borderCyan  = Color(0x4400C6FF);

  // ─── Status ──────────────────────────────────────────────
  static const Color statusPending      = Color(0xFFFFB347);
  static const Color statusPendingBg    = Color(0x22FFB347);
  static const Color statusAccepted     = Color(0xFF00C6FF);
  static const Color statusAcceptedBg   = Color(0x2200C6FF);
  static const Color statusAssigned     = Color(0xFF00C6FF);
  static const Color statusAssignedBg   = Color(0x2200C6FF);
  static const Color statusOnWay        = Color(0xFFFFD166);
  static const Color statusOnWayBg      = Color(0x22FFD166);
  static const Color statusArrived      = Color(0xFF7B61FF);
  static const Color statusArrivedBg    = Color(0x227B61FF);
  static const Color statusInProgress   = Color(0xFF00C6FF);
  static const Color statusInProgressBg = Color(0x2200C6FF);
  static const Color statusCompleted    = Color(0xFF06D6A0);
  static const Color statusCompletedBg  = Color(0x2206D6A0);
  static const Color statusReportReady  = Color(0xFF06D6A0);
  static const Color statusReportReadyBg= Color(0x2206D6A0);
  static const Color statusCancelled    = Color(0xFFEF476F);
  static const Color statusCancelledBg  = Color(0x22EF476F);

  // ─── Semantic ────────────────────────────────────────────
  static const Color error      = Color(0xFFEF476F);
  static const Color errorBg    = Color(0x22EF476F);
  static const Color success    = Color(0xFF06D6A0);
  static const Color successBg  = Color(0x2206D6A0);
  static const Color warning    = Color(0xFFFFD166);
  static const Color warningBg  = Color(0x22FFD166);
  static const Color info       = Color(0xFF00C6FF);
  static const Color infoBg     = Color(0x2200C6FF);

  // ─── Shadows / Glows ─────────────────────────────────────
  static List<BoxShadow> get cyanGlow => [
    BoxShadow(color: primary.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 6)),
    BoxShadow(color: primary.withValues(alpha: 0.15), blurRadius: 48, offset: const Offset(0, 0)),
  ];

  static List<BoxShadow> get accentGlow => [
    BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6)),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6)),
    BoxShadow(color: primary.withValues(alpha: 0.04), blurRadius: 32),
  ];

  // ─── Status Helpers ───────────────────────────────────────
  static Color getStatusColor(String s) {
    switch (s) {
      case 'pending':     return statusPending;
      case 'accepted':    return statusAccepted;
      case 'assigned':    return statusAssigned;
      case 'on_way':      return statusOnWay;
      case 'arrived':     return statusArrived;
      case 'in_progress': return statusInProgress;
      case 'completed':   return statusCompleted;
      case 'report_ready':return statusReportReady;
      case 'cancelled':   return statusCancelled;
      default:            return textMuted;
    }
  }

  static Color getStatusBgColor(String s) {
    switch (s) {
      case 'pending':     return statusPendingBg;
      case 'accepted':    return statusAcceptedBg;
      case 'assigned':    return statusAssignedBg;
      case 'on_way':      return statusOnWayBg;
      case 'arrived':     return statusArrivedBg;
      case 'in_progress': return statusInProgressBg;
      case 'completed':   return statusCompletedBg;
      case 'report_ready':return statusReportReadyBg;
      case 'cancelled':   return statusCancelledBg;
      default:            return surfaceVariant;
    }
  }

  static String getStatusLabel(String s) {
    switch (s) {
      case 'pending':     return 'قيد المراجعة';
      case 'accepted':    return 'تم القبول';
      case 'assigned':    return 'تم التعيين';
      case 'on_way':      return 'في الطريق';
      case 'arrived':     return 'وصل الفني';
      case 'in_progress': return 'جاري الفحص';
      case 'completed':   return 'اكتمل';
      case 'report_ready':return 'التقرير جاهز';
      case 'cancelled':   return 'ملغي';
      default:            return s;
    }
  }
}
