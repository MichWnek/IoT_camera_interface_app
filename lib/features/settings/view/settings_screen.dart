import 'package:camera_trap_app/data/models/theme_preference.dart';
import 'package:camera_trap_app/state/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _themeOptions = [
    (
      preference: ThemePreference.system,
      icon: Icons.brightness_auto,
      title: 'System',
      subtitle: "Follow the phone's light/dark setting",
    ),
    (
      preference: ThemePreference.day,
      icon: Icons.light_mode,
      title: 'Day',
      subtitle: 'High contrast, readable in sunlight',
    ),
    (
      preference: ThemePreference.night,
      icon: Icons.dark_mode,
      title: 'Night',
      subtitle: 'Dim red, preserves night vision',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final current = context.watch<SettingsCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: text.titleLarge)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Theme', style: text.titleMedium),
          ),
          for (final option in _themeOptions)
            ListTile(
              key: Key('theme_${option.preference.name}'),
              leading: Icon(option.icon),
              title: Text(option.title),
              subtitle: Text(option.subtitle),
              selected: option.preference == current,
              trailing: option.preference == current
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.read<SettingsCubit>().setThemePreference(
                option.preference,
              ),
            ),
        ],
      ),
    );
  }
}
