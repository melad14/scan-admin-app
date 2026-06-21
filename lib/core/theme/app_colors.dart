import 'package:flutter/material.dart';

/// ScanGo Design System — Tech App Colors (Dark Theme)
/// High-contrast for outdoor use. Same brand, different expression.
class AppColors {
  AppColors._();

  // ─── Brand Colors (SAME as Patient App) ───────────────────
  static const Color primary = Color(0xFF1D9E75);
  static const Color primaryDark = Color(0xFF16755A);
  static const Color primaryDeep = Color(0xFF085041);
  static const Color primaryLight = Color(0xFFE8F5F0);

  // ─── Surface Colors (Dark Theme) ──────────────────────────
  static const Color background = Color(0xFF0F1729);
  static const Color surface = Color(0xFF1A2332);
  static const Color surfaceVariant = Color(0xFF243044);
  static const Color surfaceBright = Color(0xFF2D3B50);

  // ─── Text Colors (Dark Theme) ─────────────────────────────
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFFB0B8C8);
  static const Color textMuted = Color(0xFF6B7A8D);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── Border Colors ────────────────────────────────────────
  static const Color border = Color(0xFF2A3545);
  static const Color borderLight = Color(0xFF1F2D3D);

  // ─── Status Colors (IDENTICAL to Patient App) ─────────────
  static const Color statusPending = Color(0xFFD97B0A);
  static const Color statusPendingBg = Color(0x26D97B0A);

  static const Color statusAccepted = Color(0xFF2B7EC2);
  static const Color statusAcceptedBg = Color(0x262B7EC2);

  static const Color statusAssigned = Color(0xFF2B7EC2);
  static const Color statusAssignedBg = Color(0x262B7EC2);

  static const Color statusOnWay = Color(0xFFD97B0A);
  static const Color statusOnWayBg = Color(0x26D97B0A);

  static const Color statusArrived = Color(0xFF1D9E75);
  static const Color statusArrivedBg = Color(0x261D9E75);

  static const Color statusInProgress = Color(0xFF1D9E75);
  static const Color statusInProgressBg = Color(0x261D9E75);

  static const Color statusCompleted = Color(0xFF4D8C2C);
  static const Color statusCompletedBg = Color(0x264D8C2C);

  static const Color statusReportReady = Color(0xFF4D8C2C);
  static const Color statusReportReadyBg = Color(0x264D8C2C);

  static const Color statusCancelled = Color(0xFFD44245);
  static const Color statusCancelledBg = Color(0x26D44245);

  // ─── Semantic Colors ──────────────────────────────────────
  static const Color error = Color(0xFFD44245);
  static const Color errorBg = Color(0x26D44245);
  static const Color success = Color(0xFF4D8C2C);
  static const Color successBg = Color(0x264D8C2C);
  static const Color warning = Color(0xFFD97B0A);
  static const Color warningBg = Color(0x26D97B0A);
  static const Color info = Color(0xFF2B7EC2);
  static const Color infoBg = Color(0x262B7EC2);

  // ─── Status Helpers (SAME logic as Patient App) ───────────
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending': return statusPending;
      case 'accepted': return statusAccepted;
      case 'assigned': return statusAssigned;
      case 'on_way': return statusOnWay;
      case 'arrived': return statusArrived;
      case 'in_progress': return statusInProgress;
      case 'completed': return statusCompleted;
      case 'report_ready': return statusReportReady;
      case 'cancelled': return statusCancelled;
      default: return textMuted;
    }
  }

  static Color getStatusBgColor(String status) {
    switch (status) {
      case 'pending': return statusPendingBg;
      case 'accepted': return statusAcceptedBg;
      case 'assigned': return statusAssignedBg;
      case 'on_way': return statusOnWayBg;
      case 'arrived': return statusArrivedBg;
      case 'in_progress': return statusInProgressBg;
      case 'completed': return statusCompletedBg;
      case 'report_ready': return statusReportReadyBg;
      case 'cancelled': return statusCancelledBg;
      default: return surfaceVariant;
    }
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'قيد المراجعة';
      case 'accepted': return 'تم القبول';
      case 'assigned': return 'تم التعيين';
      case 'on_way': return 'في الطريق';
      case 'arrived': return 'وصل الفني';
      case 'in_progress': return 'جاري الفحص';
      case 'completed': return 'اكتمل الفحص';
      case 'report_ready': return 'التقرير جاهز';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }
}
