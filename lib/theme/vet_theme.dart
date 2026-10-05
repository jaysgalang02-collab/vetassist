import 'package:flutter/material.dart';

class VetTheme {
  static const forest = Color(0xFF174D3C);
  static const mint = Color(0xFFDDEFE5);
  static const canvas = Color(0xFFF6F7F3);
  static const ink = Color(0xFF20352C);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: forest,
      primary: forest,
      onPrimary: Colors.white,
      primaryContainer: mint,
      onPrimaryContainer: forest,
      surface: canvas,
      onSurface: ink,
      onSurfaceVariant: const Color(0xFF5C6D64),
      outline: const Color(0xFF899A90),
      outlineVariant: const Color(0xFFDDE4DD),
      surfaceContainerHighest: const Color(0xFFEAF0E9),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final rounded =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      textTheme: base.textTheme
          .copyWith(
            headlineLarge: const TextStyle(
                fontSize: 34,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: ink),
            headlineMedium: const TextStyle(
                fontSize: 28,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: ink),
            titleLarge: const TextStyle(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: ink),
            titleMedium: const TextStyle(
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: ink),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.5, color: ink),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.45, color: ink),
          )
          .apply(fontFamily: base.textTheme.bodyMedium?.fontFamily),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: base.textTheme.titleLarge
            ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700, color: ink),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: scheme.outlineVariant)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: forest, width: 2)),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: base.textTheme.labelLarge
            ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        shape: rounded,
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: scheme.outlineVariant),
        shape: rounded,
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76,
        indicatorColor: mint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: base.textTheme.labelSmall?.fontFamily,
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? forest
                  : scheme.onSurfaceVariant,
            )),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: forest,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: forest,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        labelStyle: base.textTheme.labelLarge
            ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme:
          DialogThemeData(backgroundColor: Colors.white, shape: rounded),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: base.textTheme.bodyMedium
            ?.copyWith(color: Colors.white, fontSize: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
    );
  }
}
