import 'package:flutter/material.dart';
import 'package:camera_trap_app/features/dashboard/widgets/camera_card.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Camera Traps', style: text.titleLarge)),
      body: ListView(
        children: [
          CameraCard(
            cameraTrap: CameraTrap(
              id: '1',
              name: 'Camera 1',
              bleMac: '00:11:22:33:44:55',
              status: DeviceStatus(
                batteryPercent: 67,
                sdFreeGb: 0.67,
                isOnline: true,
              ),
            ),
          ),
          CameraCard(
            cameraTrap: CameraTrap(
              id: '1',
              name: 'Camera 1',
              bleMac: '00:11:22:33:44:55',
              status: DeviceStatus(
                batteryPercent: 99,
                sdFreeGb: 0.39385787395,
                isOnline: false,
              ),
            ),
          ),
          CameraCard(
            cameraTrap: CameraTrap(
              id: '3',
              name: 'Camera 3',
              bleMac: '00:11:22:33:44:55',
              status: null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
