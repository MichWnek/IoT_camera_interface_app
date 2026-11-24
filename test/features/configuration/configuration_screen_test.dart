import 'package:camera_trap_app/features/configuration/view/configuration_screen.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/device_status.dart';
import 'package:camera_trap_app/data/fake/fake_camera_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('ConfigurationScreen renders correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurationScreen(
          initialConfig: const CameraConfig(
            aiThreshold: 0.5,
            pirThreshold: 1.65,
          ),
          cameraService: FakeCameraService(delay: Duration.zero),
          status: const DeviceStatus(
            batteryPercent: 80,
            sdFreeGb: 1.5,
            isOnline: true,
          ),
        ),
      ),
    );

    // Verify that the ConfigurationScreen is rendered with the correct initial values
    expect(find.text('Configuration'), findsOneWidget);
    expect(find.text('AI Threshold: 50%'), findsOneWidget);
    expect(find.text('PIR Threshold: 1.65 V'), findsOneWidget);
  });

  testWidgets('Apply & Reset start out disabled', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurationScreen(
          initialConfig: const CameraConfig(
            aiThreshold: 0.5,
            pirThreshold: 1.65,
          ),
          cameraService: FakeCameraService(delay: Duration.zero),
        ),
      ),
    );

    // Verify that the Apply and Reset buttons are disabled initially
    final applyButton = find.byKey(const Key('apply_button'));
    final resetButton = find.byKey(const Key('reset_button'));

    expect(tester.widget<ElevatedButton>(applyButton).enabled, isFalse);
    expect(tester.widget<ElevatedButton>(resetButton).enabled, isFalse);
  });

  testWidgets('Apply & Reset become enabled after changing a slider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurationScreen(
          initialConfig: const CameraConfig(
            aiThreshold: 0.5,
            pirThreshold: 1.65,
          ),
          cameraService: FakeCameraService(delay: Duration.zero),
        ),
      ),
    );

    // Change the AI Threshold slider
    final aiSlider = find.byKey(const Key('ai_threshold_slider'));
    await tester.drag(aiSlider, const Offset(50, 0)); // Drag to the right
    await tester.pumpAndSettle();

    // Verify that the Apply and Reset buttons are now enabled
    final applyButton = find.byKey(const Key('apply_button'));
    final resetButton = find.byKey(const Key('reset_button'));

    expect(tester.widget<ElevatedButton>(applyButton).enabled, isTrue);
    expect(tester.widget<ElevatedButton>(resetButton).enabled, isTrue);
  });

  testWidgets('Reset button resets sliders to initial values', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurationScreen(
          initialConfig: const CameraConfig(
            aiThreshold: 0.5,
            pirThreshold: 1.65,
          ),
          cameraService: FakeCameraService(delay: Duration.zero),
        ),
      ),
    );

    // Change the AI Threshold slider
    final aiSlider = find.byKey(const Key('ai_threshold_slider'));
    await tester.drag(aiSlider, const Offset(50, 0)); // Drag to the right
    await tester.pumpAndSettle();

    // Tap the Reset button
    final resetButton = find.byKey(const Key('reset_button'));
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    final applyButton = find.byKey(const Key('apply_button'));

    // Verify that the sliders are reset to their initial values
    expect(find.text('AI Threshold: 50%'), findsOneWidget);
    expect(find.text('PIR Threshold: 1.65 V'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(applyButton).enabled, isFalse);
    expect(tester.widget<ElevatedButton>(resetButton).enabled, isFalse);
  });

  testWidgets('Explanation text appears when no status is passed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurationScreen(
          initialConfig: const CameraConfig(
            aiThreshold: 0.5,
            pirThreshold: 1.65,
          ),
          cameraService: FakeCameraService(delay: Duration.zero),
        ),
      ),
    );
    expect(
      find.text('No status available, connect to device to retrieve status'),
      findsOneWidget,
    );
  });

  testWidgets('Reset returns to last applied change', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurationScreen(
          initialConfig: const CameraConfig(
            aiThreshold: 0.5,
            pirThreshold: 1.65,
          ),
          cameraService: FakeCameraService(delay: Duration.zero),
        ),
      ),
    );

    final applyButton = find.byKey(const Key('apply_button'));
    final aiSlider = find.byKey(const Key('ai_threshold_slider'));
    final pirSlider = find.byKey(const Key('pir_threshold_slider'));
    tester.widget<Slider>(aiSlider).onChanged!(0.35);
    tester.widget<Slider>(pirSlider).onChanged!(2.0);
    await tester.pump();

    expect(tester.widget<ElevatedButton>(applyButton).enabled, isTrue);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    final resetButton = find.byKey(const Key('reset_button'));
    await tester.drag(aiSlider, const Offset(10, 0));
    await tester.drag(pirSlider, const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<ElevatedButton>(applyButton).enabled, isTrue);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('AI Threshold: 35%'), findsOneWidget);
    expect(find.text('PIR Threshold: 2.00 V'), findsOneWidget);
  });

  testWidgets('Test button shows the echo time and is disabled meanwhile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurationScreen(
          initialConfig: const CameraConfig(
            aiThreshold: 0.5,
            pirThreshold: 1.65,
          ),
          cameraService: FakeCameraService(
            pingDelay: const Duration(milliseconds: 200),
          ),
        ),
      ),
    );

    final testButton = find.byKey(const Key('test_button'));
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
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurationScreen(
          initialConfig: const CameraConfig(
            aiThreshold: 0.5,
            pirThreshold: 1.65,
          ),
          cameraService: FakeCameraService(
            pingDelay: const Duration(seconds: 2),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('test_button')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('No response from camera'), findsOneWidget);

    // Let the abandoned 2 s ping finish so no timer is left pending.
    await tester.pump(const Duration(seconds: 1));
  });
}
