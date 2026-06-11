import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Unified permission flow for Private Space media features.
enum PrivatePermissionKind {
  photoLibrary,
  camera,
  microphone,
}

class PrivatePermissionHelper {
  static Permission _permissionFor(PrivatePermissionKind kind) {
    return switch (kind) {
      PrivatePermissionKind.photoLibrary => Permission.photos,
      PrivatePermissionKind.camera => Permission.camera,
      PrivatePermissionKind.microphone => Permission.microphone,
    };
  }

  static String _label(PrivatePermissionKind kind) {
    return switch (kind) {
      PrivatePermissionKind.photoLibrary => 'Photo library',
      PrivatePermissionKind.camera => 'Camera',
      PrivatePermissionKind.microphone => 'Microphone',
    };
  }

  /// Returns true when the permission is granted (or limited on iOS photos).
  static Future<bool> ensure(
    BuildContext context,
    PrivatePermissionKind kind,
  ) async {
    final permission = _permissionFor(kind);
    var status = await permission.status;

    if (status.isGranted || status.isLimited) return true;

    if (status.isDenied) {
      status = await permission.request();
      if (status.isGranted || status.isLimited) return true;
    }

    if (!context.mounted) return false;

    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(context, kind);
      return false;
    }

    await _showDeniedSnack(context, kind);
    return false;
  }

  static Future<void> _showDeniedSnack(
    BuildContext context,
    PrivatePermissionKind kind,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_label(kind)} access is required for this action.'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => ensure(context, kind),
        ),
      ),
    );
  }

  static Future<void> _showSettingsDialog(
    BuildContext context,
    PrivatePermissionKind kind,
  ) async {
    final label = _label(kind);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121A26),
        title: Text(
          '$label blocked',
          style: const TextStyle(color: Color(0xFFF6E6B3)),
        ),
        content: Text(
          'Please enable $label in system settings to continue.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Color(0xFFE2BE57)),
            ),
          ),
        ],
      ),
    );
  }
}
