import 'package:bloc_test/bloc_test.dart';
import 'package:camera_trap_app/data/models/theme_preference.dart';
import 'package:camera_trap_app/data/settings_repository.dart';
import 'package:camera_trap_app/state/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts by following the system theme', () {
    expect(
      SettingsCubit(InMemorySettingsRepository()).state,
      ThemePreference.system,
    );
  });

  blocTest<SettingsCubit, ThemePreference>(
    'load emits the saved preference',
    build: () =>
        SettingsCubit(InMemorySettingsRepository(ThemePreference.night)),
    act: (cubit) => cubit.load(),
    expect: () => [ThemePreference.night],
  );

  late InMemorySettingsRepository repository;

  blocTest<SettingsCubit, ThemePreference>(
    'setThemePreference switches immediately and saves the choice',
    setUp: () => repository = InMemorySettingsRepository(),
    build: () => SettingsCubit(repository),
    act: (cubit) => cubit.setThemePreference(ThemePreference.day),
    expect: () => [ThemePreference.day],
    verify: (_) async =>
        expect(await repository.loadThemePreference(), ThemePreference.day),
  );
}
