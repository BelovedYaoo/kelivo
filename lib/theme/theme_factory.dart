import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

// CJK/Latin fallback to stabilize fontWeight (w100-w600) on iOS for Chinese
const List<String> kDefaultFontFamilyFallback = <String>[
  'PingFang SC',
  'Heiti SC',
  'Hiragino Sans GB',
  'Roboto',
];

const List<String> kAndroidFontFamilyFallback = <String>['sans-serif'];

// Windows-specific font fallback to fix Chinese font rendering issues
const List<String> kWindowsFontFamilyFallback = <String>[
  'Twemoji Country Flags',
  'Segoe UI',
  'Microsoft YaHei',
  'SimHei',
];

// Get platform-appropriate font fallback list
List<String> getPlatformFontFallback() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return kAndroidFontFamilyFallback;
  }
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return kWindowsFontFamilyFallback;
  }
  return kDefaultFontFamilyFallback;
}

// Internal helper for theme building
List<String> _getPlatformFontFallback() => getPlatformFontFallback();

TextTheme _withFontFallback(TextTheme base, List<String> fallback) {
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFamilyFallback: fallback);
  return base.copyWith(
    displayLarge: f(base.displayLarge),
    displayMedium: f(base.displayMedium),
    displaySmall: f(base.displaySmall),
    headlineLarge: f(base.headlineLarge),
    headlineMedium: f(base.headlineMedium),
    headlineSmall: f(base.headlineSmall),
    titleLarge: f(base.titleLarge),
    titleMedium: f(base.titleMedium),
    titleSmall: f(base.titleSmall),
    bodyLarge: f(base.bodyLarge),
    bodyMedium: f(base.bodyMedium),
    bodySmall: f(base.bodySmall),
    labelLarge: f(base.labelLarge),
    labelMedium: f(base.labelMedium),
    labelSmall: f(base.labelSmall),
  );
}

ThemeData buildLightTheme(ColorScheme? dynamicScheme) {
  final fontFallback = _getPlatformFontFallback();
  final scheme =
      (dynamicScheme?.harmonized()) ??
      const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF4D5C92),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFDCE1FF),
        onPrimaryContainer: Color(0xFF03174B),
        secondary: Color(0xFF595D72),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFDEE1F9),
        onSecondaryContainer: Color(0xFF161B2C),
        tertiary: Color(0xFF75546F),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFD7F6),
        onTertiaryContainer: Color(0xFF2C122A),
        error: Color(0xFFBB0947),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFDDADE),
        onErrorContainer: Color(0xFF400013),
        // background: Color(0xFFFEFBFF),
        // onBackground: Color(0xFF1A1B21),
        surface: Color(0xFFFEFBFF),
        onSurface: Color(0xFF1A1B21),
        // surfaceVariant: Color(0xFFE2E1EC),
        onSurfaceVariant: Color(0xFF45464F),
        outline: Color(0xFF75757F),
        outlineVariant: Color(0xFFC6C6D0),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFF2F3036),
        onInverseSurface: Color(0xFFF1F0F7),
        inversePrimary: Color(0xFFB6C4FF),
        surfaceTint: Color(0xFF4D5C92),
      );
  // _logColorScheme('Light ${dynamicScheme != null ? 'Dynamic' : 'Static'}', scheme);

  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontSize: 14,
        fontWeight: AppFontWeights.medium,
        fontFamilyFallback: fontFallback,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withValues(alpha: 0.5),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.black,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: AppFontWeights.semibold,
      ).copyWith(fontFamilyFallback: fontFallback),
      iconTheme: const IconThemeData(color: Colors.black),
      actionsIconTheme: const IconThemeData(color: Colors.black),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    ),
  );
  return theme.copyWith(
    textTheme: _withFontFallback(theme.textTheme, fontFallback),
    primaryTextTheme: _withFontFallback(theme.primaryTextTheme, fontFallback),
  );
}

