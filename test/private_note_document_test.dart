import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_note_document_controller.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';

void main() {
  test('document ops round-trip json', () {
    final doc = PrivateNoteDocument(
      ops: [
        const PrivateDocTextOp('hello'),
        PrivateDocImageOp(
          PrivateImageData(id: '1', path: '/tmp/a.jpg'),
        ),
        const PrivateDocTextOp(' world'),
      ],
      lastCursorAnchor: const PrivateDocAnchor(opIndex: 1, textOffset: 3),
    );
    final json = doc.toJson();
    final restored = PrivateNoteDocument.fromJson(json);
    expect(restored.ops.length, 3);
    expect((restored.ops.first as PrivateDocTextOp).text, 'hello');
    expect(restored.imageCount, 1);
    expect(restored.lastCursorAnchor?.opIndex, 1);
  });

  test('entry v2 toJson uses document only', () {
    final entry = PrivateEntry(
      id: '1',
      title: 'T',
      document: const PrivateNoteDocument(
        ops: [PrivateDocTextOp('note')],
      ),
    );
    final json = entry.toJson();
    expect(json['schema_version'], kPrivateEntrySchemaVersion);
    expect(json['document'], isNotNull);
    expect(json.containsKey('blocks'), isFalse);
  });

  test('moveOp reorders embed without RangeError', () {
    final controller = PrivateNoteDocumentController(
      initial: PrivateNoteDocument(
        ops: [
          const PrivateDocTextOp('hello'),
          PrivateDocImageOp(
            PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
          ),
          const PrivateDocTextOp(' world'),
          PrivateDocVoiceOp(
            PrivateVoiceData(id: 'voice-1', path: '/tmp/v.m4a', durationMs: 1200),
          ),
          const PrivateDocTextOp('!'),
        ],
      ),
    );

    controller.moveOp(1, 4);

    final doc = controller.buildDocument();
    final imageIndex = doc.ops.indexWhere((op) => op is PrivateDocImageOp);
    final voiceIndex = doc.ops.indexWhere((op) => op is PrivateDocVoiceOp);

    expect(imageIndex, isNonNegative);
    expect(voiceIndex, isNonNegative);
    expect(imageIndex, greaterThan(voiceIndex));

    controller.disposeController();
  });
}
