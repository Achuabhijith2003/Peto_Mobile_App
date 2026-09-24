import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable, polished Follow / Following button with built-in loading indicator,
/// smooth feedback, and consistent design across all screens.
class FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool isCompact;

  const FollowButton({
    super.key,
    required this.isFollowing,
    this.isLoading = false,
    this.onPressed,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double height = isCompact ? 32 : 38;
    final double horizontalPadding = isCompact ? 14 : 20;
    final double fontSize = isCompact ? 12 : 13;

    if (isFollowing) {
      return SizedBox(
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onSurface,
            backgroundColor: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
            side: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.8),
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(height / 2),
            ),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
            elevation: 0,
          ),
          child: isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.onSurfaceVariant),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: isCompact ? 14 : 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Following',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
        ),
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: isCompact ? 14 : 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Follow',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
