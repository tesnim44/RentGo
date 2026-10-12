import 'package:flutter/material.dart';

ThemeData buildRentGoTheme() {
  const background = Color(0xFFF4F1EA);
  const surface = Color(0xFFFFFFFF);
  const primary = Color(0xFF0F766E);
  const accent = Color(0xFFF59E0B);
  const text = Color(0xFF102A43);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: primary,
    secondary: accent,
    surface: surface,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: background,
      foregroundColor: text,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          color: text.withValues(alpha: 0.8),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? primary : text.withValues(alpha: 0.5));
      }),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: text, letterSpacing: -1.2),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.8),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: text),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: text),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: text),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: text),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text),
    ),
  );
}
