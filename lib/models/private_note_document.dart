import 'package:pupu/models/private_entry.dart';

/// Schema v2: continuous note document (Word-like storage).
class PrivateNoteDocument {
  const PrivateNoteDocument({
    this.ops = const [],
    this.lastCursorAnchor,
  });

  final List<PrivateDocOp> ops;

  /// Minimal saved cursor anchor. Used for semantic positioning only.
  final PrivateDocAnchor? lastCursorAnchor;

  static const empty = PrivateNoteDocument();

  factory PrivateNoteDocument.fromJson(Map<String, dynamic> json) {
    final rawOps = json['ops'] as List<dynamic>? ?? const [];
    return PrivateNoteDocument(
      ops: rawOps
          .map((e) => PrivateDocOp.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastCursorAnchor: json['cursor_anchor'] == null
          ? null
          : PrivateDocAnchor.fromJson(
              json['cursor_anchor'] as Map<String, dynamic>,
            ),
    );
  }

  Map<String, dynamic> toJson() => {
        'ops': ops.map((e) => e.toJson()).toList(),
        if (lastCursorAnchor != null)
          'cursor_anchor': lastCursorAnchor!.toJson(),
      };

  PrivateNoteDocument copyWith({
    List<PrivateDocOp>? ops,
    PrivateDocAnchor? lastCursorAnchor,
  }) {
    return PrivateNoteDocument(
      ops: ops ?? this.ops,
      lastCursorAnchor: lastCursorAnchor ?? this.lastCursorAnchor,
    );
  }

  int get imageCount {
    var count = 0;
    for (final op in ops) {
      if (op is PrivateDocImageOp) count++;
    }
    return count;
  }

  /// Total logical length of the linearized document.
  int get semanticLength =>
      ops.fold<int>(0, (sum, op) => sum + op.semanticLength);
}

/// Semantic anchor for cursor, media insertion, and replay positioning.
class PrivateDocAnchor {
  const PrivateDocAnchor({
    required this.opIndex,
    required this.textOffset,
  });

  final int opIndex;
  final int textOffset;

  factory PrivateDocAnchor.fromJson(Map<String, dynamic> json) {
    return PrivateDocAnchor(
      opIndex: json['op_index'] as int? ?? 0,
      textOffset: json['text_offset'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'op_index': opIndex,
        'text_offset': textOffset,
      };
}

/// One insert operation in the document stream.
///
/// Stage 1 semantic-unification helpers treat every op as a linear segment:
/// - text segments have variable length (character count)
/// - embed segments have fixed logical length 1
sealed class PrivateDocOp {
  const PrivateDocOp();

  /// Logical length in the unified segment model.
  int get semanticLength;

  /// True when this op is a rich-media embed segment.
  bool get isEmbed => this is PrivateDocImageOp || this is PrivateDocVoiceOp;

  /// True when this op is a text segment.
  bool get isText => this is PrivateDocTextOp;

  factory PrivateDocOp.fromJson(Map<String, dynamic> json) {
    final insert = json['insert'];
    if (insert is String) {
      return PrivateDocTextOp(insert);
    }
    if (insert is Map<String, dynamic>) {
      if (insert.containsKey('image')) {
        return PrivateDocImageOp(
          PrivateImageData.fromJson(insert['image'] as Map<String, dynamic>),
        );
      }
      if (insert.containsKey('voice')) {
        return PrivateDocVoiceOp(
          PrivateVoiceData.fromJson(insert['voice'] as Map<String, dynamic>),
        );
      }
    }
    return const PrivateDocTextOp('');
  }

  Map<String, dynamic> toJson();
}

class PrivateDocTextOp extends PrivateDocOp {
  const PrivateDocTextOp(this.text);

  final String text;

  @override
  int get semanticLength => text.length;

  @override
  Map<String, dynamic> toJson() => {'insert': text};
}

class PrivateDocImageOp extends PrivateDocOp {
  const PrivateDocImageOp(this.image);

  final PrivateImageData image;

  @override
  int get semanticLength => 1;

  @override
  Map<String, dynamic> toJson() => {
        'insert': {'image': image.toJson()},
      };
}

class PrivateDocVoiceOp extends PrivateDocOp {
  const PrivateDocVoiceOp(this.voice);

  final PrivateVoiceData voice;

  @override
  int get semanticLength => 1;

  @override
  Map<String, dynamic> toJson() => {
        'insert': {'voice': voice.toJson()},
      };
}

