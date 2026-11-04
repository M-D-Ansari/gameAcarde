import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResponsiveArcadeContainer extends StatelessWidget {
  final Widget child;
  final double maxAspectRatio;
  final double maxWidth;

  const ResponsiveArcadeContainer({
    super.key,
    required this.child,
    this.maxAspectRatio = 9 / 16,
    this.maxWidth = 540,
  });

  bool get _isDesktopOrWeb {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktopOrWeb) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) {
          return child;
        }

        return Container(
          color: AppColors.voidSlate,
          child: Center(
            child: Container(
              width: maxWidth,
              decoration: BoxDecoration(
                color: AppColors.onyxNavy,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonCyan.withValues(alpha: 0.12),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: AppColors.cyberMagenta.withValues(alpha: 0.08),
                    blurRadius: 48,
                    spreadRadius: 8,
                  ),
                ],
                border: Border.all(
                  color: AppColors.neonCyan.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
