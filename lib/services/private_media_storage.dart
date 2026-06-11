import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Persists Private Space images and voice files under app documents.
class PrivateMediaStorage {
  static Future<Directory> _privateDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/private_space');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _imagesDir() async {
    final root = await _privateDir();
    final dir = Directory('${root.path}/images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _voicesDir() async {
    final root = await _privateDir();
    final dir = Directory('${root.path}/voices');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> persistImageFile(File source, {required String id}) async {
    if (!await source.exists()) {
      throw const FileSystemException('Image source does not exist.');
    }
    final dir = await _imagesDir();
    final ext = _extension(source.path);
    final target = File('${dir.path}/img_$id$ext');
    await source.copy(target.path);
    return target.path;
  }

  static Future<String> persistImageBytes(
    Uint8List bytes, {
    required String id,
    String extension = '.png',
  }) async {
    if (bytes.isEmpty) {
      throw const FileSystemException('Image bytes are empty.');
    }
    final dir = await _imagesDir();
    final ext = _sanitizeExtension(extension);
    final target = File('${dir.path}/img_$id$ext');
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  static Future<String> voicePathFor(String id) async {
    final dir = await _voicesDir();
    return '${dir.path}/voice_$id.m4a';
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    return _sanitizeExtension(ext);
  }

  static String _sanitizeExtension(String ext) {
    final normalized = ext.startsWith('.') ? ext.toLowerCase() : '.${ext.toLowerCase()}';
    const allowed = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};
    return allowed.contains(normalized) ? normalized : '.jpg';
  }
}
