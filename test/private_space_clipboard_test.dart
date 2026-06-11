import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_space_clipboard.dart';
import 'package:pupu/models/private_entry.dart';

void main() {
  const sample = PrivateImageData(
    id: 'img_1',
    path: '/tmp/photo.jpg',
    source: 'gallery',
  );

  tearDown(PrivateSpaceClipboard.clearCopiedImage);

  String legacyEncodedImage(PrivateImageData image) {
    return '$kPrivateClipPrefix${jsonEncode({
          'type': 'image',
          'image': image.toJson(),
        })}';
  }

  group('PrivateSpaceClipboard.decode (legacy payloads)', () {
    test('round-trips legacy image payload', () {
      final encoded = legacyEncodedImage(sample);
      expect(encoded.startsWith(kPrivateClipPrefix), isTrue);

      final payload = PrivateSpaceClipboard.decode(encoded);
      expect(payload, isA<PrivateClipImagePayload>());
      final image = (payload! as PrivateClipImagePayload).image;
      expect(image.id, sample.id);
      expect(image.path, sample.path);
      expect(image.source, sample.source);
    });

    test('returns null for invalid or foreign payloads', () {
      expect(PrivateSpaceClipboard.decode(null), isNull);
      expect(PrivateSpaceClipboard.decode('hello'), isNull);
      expect(PrivateSpaceClipboard.decode('pupu-private-clip:{bad json'), isNull);
      expect(
        PrivateSpaceClipboard.decode('pupu-private-clip:{"type":"voice"}'),
        isNull,
      );
    });
  });

  group('PrivateSpaceClipboard in-memory image store', () {
    test('copyImage stores embed without system clipboard', () {
      expect(PrivateSpaceClipboard.hasCopiedImage, isFalse);
      PrivateSpaceClipboard.copyImage(sample);
      expect(PrivateSpaceClipboard.hasCopiedImage, isTrue);
      expect(PrivateSpaceClipboard.peekCopiedImage()?.path, sample.path);
    });

    test('takeCopiedImage returns embed and clears store', () {
      PrivateSpaceClipboard.copyImage(sample);
      final taken = PrivateSpaceClipboard.takeCopiedImage();
      expect(taken?.id, sample.id);
      expect(PrivateSpaceClipboard.hasCopiedImage, isFalse);
    });
  });

  group('PrivateSpaceClipboard.tryReadPlainText', () {
    test('returns external plain text', () {
      expect(PrivateSpaceClipboard.tryReadPlainText('hello world'), 'hello world');
    });

    test('returns null for legacy in-app image JSON', () {
      final encoded = legacyEncodedImage(sample);
      expect(PrivateSpaceClipboard.tryReadPlainText(encoded), isNull);
    });

    test('returns null for legacy base64 prefix (silent ignore)', () {
      expect(
        PrivateSpaceClipboard.tryReadPlainText('pupu-image-base64:abc'),
        isNull,
      );
    });
  });
}
