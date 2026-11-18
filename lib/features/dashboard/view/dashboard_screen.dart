import 'package:camera_trap_app/data/fake/fake_camera_service.dart';
import 'package:flutter/material.dart';
import 'package:camera_trap_app/features/dashboard/widgets/camera_card.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.cameraService
  });

  final FakeCameraService cameraService;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<CameraTrap>> _cameraFuture;

  @override
  void initState() {
    super.initState();
    _cameraFuture = widget.cameraService.loadCameras();
  }

  void _retry() {
    setState(() {
      _cameraFuture = widget.cameraService.loadCameras();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    
    return Scaffold(
      appBar: AppBar(title: Text('Camera Traps', style: text.titleLarge)),
      body: FutureBuilder<List<CameraTrap>>(
        future: _cameraFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Failed: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: () => _retry(),
                    child: const Text('Retry')
                  ),
                ]
              )
            );
          }
          final cameras = snapshot.requireData;
          return ListView.builder(
            itemCount: cameras.length,
            itemBuilder: (context, index) => CameraCard(cameraTrap: cameras[index]),
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
