import 'package:flutter/material.dart';
import 'package:pupu/core/constants.dart';

/// Pupu App - 宇宙主题（深夜模式）
/// 深蓝渐变、柔和、低饱和

class AppTheme {
  static const Color deepBlue = Color(colorDeepBlue);
  static const Color starBlue = Color(colorStarBlue);
  static const Color waterBlue = Color(colorWaterBlue);
  static const Color softWhite = Color(colorSoftWhite);
  // Backwards-compatible alias used across the app.
  static const Color primary = waterBlue;
  static const Color onPrimary = softWhite;

  static ThemeData get night {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: waterBlue,
        secondary: softWhite.withValues(alpha: 0.6),
        surface: starBlue,
        onPrimary: softWhite,
        onSecondary: deepBlue,
        onSurface: softWhite,
        onSurfaceVariant: softWhite.withValues(alpha: 0.8),
        outline: softWhite.withValues(alpha: 0.3),
      ),
      scaffoldBackgroundColor: deepBlue,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: softWhite,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: starBlue.withValues(alpha: 0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: waterBlue,
          foregroundColor: softWhite,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: starBlue.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  /// 兼容：原 light 别名指向 night
  static ThemeData get light => night;
}
