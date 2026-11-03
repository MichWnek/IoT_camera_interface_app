import 'package:flutter/material.dart';
import 'package:camera_trap_app/features/dashboard/widgets/camera_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Camera Traps', style: text.titleLarge)),
      body: ListView(
        children: const [
          CameraCard(
            name: 'Camera 1',
            batteryPercent: 67,
            sdFreeGb: 0.67,
            isOnline: true,
          ),
          CameraCard(
            name: 'Camera 2',
            batteryPercent: 1119,
            sdFreeGb: 0.564343,
            isOnline: true,
          ),
          CameraCard(
            name: 'Camera trap on a very tall maple in the forest north of that other forest that is south of a highway exit at 45km of the A1 highway',
            batteryPercent: 5,
            sdFreeGb: 0.93893827489247,
            isOnline: false,
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
