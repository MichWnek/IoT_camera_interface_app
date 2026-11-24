import 'package:camera_trap_app/app.dart';
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
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    // Retry starts a new load, so the spinner comes back.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
