import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

/// Central font strategy for body / dialog copy (not decorative brand fonts).
///
/// iOS uses the system SF Pro Text face; other platforms use bundled `'SF Pro'`.
abstract final class AppTypography {
  static String get bodyFontFamily {
    if (kIsWeb) return 'SF Pro';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return '.SF Pro Text';
      default:
        return 'SF Pro';
    }
  }
  /// Default body style — always sets [bodyFontFamily].
  static TextStyle body({
    Color? color,
    double? size,
    FontWeight? weight,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: bodyFontFamily,
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Shared dialog title semantics (size/weight only — color passed by caller).
  static TextStyle dialogTitle({Color? color}) => body(
        color: color,
        size: 17,
        weight: FontWeight.w600,
        height: 1.25,
      );
}
