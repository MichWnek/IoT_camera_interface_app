import 'package:camera_trap_app/features/dashboard/view/dashboard_screen.dart';
import 'package:camera_trap_app/core/theme/app_theme.dart';
import 'package:camera_trap_app/data/fake/fake_camera_service.dart';
import 'package:flutter/material.dart';

class CameraTrapApp extends StatelessWidget {
  const CameraTrapApp({
    super.key,
    required this.cameraService,
  });
  final FakeCameraService cameraService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Traps',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.day,
      darkTheme: AppTheme.night,
      themeMode: ThemeMode.system,
      home: DashboardScreen(cameraService: cameraService,),
    );
  }
}