// New: Build themes from a provided static palette (with optional dynamic override)
ThemeData buildLightThemeForScheme(
  ColorScheme staticScheme, {
  ColorScheme? dynamicScheme,
  bool pureBackground = false,
}) {
  final fontFallback = _getPlatformFontFallback();
  var scheme = (dynamicScheme?.harmonized()) ?? staticScheme;
  if (pureBackground) {
    scheme = scheme.copyWith(
      surface: const Color(0xFFFFFFFF),
      inverseSurface: const Color(0xFF000000),
      onInverseSurface: const Color(0xFFFFFFFF),
    );
  }
  // Align logging behavior with buildLightTheme so diagnostics are consistent.
  // _logColorScheme('Light ${dynamicScheme != null ? 'Dynamic' : 'Static'}', scheme);
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontSize: 14,
        fontWeight: AppFontWeights.medium,
        fontFamilyFallback: fontFallback,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withValues(alpha: 0.5),
    ),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surface),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.black,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: AppFontWeights.semibold,
      ).copyWith(fontFamilyFallback: fontFallback),
      iconTheme: const IconThemeData(color: Colors.black),
      actionsIconTheme: const IconThemeData(color: Colors.black),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: scheme.surface,
      ),
    ),
  );
  return theme.copyWith(
    textTheme: _withFontFallback(theme.textTheme, fontFallback),
    primaryTextTheme: _withFontFallback(theme.primaryTextTheme, fontFallback),
    canvasColor: scheme.surface,
  );
}

ThemeData buildDarkTheme(ColorScheme? dynamicScheme) {
  final fontFallback = _getPlatformFontFallback();
  final scheme =
      (dynamicScheme?.harmonized()) ??
      const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFB6C4FF),
        onPrimary: Color(0xFF1D2D61),
        primaryContainer: Color(0xFF354479),
        onPrimaryContainer: Color(0xFFDCE1FF),
        secondary: Color(0xFFC2C5DD),
        onSecondary: Color(0xFF2B3042),
        secondaryContainer: Color(0xFF424659),
        onSecondaryContainer: Color(0xFFDEE1F9),
        tertiary: Color(0xFFE3BADA),
        onTertiary: Color(0xFF432740),
        tertiaryContainer: Color(0xFF5B3D57),
        onTertiaryContainer: Color(0xFFFFD7F6),
        error: Color(0xFFFCB4BD),
        onError: Color(0xFF670023),
        errorContainer: Color(0xFF910034),
        onErrorContainer: Color(0xFFFCB4BD),
        // background: Color(0xFF1A1B21),
        // onBackground: Color(0xFFE3E1E9),
        surface: Color(0xFF1A1B21),
        onSurface: Color(0xFFE3E1E9),
        // surfaceVariant: Color(0xFF45464F),
        onSurfaceVariant: Color(0xFFC6C6D0),
        outline: Color(0xFF90909A),
        outlineVariant: Color(0xFF45464F),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFFE3E1E9),
        onInverseSurface: Color(0xFF2F3036),
        inversePrimary: Color(0xFF4D5C92),
        surfaceTint: Color(0xFFB6C4FF),
      );
  // _logColorScheme('Dark ${dynamicScheme != null ? 'Dynamic' : 'Static'}', scheme);

  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontSize: 14,
        fontWeight: AppFontWeights.medium,
        fontFamilyFallback: fontFallback,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withValues(alpha: 0.6),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: AppFontWeights.semibold,
      ).copyWith(fontFamilyFallback: fontFallback),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    ),
  );
  return theme.copyWith(
    textTheme: _withFontFallback(theme.textTheme, fontFallback),
    primaryTextTheme: _withFontFallback(theme.primaryTextTheme, fontFallback),
  );
}

ThemeData buildDarkThemeForScheme(
  ColorScheme staticScheme, {
  ColorScheme? dynamicScheme,
  bool pureBackground = false,
}) {
  final fontFallback = _getPlatformFontFallback();
  var scheme = (dynamicScheme?.harmonized()) ?? staticScheme;
  if (pureBackground) {
    scheme = scheme.copyWith(
      surface: const Color(0xFF000000),
      inverseSurface: const Color(0xFFFFFFFF),
      onInverseSurface: const Color(0xFF000000),
    );
  }
  // Align logging behavior with buildDarkTheme so diagnostics are consistent.
  // _logColorScheme('Dark ${dynamicScheme != null ? 'Dynamic' : 'Static'}', scheme);
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontSize: 14,
        fontWeight: AppFontWeights.medium,
        fontFamilyFallback: fontFallback,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withValues(alpha: 0.6),
    ),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surface),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: AppFontWeights.semibold,
      ).copyWith(fontFamilyFallback: fontFallback),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: scheme.surface,
      ),
    ),
  );
  return theme.copyWith(
    textTheme: _withFontFallback(theme.textTheme, fontFallback),
    primaryTextTheme: _withFontFallback(theme.primaryTextTheme, fontFallback),
    canvasColor: scheme.surface,
  );
}
