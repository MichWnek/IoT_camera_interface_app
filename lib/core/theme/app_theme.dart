import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get day => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      //looks fine, woody tones resemble
      seedColor: const Color.fromARGB(255, 64, 50, 1),
      contrastLevel: 1.0,
    ),
  );

  static ThemeData get night => ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: Color.fromARGB(255, 0, 0, 0),
      onPrimary: Color.fromARGB(255, 185, 0, 0),
      surface: Color.fromARGB(255, 0, 0, 0),
      onSurface: Color.fromARGB(255, 227, 0, 0),
      error: Color.fromARGB(255, 255, 1, 1),
      outline: Color.fromARGB(255, 209, 0, 0),
      secondary: Color.fromARGB(51, 98, 0, 0),
    ),
  );
}
