import 'package:flutter/material.dart';

/// Shared Archive glass-card page title typography (iOS SF Pro default tracking).
abstract final class ArchiveTypography {
  static const TextStyle pageTitle = TextStyle(
    color: Colors.white,
    fontSize: 25,
    fontFamily: 'SF Pro',
    fontWeight: FontWeight.bold,
    letterSpacing: 0,
  );
}
