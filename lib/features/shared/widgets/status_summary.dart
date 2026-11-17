import 'package:flutter/material.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

class StatusSummary extends StatelessWidget {
  final DeviceStatus? _status;

  const StatusSummary({super.key, this._status});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_status == null) {
      return Text(
        'No status available, connect to device to retrieve status',
        style: text.bodyMedium,
      );
    } else {
      DeviceStatus status = _status;
      return _buildStatusSummary(context, status);
    }
  }

  Widget _buildStatusSummary(BuildContext context, DeviceStatus status) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        Icon(
          status.isOnline ? Icons.bluetooth : Icons.block_rounded,
          color: status.isOnline ? colors.primary : colors.outline,
        ),
        Text(
          'Battery: ${status.batteryPercent}%',
          style: text.bodyMedium?.copyWith(
            color: status.isLowBattery == true ? colors.error : colors.primary,
            fontWeight: status.isLowBattery == true
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        Text(
          'SD: ${status.sdFreeGb.toStringAsFixed(2)} GB free',
          style: text.bodyMedium,
        ),
      ],
    );
  }
}
