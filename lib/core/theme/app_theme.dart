import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get day => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      //looks fine, woody tones resemble nature
      seedColor: const Color.fromARGB(255, 64, 50, 1),
      contrastLevel: 1.0,
    ),
  );

  static ThemeData get night => ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: Color.fromARGB(255, 255, 1, 1),
      onPrimary: Color.fromARGB(255, 0, 0, 0),
      surface: Color.fromARGB(255, 0, 0, 0),
      onSurface: Color.fromARGB(255, 255, 0, 0),
      error: Color.fromARGB(255, 255, 1, 1),
      outline: Color.fromARGB(255, 200, 0, 0),
      surfaceContainerLow: Color.fromARGB(232, 46, 0, 0),
    ),
  );
}
