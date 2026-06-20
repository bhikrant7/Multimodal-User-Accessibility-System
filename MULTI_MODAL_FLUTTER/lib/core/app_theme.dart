import 'package:flutter/material.dart';

class SentinelTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF1CE8B5),
      onPrimary: Colors.black,
      secondary: Color(0xFF4B80FF),
      onSecondary: Colors.white,
      // background: Color(0xFF08101C),
      surface: Color(0xFF111A26),
      onSurface: Colors.white,
      error: Color(0xFFFF5A5F),
    ),
    scaffoldBackgroundColor: const Color(0xFF050B13),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF07101B),
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF0F1723),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111E2D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minimumSize: const Size(160, 52),
      ),
    ),
  );
}
