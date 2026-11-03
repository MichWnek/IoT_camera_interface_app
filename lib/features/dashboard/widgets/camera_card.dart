import 'package:flutter/material.dart';

class CameraCard extends StatelessWidget {
  const CameraCard({
    super.key,
    required this.name,
    required this.batteryPercent,
    required this.sdFreeGb,
    required this.isOnline,
  });

  final String name;
  final int batteryPercent;
  final double sdFreeGb;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      color: colors.secondary,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isOnline ? Icons.bluetooth : Icons.block_rounded,
              color: isOnline ? colors.onPrimary : colors.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  Text(
                    'Battery $batteryPercent%',
                    style: text.bodyMedium?.copyWith(
                      color: batteryPercent > 20
                          ? colors.onPrimary
                          : colors.error,
                    ),
                  ),
                  Text(
                    'SD ${sdFreeGb.toStringAsFixed(2)} GB free',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onPrimary),
          ],
        ),
      ),
    );
  }
}
