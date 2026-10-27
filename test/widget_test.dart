// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:camera_trap_app/app.dart';
import 'package:camera_trap_app/features/dashboard/widgets/camera_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App screen text display test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CameraTrapApp());

    // Verify text is displayed
    expect(find.text('Camera Traps'), findsOneWidget);
    expect(find.byType(CameraCard), findsNWidgets(3));
  });
}
