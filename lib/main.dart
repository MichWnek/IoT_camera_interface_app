import 'package:flutter/material.dart';
import 'package:camera_trap_app/app.dart';
import 'package:camera_trap_app/data/fake/fake_camera_service.dart';
import 'package:camera_trap_app/data/settings_repository.dart';

void main() {
  runApp(
    CameraTrapApp(
      cameraService: FakeCameraService(),
      settingsRepository: InMemorySettingsRepository(),
    ),
  );
}
