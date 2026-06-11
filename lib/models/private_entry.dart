import 'dart:convert';

import 'package:pupu/models/private_note_document.dart';

/// Current Private Space entry schema (v2 = document ops).
const int kPrivateEntrySchemaVersion = 3;

/// Private Space content block types (legacy v1 — not written for new saves).
enum PrivateBlockType {
  text,
  image,
  voice,
}


class PrivateImageData {
  const PrivateImageData({
    required this.id,
    required this.path,
    this.source = 'gallery',
  });

  final String id;
  final String path;
  final String source;

  factory PrivateImageData.fromJson(Map<String, dynamic> json) {
    return PrivateImageData(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      source: json['source'] as String? ?? 'gallery',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'source': source,
      };
}


class PrivateVoiceData {
  const PrivateVoiceData({
    required this.id,
    required this.path,
    required this.durationMs,
    this.title,
    this.waveform = const [],
  });

  final String id;
  final String path;
  final int durationMs;
  final String? title;
  final List<double> waveform;

  factory PrivateVoiceData.fromJson(Map<String, dynamic> json) {
    return PrivateVoiceData(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      durationMs: json['duration_ms'] as int? ?? 0,
      title: json['title'] as String?,
      waveform: (json['waveform'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'duration_ms': durationMs,
        'title': title,
        'waveform': waveform,
      };
}

class PrivateContentBlock {
  const PrivateContentBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.images = const [],
    this.voice,
  });

  final String id;
  final PrivateBlockType type;
  final String text;
  final List<PrivateImageData> images;
  final PrivateVoiceData? voice;

  factory PrivateContentBlock.text({
    required String id,
    required String text,
  }) {
    return PrivateContentBlock(
      id: id,
      type: PrivateBlockType.text,
      text: text,
    );
  }

  factory PrivateContentBlock.imageGroup({
    required String id,
    required List<PrivateImageData> images,
  }) {
    return PrivateContentBlock(
      id: id,
      type: PrivateBlockType.image,
      images: images,
    );
  }

  factory PrivateContentBlock.voice({
    required String id,
    required PrivateVoiceData voice,
  }) {
    return PrivateContentBlock(
      id: id,
      type: PrivateBlockType.voice,
      voice: voice,
    );
  }

  factory PrivateContentBlock.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'text';
    final type = PrivateBlockType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => PrivateBlockType.text,
    );

    return PrivateContentBlock(
      id: json['id'] as String? ?? '',
      type: type,
      text: json['text'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => PrivateImageData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      voice: json['voice'] == null
          ? null
          : PrivateVoiceData.fromJson(json['voice'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'text': text,
        'images': images.map((e) => e.toJson()).toList(),
        'voice': voice?.toJson(),
      };

  PrivateContentBlock copyWith({
    String? id,
    PrivateBlockType? type,
    String? text,
    List<PrivateImageData>? images,
    PrivateVoiceData? voice,
  }) {
    return PrivateContentBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      images: images ?? this.images,
      voice: voice ?? this.voice,
    );
  }
}

/// Private Space entry (schema v2: [document] only for new saves).
class PrivateEntry {
  final String id;
  final String title;
  final List<String> tags;
  final String category;
  final int schemaVersion;
  final PrivateNoteDocument document;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Legacy fields — read-only for purge detection; never written on save.
  final String content;
  final List<String> attachmentUrls;
  final List<PrivateContentBlock> blocks;

  PrivateEntry({
    required this.id,
    required this.title,
    required this.document,
    this.schemaVersion = kPrivateEntrySchemaVersion,
    this.tags = const [],
    this.category = 'Uncategorized',
    this.content = '',
    this.attachmentUrls = const [],
    this.blocks = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLegacySchema => schemaVersion < kPrivateEntrySchemaVersion;

  bool get hasLegacyPayload =>
      blocks.isNotEmpty ||
      content.trim().isNotEmpty ||
      attachmentUrls.isNotEmpty;

  List<PrivateContentBlock> get normalizedBlocks {
    if (blocks.isNotEmpty) return blocks;
    if (content.trim().isEmpty && attachmentUrls.isEmpty) {
      return const [];
    }

    final generated = <PrivateContentBlock>[];
    if (content.trim().isNotEmpty) {
      generated.add(
        PrivateContentBlock.text(
          id: '${id}_legacy_text',
          text: content,
        ),
      );
    }
    if (attachmentUrls.isNotEmpty) {
      generated.add(
        PrivateContentBlock.imageGroup(
          id: '${id}_legacy_images',
          images: attachmentUrls
              .asMap()
              .entries
              .map(
                (entry) => PrivateImageData(
                  id: '${id}_img_${entry.key}',
                  path: entry.value,
                  source: 'legacy',
                ),
              )
              .toList(),
        ),
      );
    }
    return generated;
  }

  factory PrivateEntry.fromJson(Map<String, dynamic> json) {
    final schema = json['schema_version'] as int? ?? 1;
    final docJson = json['document'] as Map<String, dynamic>?;
    return PrivateEntry(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      schemaVersion: schema,
      document: docJson != null
          ? PrivateNoteDocument.fromJson(docJson)
          : PrivateNoteDocument.empty,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      category: json['category'] as String? ?? 'Uncategorized',
      content: json['content'] as String? ?? '',
      attachmentUrls: (json['attachment_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      blocks: (json['blocks'] as List<dynamic>?)
              ?.map(
                (e) => PrivateContentBlock.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'schema_version': kPrivateEntrySchemaVersion,
      'document': document.toJson(),
      'tags': tags,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get plainTextPreview {
    final buffer = StringBuffer();
    for (final op in document.ops) {
      switch (op) {
        case PrivateDocTextOp(:final text):
          if (text.trim().isNotEmpty) buffer.writeln(text.trim());
        case PrivateDocImageOp():
          buffer.writeln('[Image]');
        case PrivateDocVoiceOp(:final voice):
          final seconds = (voice.durationMs / 1000).round();
          buffer.writeln(
            voice.title?.trim().isNotEmpty == true
                ? voice.title!
                : '[Voice ${seconds}s]',
          );
      }
    }
    return buffer.toString().trim();
  }

  /// [updatedAt] omitted → preserve existing timestamp (metadata edits).
  /// Content saves should pass [updatedAt]: `DateTime.now()`.
  PrivateEntry copyWith({
    String? id,
    String? title,
    List<String>? tags,
    String? category,
    PrivateNoteDocument? document,
    DateTime? updatedAt,
  }) {
    return PrivateEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      document: document ?? this.document,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String encodeBlocks(List<PrivateContentBlock> blocks) {
    return jsonEncode(blocks.map((e) => e.toJson()).toList());
  }

  static List<PrivateContentBlock> decodeBlocks(String source) {
    final raw = jsonDecode(source) as List<dynamic>;
    return raw
        .map((e) => PrivateContentBlock.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
