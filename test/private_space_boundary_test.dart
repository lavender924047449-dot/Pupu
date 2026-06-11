import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_entry_sort.dart';
import 'package:pupu/features/private_space/private_note_document_controller.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mixed note document', () {
    test('text + image + voice round-trips through json', () {
      final doc = PrivateNoteDocument(
        ops: [
          const PrivateDocTextOp('title line'),
          PrivateDocImageOp(
            PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
          ),
          const PrivateDocTextOp('\nbody'),
          PrivateDocVoiceOp(
            PrivateVoiceData(id: 'v-1', path: '/tmp/v.m4a', durationMs: 800),
          ),
        ],
      );

      final restored = PrivateNoteDocument.fromJson(doc.toJson());
      expect(restored.ops.length, 4);
      expect(restored.imageCount, 1);
      expect(restored.ops.whereType<PrivateDocVoiceOp>().length, 1);
    });

    test('sequential embed delete keeps valid caret range', () {
      final controller = PrivateNoteDocumentController(
        initial: PrivateNoteDocument(
          ops: [
            const PrivateDocTextOp('mix'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocVoiceOp(
              PrivateVoiceData(id: 'v-1', path: '/tmp/v.m4a', durationMs: 500),
            ),
            const PrivateDocTextOp('tail'),
          ],
        ),
      );

      controller.removeImageAt(1);
      controller.removeVoiceAt(1);

      final doc = controller.buildDocument();
      expect(doc.ops.whereType<PrivateDocImageOp>(), isEmpty);
      expect(doc.ops.whereType<PrivateDocVoiceOp>(), isEmpty);
      expect(controller.caret.opIndex, inInclusiveRange(0, doc.ops.length - 1));

      controller.disposeController();
    });
  });

  group('history pin sort', () {
    PrivateEntry entry({
      required String id,
      required DateTime updatedAt,
      List<String> tags = const [],
    }) {
      return PrivateEntry(
        id: id,
        title: id,
        document: const PrivateNoteDocument(ops: [PrivateDocTextOp('x')]),
        tags: tags,
        createdAt: updatedAt,
        updatedAt: updatedAt,
      );
    }

    test('pinned entries precede non-pinned', () {
      final older = entry(
        id: 'old',
        updatedAt: DateTime(2024, 1, 1),
        tags: const ['pinned'],
      );
      final newer = entry(
        id: 'new',
        updatedAt: DateTime(2025, 1, 1),
      );

      final sorted = sortPrivateEntriesForHistory([newer, older]);
      expect(sorted.first.id, 'old');
    });

    test('unpin preserves relative order by updatedAt', () {
      final a = entry(id: 'a', updatedAt: DateTime(2025, 6, 1));
      final b = entry(id: 'b', updatedAt: DateTime(2025, 3, 1));
      final c = entry(
        id: 'c',
        updatedAt: DateTime(2025, 1, 1),
        tags: const ['pinned'],
      );

      final sorted = sortPrivateEntriesForHistory([a, b, c]);
      expect(sorted.map((e) => e.id).toList(), ['c', 'a', 'b']);

      final unpinC = PrivateEntry(
        id: c.id,
        title: c.title,
        document: c.document,
        tags: const [],
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );
      final afterUnpin = sortPrivateEntriesForHistory([a, b, unpinC]);
      expect(afterUnpin.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });
  });

  group('PS-010 updatedAt semantics', () {
    test('copyWith preserves updatedAt when omitted', () {
      final original = DateTime(2024, 5, 1, 12, 0);
      final entry = PrivateEntry(
        id: 'e1',
        title: 't',
        document: const PrivateNoteDocument(ops: [PrivateDocTextOp('x')]),
        category: 'Ideas',
        updatedAt: original,
        createdAt: original,
      );

      final relabeled = entry.copyWith(category: 'Journal');
      expect(relabeled.updatedAt, original);
      expect(relabeled.category, 'Journal');
    });

    test('copyWith bumps updatedAt only when explicitly passed', () {
      final original = DateTime(2024, 5, 1);
      final entry = PrivateEntry(
        id: 'e1',
        title: 't',
        document: const PrivateNoteDocument(ops: [PrivateDocTextOp('x')]),
        updatedAt: original,
        createdAt: original,
      );

      final saved = entry.copyWith(
        document: const PrivateNoteDocument(ops: [PrivateDocTextOp('edited')]),
        updatedAt: DateTime(2025, 1, 1),
      );
      expect(saved.updatedAt, DateTime(2025, 1, 1));
      expect(saved.document.ops.first, isA<PrivateDocTextOp>());
    });
  });

  group('PS-010 dirty detection', () {
    test('hasUnsavedEdits false until ops change', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(ops: [PrivateDocTextOp('hello')]),
      );
      controller.captureSavedBaseline();
      expect(controller.hasUnsavedEdits, isFalse);

      controller.textControllers.first.text = 'hello world';
      expect(controller.hasUnsavedEdits, isTrue);

      controller.disposeController();
    });

    test('captureSavedBaseline clears dirty after logical save', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(ops: [PrivateDocTextOp('a')]),
      );
      controller.captureSavedBaseline();
      controller.textControllers.first.text = 'b';
      expect(controller.hasUnsavedEdits, isTrue);

      controller.captureSavedBaseline();
      expect(controller.hasUnsavedEdits, isFalse);

      controller.disposeController();
    });
  });
}
