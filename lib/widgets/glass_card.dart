import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final double blurSigma;
  final Color? backgroundColor;
  final double? opacity;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blurSigma = 20.0,
    this.backgroundColor,
    this.opacity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      decoration: BoxDecoration(
        color: (backgroundColor ?? AppColors.surfaceVariant)
            .withValues(alpha: opacity ?? 0.6),
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }

    return container;
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final double? opacity;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: (backgroundColor ?? AppColors.surfaceVariant)
            .withValues(alpha: opacity ?? 0.6),
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }
}
