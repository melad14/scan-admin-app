import 'package:flutter/material.dart';
import 'package:tech_app/core/theme/app_colors.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isVisible;
  final String message;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isVisible,
    required this.child,
    this.message = 'جاري التحميل...',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        child,
        if (isVisible)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: c.cardShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: c.primary, strokeWidth: 3),
                      const SizedBox(height: 18),
                      Text(
                        message,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
