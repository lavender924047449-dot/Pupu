import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Media permissions used by Private Space features.
enum PrivatePermissionKind {
  photoLibrary,
  camera,
  microphone,
}

/// Semantic outcome of [PrivatePermissionHelper.ensure] — UI layer maps to dialogs/snacks.
enum PrivatePermissionResult {
  granted,
  deniedRetryable,
  deniedPermanently,
}

/// Permission query/request only — no UI (see PS-011 / PLAN-DIALOG-001).
class PrivatePermissionHelper {
  static Permission _permissionFor(PrivatePermissionKind kind) {
    return switch (kind) {
      PrivatePermissionKind.photoLibrary => Permission.photos,
      PrivatePermissionKind.camera => Permission.camera,
      PrivatePermissionKind.microphone => Permission.microphone,
    };
  }

  /// English label for dialogs and snack messages.
  static String labelFor(PrivatePermissionKind kind) {
    return switch (kind) {
      PrivatePermissionKind.photoLibrary => 'Photos',
      PrivatePermissionKind.camera => 'Camera',
      PrivatePermissionKind.microphone => 'Microphone',
    };
  }

  /// Pure mapping from [PermissionStatus] to [PrivatePermissionResult] (unit-testable).
  static PrivatePermissionResult resultFromStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return PrivatePermissionResult.granted;
    }
    if (status.isPermanentlyDenied) {
      return PrivatePermissionResult.deniedPermanently;
    }
    return PrivatePermissionResult.deniedRetryable;
  }

  /// Whether [ensure] should query/request OS permission before opening media UI.
  ///
  /// Android gallery uses the system Photo Picker via `image_picker` — no
  /// READ_MEDIA_IMAGES preflight (see image_picker Android docs).
  static bool requiresPreflight(PrivatePermissionKind kind) {
    if (kIsWeb) return false;
    if (kind == PrivatePermissionKind.photoLibrary &&
        defaultTargetPlatform == TargetPlatform.android) {
      return false;
    }
    return true;
  }

  /// Requests permission when needed and returns a semantic result (no UI).
  static Future<PrivatePermissionResult> ensure(PrivatePermissionKind kind) async {
    if (!requiresPreflight(kind)) {
      return PrivatePermissionResult.granted;
    }

    final permission = _permissionFor(kind);
    var status = await permission.status;

    if (status.isGranted || status.isLimited) {
      return PrivatePermissionResult.granted;
    }

    if (status.isDenied) {
      status = await permission.request();
    }

    return resultFromStatus(status);
  }
}
