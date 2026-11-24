import 'package:camera_trap_app/data/camera_service.dart';
import 'package:camera_trap_app/data/fake/fake_camera_service.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/features/configuration/view/configuration_screen.dart';
import 'package:camera_trap_app/state/cameras_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows the configuration screen with the providers the app normally gives
/// it, and waits for the cameras to load.
Future<void> pumpConfigurationScreen(
  WidgetTester tester, {
  FakeCameraService? service,
  String cameraId = '1',
}) async {
  final cameraService = service ?? FakeCameraService(delay: Duration.zero);
  await tester.pumpWidget(
    RepositoryProvider<CameraService>.value(
      value: cameraService,
      child: BlocProvider(
        create: (_) => CamerasCubit(cameraService)..load(),
        child: MaterialApp(
          home: ConfigurationScreen(
            cameraId: cameraId,
            initialConfig: const CameraConfig(
              aiThreshold: 0.5,
              pirThreshold: 1.65,
            ),
          ),
        ),
      ),
    ),
  );
  // The cubit is created lazily during the first build, so loading only
  // starts then; settle until the loaded cameras are on screen.
  await tester.pumpAndSettle();
}

void main() {
  final applyButton = find.byKey(const Key('apply_button'));
  final resetButton = find.byKey(const Key('reset_button'));
  final testButton = find.byKey(const Key('test_button'));
  final aiSlider = find.byKey(const Key('ai_threshold_slider'));
  final pirSlider = find.byKey(const Key('pir_threshold_slider'));

  testWidgets('ConfigurationScreen renders correctly', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(tester);

    expect(find.text('Configuration'), findsOneWidget);
    expect(find.text('Camera 1'), findsOneWidget);
    expect(find.text('Battery: 67%'), findsOneWidget);
    expect(find.text('AI Threshold: 50%'), findsOneWidget);
    expect(find.text('PIR Threshold: 1.65 V'), findsOneWidget);
  });

  testWidgets('Status updates live while the screen is open', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(tester);
    expect(find.text('Battery: 67%'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Battery: 66%'), findsOneWidget);
  });

  testWidgets('Explanation text appears for a camera that never connected', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(tester, cameraId: '3');

    expect(
      find.text('No status available, connect to device to retrieve status'),
      findsOneWidget,
    );
  });

  testWidgets('Apply & Reset start out disabled', (WidgetTester tester) async {
    await pumpConfigurationScreen(tester);

    expect(tester.widget<ElevatedButton>(applyButton).enabled, isFalse);
    expect(tester.widget<ElevatedButton>(resetButton).enabled, isFalse);
  });

  testWidgets('Apply & Reset become enabled after changing a slider', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(tester);

    await tester.drag(aiSlider, const Offset(50, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<ElevatedButton>(applyButton).enabled, isTrue);
    expect(tester.widget<ElevatedButton>(resetButton).enabled, isTrue);
  });

  testWidgets('Reset button resets sliders to initial values', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(tester);

    await tester.drag(aiSlider, const Offset(50, 0));
    await tester.pumpAndSettle();
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('AI Threshold: 50%'), findsOneWidget);
    expect(find.text('PIR Threshold: 1.65 V'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(applyButton).enabled, isFalse);
    expect(tester.widget<ElevatedButton>(resetButton).enabled, isFalse);
  });

  testWidgets('Reset returns to last applied change', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(tester);

    tester.widget<Slider>(aiSlider).onChanged!(0.35);
    tester.widget<Slider>(pirSlider).onChanged!(2.0);
    await tester.pump();

    expect(tester.widget<ElevatedButton>(applyButton).enabled, isTrue);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    await tester.drag(aiSlider, const Offset(10, 0));
    await tester.drag(pirSlider, const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<ElevatedButton>(applyButton).enabled, isTrue);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('AI Threshold: 35%'), findsOneWidget);
    expect(find.text('PIR Threshold: 2.00 V'), findsOneWidget);
  });

  testWidgets('Apply sends the config and confirms it', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(tester);

    tester.widget<Slider>(aiSlider).onChanged!(0.35);
    await tester.pump();
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    expect(find.text('Configuration applied'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(applyButton).enabled, isFalse);
    expect(tester.widget<ElevatedButton>(resetButton).enabled, isFalse);
  });

  testWidgets('A failed apply keeps the changes so the user can retry', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(
      tester,
      service: FakeCameraService(delay: Duration.zero, failApply: true),
    );

    tester.widget<Slider>(aiSlider).onChanged!(0.35);
    await tester.pump();
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    expect(find.text('Could not apply configuration'), findsOneWidget);
    expect(find.text('AI Threshold: 35%'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(applyButton).enabled, isTrue);
  });

  testWidgets('Test button shows the echo time and is disabled meanwhile', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(
      tester,
      service: FakeCameraService(
        delay: Duration.zero,
        pingDelay: const Duration(milliseconds: 200),
      ),
    );

    await tester.tap(testButton);
    await tester.pump();

    expect(tester.widget<OutlinedButton>(testButton).enabled, isFalse);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.textContaining('Echo in'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(testButton).enabled, isTrue);
  });

  testWidgets('Test button reports no response when the ping times out', (
    WidgetTester tester,
  ) async {
    await pumpConfigurationScreen(
      tester,
      service: FakeCameraService(
        delay: Duration.zero,
        pingDelay: const Duration(seconds: 2),
      ),
    );

    await tester.tap(testButton);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('No response from camera'), findsOneWidget);

    // Let the abandoned 2 s ping finish so no timer is left pending.
    await tester.pump(const Duration(seconds: 1));
  });
}
