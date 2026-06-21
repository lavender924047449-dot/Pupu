import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Renders a Private Space note image from asset, network/blob, or local file.
///
/// Local [File] paths are unsupported on web — shows a placeholder instead.
class PrivateNoteImage extends StatelessWidget {
  const PrivateNoteImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.brokenIconSize = 36,
  });

  final String path;
  final BoxFit fit;
  final double brokenIconSize;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: fit);
    }
    if (path.startsWith('http') || path.startsWith('blob:')) {
      return Image.network(path, fit: fit);
    }
    if (kIsWeb) {
      return _placeholder(broken: true);
    }

    final file = File(path);
    if (!file.existsSync()) {
      return _placeholder(broken: true);
    }
    return Image.file(file, fit: fit);
  }

  Widget _placeholder({required bool broken}) {
    return Container(
      color: const Color(0x33141D2A),
      child: Center(
        child: Icon(
          broken ? Icons.broken_image_outlined : Icons.image_outlined,
          color: Colors.white38,
          size: brokenIconSize,
        ),
      ),
    );
  }
}
