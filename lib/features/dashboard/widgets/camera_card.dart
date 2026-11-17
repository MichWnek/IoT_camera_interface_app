import 'package:camera_trap_app/features/shared/widgets/status_summary.dart';
import 'package:flutter/material.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';

class CameraCard extends StatelessWidget {
  const CameraCard({super.key, required this.cameraTrap});

  final CameraTrap cameraTrap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    List<Widget> cameraInfo = [
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cameraTrap.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium,
            ),
            const SizedBox(height: 4),
            StatusSummary(status: cameraTrap.status),
          ],
        ),
      ),
      Icon(Icons.chevron_right, color: colors.primary),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(children: cameraInfo),
      ),
    );
  }
}
