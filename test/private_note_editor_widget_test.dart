import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_note_editor.dart';
import 'package:pupu/features/private_space/private_note_document_controller.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';

Future<void> _pumpEditor(
  WidgetTester tester, {
  required PrivateNoteDocumentController controller,
  required ScrollController scrollController,
  double height = 400,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 312,
          height: height,
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
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty note first image lays out embed without flex overflow', (tester) async {
    final controller = PrivateNoteDocumentController(
      initial: const PrivateNoteDocument(ops: [PrivateDocTextOp('')]),
    );
    controller.insertImageAtCaret(
      const PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
    );

    expect(controller.ops.length, 1);
    expect(controller.ops.single, isA<PrivateDocImageOp>());
    expect(controller.isCaretOnEmbed, isTrue);
    expect(controller.caret.textOffset, 1);

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await _pumpEditor(
      tester,
      controller: controller,
      scrollController: scrollController,
    );

    expect(find.byType(AspectRatio), findsOneWidget);
    final aspectSize = tester.getSize(find.byType(AspectRatio));
    expect(aspectSize.height, greaterThan(50));
    expect(aspectSize.width, greaterThan(50));

    controller.disposeController();
  });

  testWidgets('typing with visible caret does not auto-scroll', (tester) async {
    final controller = PrivateNoteDocumentController(
      initial: const PrivateNoteDocument(ops: [PrivateDocTextOp('')]),
    );
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    addTearDown(controller.disposeController);

    await _pumpEditor(
      tester,
      controller: controller,
      scrollController: scrollController,
      height: 300,
    );

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    final initialScroll = scrollController.hasClients ? scrollController.offset : 0.0;

    await tester.enterText(find.byType(TextField).first, 'Hello world');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(scrollController.hasClients, isTrue);
    expect(scrollController.offset, initialScroll);
  });

  testWidgets('continued typing after caret scroll does not oscillate', (tester) async {
    final longPrefix = List.filled(30, 'Line of text.').join('\n');
    final controller = PrivateNoteDocumentController(
      initial: PrivateNoteDocument(ops: [PrivateDocTextOp(longPrefix)]),
    );
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    addTearDown(controller.disposeController);

    await _pumpEditor(
      tester,
      controller: controller,
      scrollController: scrollController,
      height: 220,
    );

    final focusNode = controller.textFocusNodeAt(0)!;
    focusNode.requestFocus();
    final textController = controller.textControllerAt(0)!;
    textController.selection = TextSelection.collapsed(
      offset: textController.text.length,
    );
    await tester.pumpAndSettle();

    final textField = find.byType(TextField).first;
    await tester.enterText(textField, '$longPrefix\nNew line');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final afterFirstEdit = scrollController.offset;
    expect(afterFirstEdit, greaterThan(0));

    await tester.enterText(textField, '$longPrefix\nNew line!!');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Caret remains visible — no back-and-forth scroll jitter.
    expect((scrollController.offset - afterFirstEdit).abs(), lessThan(8));
  });
}
