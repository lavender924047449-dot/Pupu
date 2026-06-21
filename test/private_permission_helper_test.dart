import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pupu/services/private_permission_helper.dart';

void main() {
  group('PrivatePermissionHelper.resultFromStatus', () {
    test('granted → granted', () {
      expect(
        PrivatePermissionHelper.resultFromStatus(PermissionStatus.granted),
        PrivatePermissionResult.granted,
      );
    });

    test('limited → granted', () {
      expect(
        PrivatePermissionHelper.resultFromStatus(PermissionStatus.limited),
        PrivatePermissionResult.granted,
      );
    });

    test('permanentlyDenied → deniedPermanently', () {
      expect(
        PrivatePermissionHelper.resultFromStatus(PermissionStatus.permanentlyDenied),
        PrivatePermissionResult.deniedPermanently,
      );
    });

    test('denied → deniedRetryable', () {
      expect(
        PrivatePermissionHelper.resultFromStatus(PermissionStatus.denied),
        PrivatePermissionResult.deniedRetryable,
      );
    });

    test('restricted → deniedRetryable', () {
      expect(
        PrivatePermissionHelper.resultFromStatus(PermissionStatus.restricted),
        PrivatePermissionResult.deniedRetryable,
      );
    });
  });

  group('PrivatePermissionHelper.requiresPreflight', () {
    test('camera and microphone always require preflight', () {
      expect(PrivatePermissionHelper.requiresPreflight(PrivatePermissionKind.camera), isTrue);
      expect(PrivatePermissionHelper.requiresPreflight(PrivatePermissionKind.microphone), isTrue);
    });

    test('photoLibrary skips preflight on Android and web', () {
      final expected =
          !kIsWeb && defaultTargetPlatform != TargetPlatform.android;
      expect(
        PrivatePermissionHelper.requiresPreflight(PrivatePermissionKind.photoLibrary),
        expected,
      );
    });
  });

  group('PrivatePermissionHelper.labelFor', () {
    test('maps all kinds to English labels', () {
      expect(
        PrivatePermissionHelper.labelFor(PrivatePermissionKind.photoLibrary),
        'Photos',
      );
      expect(
        PrivatePermissionHelper.labelFor(PrivatePermissionKind.camera),
        'Camera',
      );
      expect(
        PrivatePermissionHelper.labelFor(PrivatePermissionKind.microphone),
        'Microphone',
      );
    });
  });
}
