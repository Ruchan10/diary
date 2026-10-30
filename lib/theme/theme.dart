import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/settings.dart';

/// Soft, slightly wonky serif for headlines and the wordmark.
const displayFont = 'Fraunces';

/// Rounded sans for everything else.
const uiFont = 'Nunito';

/// Handwriting for the playful bits: prompts, speech bubbles, notes.
const handFont = 'Caveat';

TextStyle handStyle(double size, {Color? color, FontWeight weight = FontWeight.w700, double height = 1.15}) =>
    TextStyle(fontFamily: handFont, fontSize: size, fontWeight: weight, color: color, height: height);

@immutable
class Accent {
  const Accent(this.name, this.color);

  final String name;
  final Color color;
}

const accents = [
  Accent('Ink', Color(0xFF4F55D9)),
  Accent('Bubblegum', Color(0xFFE0457B)),
  Accent('Matcha', Color(0xFF5B8C3A)),
  Accent('Tangerine', Color(0xFFF07B2D)),
  Accent('Lagoon', Color(0xFF0097A7)),
  Accent('Grape', Color(0xFF8E4BC5)),
  Accent('Pencil', Color(0xFF5E6672)),
];

/// The wallpaper colour from Android 12+ (null where Material You isn't available).
@immutable
class DynamicSeed {
  const DynamicSeed(this.color);

  final Color? color;

  @override
  bool operator ==(Object other) => other is DynamicSeed && other.color == color;

  @override
  int get hashCode => color.hashCode;
}

Color accentSeed(SettingsController settings, {Color? dynamicSeed}) =>
    settings.dynamicColor && dynamicSeed != null
        ? dynamicSeed
        : accents[settings.accent.clamp(0, accents.length - 1)].color;

/// "Vibrant" keeps the accent punchy; the grey Pencil accent stays calm.
ColorScheme schemeFor(Color seed, Brightness brightness) => ColorScheme.fromSeed(
  seedColor: seed,
  brightness: brightness,
  dynamicSchemeVariant: seed == accents.last.color ? DynamicSchemeVariant.tonalSpot : DynamicSchemeVariant.vibrant,
);

/// Inky's body colour: always a deep ink so its white face reads in light and dark.
Color inkColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark ? Color.lerp(scheme.primaryContainer, scheme.primary, 0.25)! : scheme.primary;

ThemeData buildTheme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: uiFont);
  final t = base.textTheme;
  TextStyle? display(TextStyle? s, {double? size}) =>
      s?.copyWith(fontFamily: displayFont, fontWeight: FontWeight.w600, fontSize: size, letterSpacing: -0.3);
  TextStyle? bold(TextStyle? s, [FontWeight w = FontWeight.w700]) => s?.copyWith(fontWeight: w);

  return base.copyWith(
    textTheme: t.copyWith(
      displaySmall: display(t.displaySmall),
      headlineLarge: display(t.headlineLarge),
      headlineMedium: display(t.headlineMedium),
      headlineSmall: display(t.headlineSmall),
      titleLarge: display(t.titleLarge),
      titleMedium: bold(t.titleMedium),
      titleSmall: bold(t.titleSmall),
      labelLarge: bold(t.labelLarge),
      labelMedium: bold(t.labelMedium, FontWeight.w600),
    ),
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: display(t.titleLarge, size: 24)?.copyWith(color: scheme.onSurface),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: scheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      extendedTextStyle: const TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w800, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(textStyle: const TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w800)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w800)),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 24)),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
  );
}

/// The face the diary text is written in.
TextStyle writingStyle(WritingFont font, double size) => switch (font) {
  WritingFont.classic => TextStyle(fontFamily: 'Lora', fontSize: size, height: 1.6),
  WritingFont.clean => TextStyle(fontFamily: uiFont, fontSize: size, height: 1.6),
  WritingFont.handwritten => TextStyle(fontFamily: handFont, fontSize: size * 1.3, height: 1.35, fontWeight: FontWeight.w500),
  WritingFont.typewriter => TextStyle(fontFamily: 'CourierPrime', fontSize: size * 0.95, height: 1.6),
};
