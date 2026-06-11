import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pupu/models/private_entry.dart';

/// Prefix for legacy in-app JSON clipboard payloads (no longer written).
const String kPrivateClipPrefix = 'pupu-private-clip:';

/// Legacy prefix from the removed external paste-image flow (silently ignored).
const String kLegacyImageBase64Prefix = 'pupu-image-base64:';

/// Decoded in-app clipboard payload.
sealed class PrivateClipPayload {
  const PrivateClipPayload();
}

/// Image embed copied/cut from within Private Space.
final class PrivateClipImagePayload extends PrivateClipPayload {
  const PrivateClipImagePayload(this.image);

  final PrivateImageData image;
}

/// Private Space clipboard helpers.
///
/// Image embeds use an in-memory store so paste always restores a full embed
/// instead of leaking JSON into the system clipboard.
abstract final class PrivateSpaceClipboard {
  PrivateSpaceClipboard._();

  static PrivateImageData? _copiedImage;
  static String? _copiedText;

  /// Decode legacy clipboard text into an in-app payload.
  static PrivateClipPayload? decode(String? text) => _decode(text);

  /// Plain text for caret insertion, or `null` when silent ignore.
  static String? tryReadPlainText(String? text) => _tryReadPlainText(text);

  /// Store plain text for in-app paste (does not touch system clipboard).
  static void copyText(String text) {
    _copiedText = text;
  }

  /// Store an image embed for in-app paste (does not touch system clipboard).
  static void copyImage(PrivateImageData image) {
    _copiedImage = image;
  }

  /// Whether an in-app text payload is ready to paste.
  static bool get hasCopiedText => _copiedText != null;

  /// Whether an in-app image embed is ready to paste.
  static bool get hasCopiedImage => _copiedImage != null;

  /// Peek at copied text without consuming it.
  static String? peekCopiedText() => _copiedText;

  /// Peek at the copied image without consuming it.
  static PrivateImageData? peekCopiedImage() => _copiedImage;

  /// Take copied text for paste (clears the in-app store).
  static String? takeCopiedText() {
    final text = _copiedText;
    _copiedText = null;
    return text;
  }

  /// Take the copied image for paste (clears the in-app store).
  static PrivateImageData? takeCopiedImage() {
    final image = _copiedImage;
    _copiedImage = null;
    return image;
  }

  /// Clear the in-app clipboard store.
  static void clearCopiedImage() {
    _copiedImage = null;
    _copiedText = null;
  }

  /// Read raw system clipboard text (external plain text only).
  static Future<String?> readClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}

PrivateClipPayload? _decode(String? text) {
  if (text == null || text.isEmpty) return null;
  if (!text.startsWith(kPrivateClipPrefix)) return null;

  final jsonText = text.substring(kPrivateClipPrefix.length);
  if (jsonText.isEmpty) return null;

  try {
    final map = jsonDecode(jsonText) as Map<String, dynamic>;
    final type = map['type'] as String?;
    if (type == 'image') {
      final imageJson = map['image'];
      if (imageJson is! Map<String, dynamic>) return null;
      final image = PrivateImageData.fromJson(imageJson);
      if (image.id.isEmpty || image.path.isEmpty) return null;
      return PrivateClipImagePayload(image);
    }
  } catch (_) {}
  return null;
}

String? _tryReadPlainText(String? text) {
  if (text == null || text.isEmpty) return null;
  if (text.startsWith(kPrivateClipPrefix)) return null;
  if (text.startsWith(kLegacyImageBase64Prefix)) return null;
  return text;
}
