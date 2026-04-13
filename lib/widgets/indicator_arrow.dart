import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class IndicatorArrow extends StatefulWidget {
  final bool isActive;
  final bool isLeft;

  const IndicatorArrow({
    super.key,
    required this.isActive,
    required this.isLeft,
  });

  @override
  State<IndicatorArrow> createState() => _IndicatorArrowState();
}

class _IndicatorArrowState extends State<IndicatorArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _opacityAnimation = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(IndicatorArrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: widget.isActive ? _opacityAnimation.value : 0.2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isLeft ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                size: 40,
                color: AppColors.primary,
              ),
              const SizedBox(height: 4),
              Text(
                widget.isLeft ? 'LEFT' : 'RIGHT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
