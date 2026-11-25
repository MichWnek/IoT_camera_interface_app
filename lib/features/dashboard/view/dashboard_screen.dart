import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/features/configuration/view/configuration_screen.dart';
import 'package:camera_trap_app/features/dashboard/widgets/camera_card.dart';
import 'package:camera_trap_app/features/nearby/view/nearby_devices_screen.dart';
import 'package:camera_trap_app/features/settings/view/settings_screen.dart';
import 'package:camera_trap_app/state/cameras_cubit.dart';
import 'package:camera_trap_app/state/cameras_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _openConfiguration(BuildContext context, CameraTrap camera) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfigurationScreen(
          cameraId: camera.id,
          initialConfig: CameraConfig.defaults,
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Traps', style: text.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_searching),
            tooltip: 'Nearby devices',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NearbyDevicesScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: BlocBuilder<CamerasCubit, CamerasState>(
        builder: (context, state) => switch (state) {
          CamerasLoading() => const Center(child: CircularProgressIndicator()),
          CamerasError(:final message) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.read<CamerasCubit>().load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          CamerasLoaded(:final cameras) when cameras.isEmpty => const Center(
            child: Text('No cameras yet, tap + to add one'),
          ),
          CamerasLoaded(:final cameras) => ListView.builder(
            itemCount: cameras.length,
            itemBuilder: (context, index) => CameraCard(
              cameraTrap: cameras[index],
              onTap: () => _openConfiguration(context, cameras[index]),
            ),
          ),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
