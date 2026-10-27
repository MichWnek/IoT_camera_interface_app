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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.brightness_1_rounded,
              color: isOnline ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Battery $batteryPercent%'),
                  Text('SD ${sdFreeGb.toStringAsFixed(2)} GB free'),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
