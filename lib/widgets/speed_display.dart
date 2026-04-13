import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SpeedDisplay extends StatelessWidget {
  final double speed;
  final String unit;

  const SpeedDisplay({super.key, required this.speed, this.unit = 'km/h'});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryContainer],
          ).createShader(bounds),
          child: Text(
            speed.toInt().toString(),
            style: const TextStyle(
              fontSize: 112,
              fontWeight: FontWeight.w800,
              letterSpacing: -4,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
        Text(
          unit.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: AppColors.outline,
          ),
        ),
      ],
    );
  }
}
