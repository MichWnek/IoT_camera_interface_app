import 'package:camera_trap_app/app.dart';
import 'package:camera_trap_app/features/configuration/view/configuration_screen.dart';
import 'package:camera_trap_app/features/dashboard/widgets/camera_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera_trap_app/data/fake/fake_camera_service.dart';

void main() {
  testWidgets('Dashboard shows a spinner, then the loaded cameras', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CameraTrapApp(cameraService: FakeCameraService(delay: Duration.zero)),
    );

    expect(find.text('Camera Traps'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(CameraCard), findsNWidgets(3));
  });

  testWidgets('Dashboard shows an error and Retry when loading fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CameraTrapApp(
        cameraService: FakeCameraService(fail: true, delay: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CameraCard), findsNothing);
    expect(find.text("Couldn't load cameras"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    // Retry starts a new load, so the spinner comes back.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('Dashboard battery updates live', (WidgetTester tester) async {
    await tester.pumpWidget(
      CameraTrapApp(cameraService: FakeCameraService(delay: Duration.zero)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Battery: 67%'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Battery: 66%'), findsOneWidget);
  });

  testWidgets('Tapping a camera opens its live configuration, back returns', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CameraTrapApp(cameraService: FakeCameraService(delay: Duration.zero)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Camera 1'));
    await tester.pumpAndSettle();

    expect(find.byType(ConfigurationScreen), findsOneWidget);
    expect(find.text('Camera 1'), findsOneWidget);
    expect(find.text('Battery: 67%'), findsOneWidget);

    // The configuration screen follows the same live status.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Battery: 66%'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(ConfigurationScreen), findsNothing);
    expect(find.byType(CameraCard), findsNWidgets(3));
  });
}
