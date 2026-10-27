import 'package:camera_trap_app/features/dashboard/view/dashboard_screen.dart';

import 'package:flutter/material.dart';

class CameraTrapApp extends StatelessWidget {
  const CameraTrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Camera Traps',
      debugShowCheckedModeBanner: false,
      home: DashboardScreen(),
    );
  }
}
