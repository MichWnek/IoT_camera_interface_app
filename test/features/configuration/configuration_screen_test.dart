import 'package:camera_trap_app/features/configuration/view/configuration_screen.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('ConfigurationScreen renders correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ConfigurationScreen(
          initialConfig: CameraConfig(aiThreshold: 0.5, pirThreshold: 1.65),
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
      const MaterialApp(
        home: ConfigurationScreen(
          initialConfig: CameraConfig(aiThreshold: 0.5, pirThreshold: 1.65),
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
      const MaterialApp(
        home: ConfigurationScreen(
          initialConfig: CameraConfig(aiThreshold: 0.5, pirThreshold: 1.65),
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
      const MaterialApp(
        home: ConfigurationScreen(
          initialConfig: CameraConfig(aiThreshold: 0.5, pirThreshold: 1.65),
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
}
