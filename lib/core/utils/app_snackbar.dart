import 'package:flutter/material.dart';
import 'package:tech_app/core/theme/app_colors.dart';

enum SnackType { success, error, warning, info }

class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    required SnackType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final c = context.colors;
    
    final config = _getConfig(type, c);
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: config.iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(config.icon, color: config.iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: config.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: config.bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: config.borderColor, width: 1.5),
        ),
        elevation: 6,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  static _SnackConfig _getConfig(SnackType type, AppColorTokens c) {
    switch (type) {
      case SnackType.success:
        return _SnackConfig(
          icon: Icons.check_circle_rounded,
          iconColor: c.success,
          textColor: c.success,
          bgColor: c.successBg,
          borderColor: c.success.withOpacity(0.35),
        );
      case SnackType.error:
        return _SnackConfig(
          icon: Icons.error_rounded,
          iconColor: c.error,
          textColor: c.error,
          bgColor: c.errorBg,
          borderColor: c.error.withOpacity(0.35),
        );
      case SnackType.warning:
        return _SnackConfig(
          icon: Icons.warning_rounded,
          iconColor: c.warning,
          textColor: c.warning,
          bgColor: c.warningBg,
          borderColor: c.warning.withOpacity(0.35),
        );
      case SnackType.info:
        return _SnackConfig(
          icon: Icons.info_rounded,
          iconColor: c.info,
          textColor: c.info,
          bgColor: c.infoBg,
          borderColor: c.info.withOpacity(0.35),
        );
    }
  }
}

class _SnackConfig {
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;

  const _SnackConfig({
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });
}
