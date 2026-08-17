import 'package:flutter/material.dart';

final class WaypointColors {
  static const canvas = Color(0xFFF7F5F0);
  static const paper = Color(0xFFFFFEFB);
  static const ink = Color(0xFF18332B);
  static const muted = Color(0xFF718078);
  static const line = Color(0xFFE5E8E2);
  static const mint = Color(0xFFB7D9D0);
  static const mintDeep = Color(0xFF2D6B58);
  static const peach = Color(0xFFF3D4B2);
  static const lavender = Color(0xFFD7C5E9);
  static const sky = Color(0xFFC9D8E8);
  static const danger = Color(0xFFAD554C);

  const WaypointColors._();
}

Color waypointColor(String value) {
  final normalized = value.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

ThemeData waypointTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: WaypointColors.mintDeep,
        brightness: Brightness.light,
      ).copyWith(
        primary: WaypointColors.mintDeep,
        onPrimary: Colors.white,
        surface: WaypointColors.paper,
        onSurface: WaypointColors.ink,
        outline: WaypointColors.line,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: WaypointColors.canvas,
    canvasColor: WaypointColors.canvas,
    dividerColor: WaypointColors.line,
    fontFamily: 'Avenir Next',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: WaypointColors.ink,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.3,
        height: 1.08,
      ),
      headlineMedium: TextStyle(
        color: WaypointColors.ink,
        fontSize: 27,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      titleLarge: TextStyle(
        color: WaypointColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        color: WaypointColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: WaypointColors.ink,
        fontSize: 16,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        color: WaypointColors.muted,
        fontSize: 14,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: WaypointColors.canvas,
      foregroundColor: WaypointColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WaypointColors.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: WaypointColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: WaypointColors.mintDeep, width: 1.5),
      ),
      hintStyle: TextStyle(color: WaypointColors.muted),
    ),
    cardTheme: const CardThemeData(
      color: WaypointColors.paper,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
  );
}
