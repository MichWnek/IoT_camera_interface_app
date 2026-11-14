import 'package:flutter/material.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

class StatusSummary extends StatelessWidget {
  final DeviceStatus? status_;

  const StatusSummary({super.key, this.status_});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (status_ == null) {
      return Text(
        'No status available, connect to device to retrieve status',
        style: text.bodyMedium,
      );
    } else {
      return _buildStatusSummary(context);
    }
  }

  Widget _buildStatusSummary(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          status_?.isOnline == true ? Icons.bluetooth : Icons.block_rounded,
          color: status_?.isOnline == true ? colors.primary : colors.outline,
        ),
        const SizedBox(width: 8),
        Text(
          'Battery: ${status_?.batteryPercent}%',
          style: text.bodyMedium?.copyWith(
            color: status_?.isLowBattery == true
                ? colors.error
                : colors.primary,
            fontWeight: status_?.isLowBattery == true
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'SD: ${status_?.sdFreeGb.toStringAsFixed(2)} GB free',
          style: text.bodyMedium,
        ),
      ],
    );
  }
}
