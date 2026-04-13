import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BleStatusChip extends StatelessWidget {
  final bool isConnected;
  final String? deviceName;

  const BleStatusChip({super.key, required this.isConnected, this.deviceName});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              size: 20,
              color: AppColors.primary,
            ),
            if (isConnected && deviceName != null) ...[
              const SizedBox(width: 8),
              Text(
                deviceName!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
