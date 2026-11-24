import 'package:camera_trap_app/app.dart';
import 'package:camera_trap_app/core/theme/app_theme.dart';
import 'package:camera_trap_app/data/fake/fake_camera_service.dart';
import 'package:camera_trap_app/data/models/theme_preference.dart';
import 'package:camera_trap_app/data/settings_repository.dart';
import 'package:camera_trap_app/features/settings/view/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  ThemePreference saved = ThemePreference.system,
}) async {
  await tester.pumpWidget(
    CameraTrapApp(
      cameraService: FakeCameraService(delay: Duration.zero),
      settingsRepository: InMemorySettingsRepository(saved),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

/// The colour scheme actually in use on screen right now.
ColorScheme activeScheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).last)).colorScheme;

bool isChecked(WidgetTester tester, ThemePreference preference) => tester
    .widget<ListTile>(find.byKey(Key('theme_${preference.name}')))
    .selected;

void main() {
  testWidgets('The settings button opens the settings screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(isChecked(tester, ThemePreference.system), isTrue);
  });

  testWidgets('Choosing Night switches the whole app to the night theme', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);

    await tester.tap(find.text('Night'));
    await tester.pumpAndSettle();

    expect(isChecked(tester, ThemePreference.night), isTrue);
    expect(isChecked(tester, ThemePreference.system), isFalse);
    expect(activeScheme(tester).surface, AppTheme.night.colorScheme.surface);

    // The dashboard behind it is in night mode too.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(activeScheme(tester).surface, AppTheme.night.colorScheme.surface);
  });

  testWidgets('Choosing Day overrides a dark phone setting', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);
    // Following the system, the dark phone setting gives the night theme.
    expect(activeScheme(tester).surface, AppTheme.night.colorScheme.surface);

    await openSettings(tester);
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    expect(activeScheme(tester).surface, AppTheme.day.colorScheme.surface);
  });

  testWidgets('The app starts with the saved preference', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, saved: ThemePreference.night);

    expect(activeScheme(tester).surface, AppTheme.night.colorScheme.surface);
  });
}
