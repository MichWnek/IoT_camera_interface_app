import 'package:flutter/material.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';

class CameraCard extends StatelessWidget {
  const CameraCard({super.key, this.cameraTrap});

  final CameraTrap? cameraTrap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    List<Widget> statusBar = [
      Icon(
        cameraTrap?.status?.isOnline == true
            ? Icons.bluetooth
            : Icons.block_rounded,
        color: cameraTrap?.status?.isOnline == true
            ? colors.primary
            : colors.outline,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cameraTrap?.name ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium,
            ),
            Text(
              'Battery ${cameraTrap?.status?.batteryPercent}%',
              style: text.bodyMedium?.copyWith(
                color: cameraTrap?.status?.isLowBattery == true
                    ? colors.error
                    : colors.primary,
                fontWeight: cameraTrap?.status?.isLowBattery == true
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            Text(
              'SD ${cameraTrap?.status?.sdFreeGb.toStringAsFixed(2)} GB free',
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
      Icon(Icons.chevron_right, color: colors.primary),
    ];
    statusBar = [
      Icon(
        cameraTrap?.status?.isOnline == true
            ? Icons.bluetooth
            : Icons.block_rounded,
        color: cameraTrap?.status?.isOnline == true
            ? colors.primary
            : colors.outline,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cameraTrap?.name ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium,
            ),
            Text(
              'Battery ${cameraTrap?.status?.batteryPercent}%',
              style: text.bodyMedium?.copyWith(
                color: cameraTrap?.status?.isLowBattery == true
                    ? colors.error
                    : colors.primary,
                fontWeight: cameraTrap?.status?.isLowBattery == true
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            Text(
              'SD ${cameraTrap?.status?.sdFreeGb.toStringAsFixed(2)} GB free',
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
      Icon(Icons.chevron_right, color: colors.primary),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(children: statusBar),
      ),
    );
  }
}
