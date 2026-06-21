import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_note_editor.dart';
import 'package:pupu/features/private_space/private_note_document_controller.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';

const _placeholderText = 'Speak to the galaxy...';

Future<void> _pumpEditor(
  WidgetTester tester, {
  required PrivateNoteDocumentController controller,
}) async {
  final scrollController = ScrollController();
  addTearDown(scrollController.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 312,
          height: 400,
          child: PrivateNoteEditor(
            controller: controller,
            scrollController: scrollController,
            enabled: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivateNoteDocumentController entry placeholder', () {
    test('new blank note shows placeholder when enabled', () {
      final controller = PrivateNoteDocumentController(
        showEntryPlaceholder: true,
      );
      addTearDown(controller.disposeController);

      expect(controller.showEntryPlaceholder, isTrue);
    });

    test('editing existing note does not show placeholder', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(ops: [PrivateDocTextOp('Saved')]),
        showEntryPlaceholder: false,
      );
      addTearDown(controller.disposeController);

      expect(controller.showEntryPlaceholder, isFalse);
    });

    test('typing dismisses placeholder permanently', () {
      final controller = PrivateNoteDocumentController(
        showEntryPlaceholder: true,
      );
      addTearDown(controller.disposeController);

      controller.onTextEdited(0, 'Hi');
      expect(controller.showEntryPlaceholder, isFalse);

      controller.onTextEdited(0, '');
      expect(controller.showEntryPlaceholder, isFalse);
    });

    test('paste dismisses placeholder', () {
      final controller = PrivateNoteDocumentController(
        showEntryPlaceholder: true,
      );
      addTearDown(controller.disposeController);
      controller.focusFirstText();

      controller.pasteTextAtCaret('Pasted');
      expect(controller.showEntryPlaceholder, isFalse);
    });

    test('image insert dismisses placeholder', () {
      final controller = PrivateNoteDocumentController(
        showEntryPlaceholder: true,
      );
      addTearDown(controller.disposeController);

      controller.insertImageAtCaret(
        const PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
      );
      expect(controller.showEntryPlaceholder, isFalse);
    });

    test('voice insert dismisses placeholder', () {
      final controller = PrivateNoteDocumentController(
        showEntryPlaceholder: true,
      );
      addTearDown(controller.disposeController);

      controller.insertVoiceAtCaret(
        const PrivateVoiceData(
          id: 'voice-1',
          path: '/tmp/a.m4a',
          durationMs: 1200,
        ),
      );
      expect(controller.showEntryPlaceholder, isFalse);
    });

    test('focus alone does not dismiss placeholder', () {
      final controller = PrivateNoteDocumentController(
        showEntryPlaceholder: true,
      );
      addTearDown(controller.disposeController);

      controller.focusFirstText(requestKeyboard: false);
      expect(controller.showEntryPlaceholder, isTrue);
    });
  });

  group('PrivateNoteEditor entry placeholder UI', () {
    testWidgets('renders placeholder on new blank note', (tester) async {
      final controller = PrivateNoteDocumentController(
        showEntryPlaceholder: true,
      );
      addTearDown(controller.disposeController);

      await _pumpEditor(tester, controller: controller);

      expect(find.text(_placeholderText), findsOneWidget);
    });

    testWidgets('hides placeholder after first keystroke', (tester) async {
      final controller = PrivateNoteDocumentController(
        showEntryPlaceholder: true,
      );
      addTearDown(controller.disposeController);

      await _pumpEditor(tester, controller: controller);

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(find.text(_placeholderText), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'A');
      await tester.pump();

      expect(find.text(_placeholderText), findsNothing);
    });

    testWidgets('does not render placeholder when editing existing note',
        (tester) async {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(ops: [PrivateDocTextOp('Hello')]),
        showEntryPlaceholder: false,
      );
      addTearDown(controller.disposeController);

      await _pumpEditor(tester, controller: controller);

      expect(find.text(_placeholderText), findsNothing);
    });

    testWidgets('paper tap focuses editor without dismissing placeholder',
        (tester) async {
      final controller = PrivateNoteDocumentController(
        showEntryPlaceholder: true,
      );
      addTearDown(controller.disposeController);

      await _pumpEditor(tester, controller: controller);

      await tester.tapAt(const Offset(200, 200));
      await tester.pump();

      expect(find.text(_placeholderText), findsOneWidget);
      expect(controller.textFocusNodeAt(0)?.hasFocus, isTrue);
    });
  });
}
