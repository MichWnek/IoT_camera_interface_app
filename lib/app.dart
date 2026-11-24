import 'package:camera_trap_app/data/camera_service.dart';
import 'package:camera_trap_app/features/dashboard/view/dashboard_screen.dart';
import 'package:camera_trap_app/core/theme/app_theme.dart';
import 'package:camera_trap_app/state/cameras_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CameraTrapApp extends StatelessWidget {
  const CameraTrapApp({super.key, required this.cameraService});
  final CameraService cameraService;

  @override
  Widget build(BuildContext context) {
    // Provided above MaterialApp so screens opened with Navigator.push,
    // which sit under the Navigator rather than the screen that opened
    // them, can still find the service and the cubit.
    return RepositoryProvider<CameraService>.value(
      value: cameraService,
      child: BlocProvider(
        create: (_) => CamerasCubit(cameraService)..load(),
        child: MaterialApp(
          title: 'Camera Traps',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.day,
          darkTheme: AppTheme.night,
          themeMode: ThemeMode.system,
          home: const DashboardScreen(),
        ),
      ),
    );
  }
}
