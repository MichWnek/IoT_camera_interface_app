import 'package:camera_trap_app/data/models/theme_preference.dart';
import 'package:camera_trap_app/data/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide theme choice. The state is just the current [ThemePreference].
class SettingsCubit extends Cubit<ThemePreference> {
  SettingsCubit(this._repository) : super(ThemePreference.system);

  final SettingsRepository _repository;

  Future<void> load() async {
    final preference = await _repository.loadThemePreference();
    if (isClosed) return;
    emit(preference);
  }

  /// Switches the theme straight away, then saves the choice.
  Future<void> setThemePreference(ThemePreference preference) async {
    emit(preference);
    await _repository.saveThemePreference(preference);
  }
}
