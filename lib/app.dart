import 'package:camera_trap_app/data/ble/ble_adapter.dart';
import 'package:camera_trap_app/data/camera_service.dart';
import 'package:camera_trap_app/data/models/theme_preference.dart';
import 'package:camera_trap_app/data/settings_repository.dart';
import 'package:camera_trap_app/features/dashboard/view/dashboard_screen.dart';
import 'package:camera_trap_app/core/theme/app_theme.dart';
import 'package:camera_trap_app/state/bluetooth_cubit.dart';
import 'package:camera_trap_app/state/cameras_cubit.dart';
import 'package:camera_trap_app/state/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CameraTrapApp extends StatelessWidget {
  const CameraTrapApp({
    super.key,
    required this.cameraService,
    required this.settingsRepository,
    required this.bleAdapter,
  });

  final CameraService cameraService;
  final SettingsRepository settingsRepository;
  final BleAdapter bleAdapter;

  static ThemeMode _themeMode(ThemePreference preference) =>
      switch (preference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.day => ThemeMode.light,
        ThemePreference.night => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) {
    // Provided above MaterialApp so screens opened with Navigator.push,
    // which sit under the Navigator rather than the screen that opened
    // them, can still find the service and the cubits.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CameraService>.value(value: cameraService),
        RepositoryProvider<BleAdapter>.value(value: bleAdapter),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CamerasCubit(cameraService)..load()),
          BlocProvider(
            create: (_) => SettingsCubit(settingsRepository)..load(),
          ),
          // Lazy: only checks Bluetooth once a screen needs it, so the app
          // doesn't touch Bluetooth at startup.
          BlocProvider(create: (_) => BluetoothCubit(bleAdapter)),
        ],
        child: BlocBuilder<SettingsCubit, ThemePreference>(
          builder: (context, preference) => MaterialApp(
            title: 'Camera Traps',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.day,
            darkTheme: AppTheme.night,
            themeMode: _themeMode(preference),
            home: const DashboardScreen(),
          ),
        ),
      ),
    );
  }
}
