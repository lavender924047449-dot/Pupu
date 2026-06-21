import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_note_document_controller.dart';
import 'package:pupu/features/private_space/private_space_clipboard.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(PrivateSpaceClipboard.clearCopiedImage);

  group('PrivateNoteDocumentController embed layout', () {
    test('consecutive image inserts do not leave empty text ops between embeds', () {
      final controller = PrivateNoteDocumentController();

      controller.insertImageAtCaret(
        const PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
      );
      expect(controller.isCaretOnEmbed, isTrue);
      expect(controller.caret.textOffset, 1);

      controller.insertImageAtCaret(
        const PrivateImageData(id: 'img-2', path: '/tmp/b.jpg'),
      );

      final ops = controller.buildDocument().ops;
      expect(ops.length, 2);
      expect(ops[0], isA<PrivateDocImageOp>());
      expect(ops[1], isA<PrivateDocImageOp>());
      expect(ops.any((op) => op is PrivateDocTextOp), isFalse);

      controller.disposeController();
    });

    test('insertImagesAtCaret preserves selection order in middle of text', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [PrivateDocTextOp('hello world')],
        ),
      );
      controller.textControllers[0].selection =
          const TextSelection.collapsed(offset: 5);
      controller.onTextSelectionChanged(0);

      controller.insertImagesAtCaret([
        const PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
        const PrivateImageData(id: 'img-2', path: '/tmp/b.jpg'),
        const PrivateImageData(id: 'img-3', path: '/tmp/c.jpg'),
      ]);

      final ops = controller.buildDocument().ops;
      expect(ops.length, 5);
      expect((ops[0] as PrivateDocTextOp).text, 'hello');
      expect((ops[1] as PrivateDocImageOp).image.id, 'img-1');
      expect((ops[2] as PrivateDocImageOp).image.id, 'img-2');
      expect((ops[3] as PrivateDocImageOp).image.id, 'img-3');
      expect((ops[4] as PrivateDocTextOp).text, ' world');

      controller.disposeController();
    });

    test('insertImagesAtCaret batch undo removes all images at once', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [PrivateDocTextOp('hello world')],
        ),
      );
      controller.textControllers[0].selection =
          const TextSelection.collapsed(offset: 5);
      controller.onTextSelectionChanged(0);

      controller.insertImagesAtCaret([
        const PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
        const PrivateImageData(id: 'img-2', path: '/tmp/b.jpg'),
        const PrivateImageData(id: 'img-3', path: '/tmp/c.jpg'),
      ]);
      expect(controller.buildDocument().imageCount, 3);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.buildDocument().imageCount, 0);
      expect(
        (controller.buildDocument().ops.single as PrivateDocTextOp).text,
        'hello world',
      );

      controller.disposeController();
    });

    test('text between images is kept when it has content', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('between'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-2', path: '/tmp/b.jpg'),
            ),
          ],
        ),
      );

      final ops = controller.buildDocument().ops;
      expect(ops.length, 3);
      expect((ops[1] as PrivateDocTextOp).text, 'between');

      controller.disposeController();
    });

    test('ensureTextOpAt inserts text segment after image', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
          ],
        ),
      );

      controller.ensureTextOpAt(1);

      expect(controller.ops.length, 2);
      expect(controller.ops[0], isA<PrivateDocImageOp>());
      expect(controller.ops[1], isA<PrivateDocTextOp>());
      expect((controller.ops[1] as PrivateDocTextOp).text, isEmpty);
      expect(controller.textControllers.length, 1);

      controller.disposeController();
    });

    test('removing embed between text segments merges without empty gaps', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('hello'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('world'),
          ],
        ),
      );

      controller.removeImageAt(1);

      final ops = controller.buildDocument().ops;
      expect(ops.length, 1);
      expect((ops.single as PrivateDocTextOp).text, 'helloworld');

      controller.disposeController();
    });
  });

  group('PrivateNoteDocumentController clipboard paste', () {
    test('pasteTextAtCaret inserts external plain text at caret', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [PrivateDocTextOp('hello')],
        ),
      );

      controller.onTextFocus(0);
      controller.textControllers[0].selection =
          const TextSelection.collapsed(offset: 5);
      controller.pasteTextAtCaret(' world');

      expect(controller.textControllers[0].text, 'hello world');
      controller.disposeController();
    });

    test('pasteTextAtCaret inserts into text segment after embed', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('first'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('second'),
          ],
        ),
      );

      controller.onTextFocus(1);
      final field = controller.textControllers[1];
      field.selection = TextSelection.collapsed(offset: field.text.length);
      controller.pasteTextAtCaret(' pasted');

      expect(controller.textControllers[1].text, 'second pasted');
      controller.disposeController();
    });

    test('tryPasteInternalImage inserts copied image embed', () {
      const sample = PrivateImageData(
        id: 'img_src',
        path: '/tmp/photo.jpg',
        source: 'gallery',
      );
      PrivateSpaceClipboard.copyImage(sample);
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [PrivateDocTextOp('')],
        ),
      );

      controller.onTextFocus(0);
      final consumed = controller.tryPasteInternalImage();

      expect(consumed, isTrue);
      final images = controller.buildDocument().ops.whereType<PrivateDocImageOp>();
      expect(images.length, 1);
      expect(images.first.image.path, '/tmp/photo.jpg');
      controller.disposeController();
    });

    test('tryPasteInternalImage falls back to internal copied text payload', () {
      PrivateSpaceClipboard.copyText(' internal');
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [PrivateDocTextOp('hello')],
        ),
      );

      controller.onTextFocus(0);
      controller.textControllers[0].selection =
          const TextSelection.collapsed(offset: 5);
      final consumed = controller.tryPasteInternalImage();

      expect(consumed, isTrue);
      expect(controller.textControllers[0].text, 'hello internal');
      controller.disposeController();
    });

    test('shouldSilenceClipboardText rejects legacy base64 and invalid JSON', () {
      final controller = PrivateNoteDocumentController();

      expect(controller.shouldSilenceClipboardText('pupu-image-base64:abc'), isTrue);
      expect(controller.shouldSilenceClipboardText('pupu-private-clip:{bad'), isTrue);
      expect(controller.shouldSilenceClipboardText('hello'), isFalse);

      controller.disposeController();
    });

    test('copySelectionBySemanticRangeToClipboard copies mixed range only', () async {
      final clipboardEvents = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            clipboardEvents.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(
        anchorOffset: 1,
        focusOffset: 4,
      );

      final handled = controller.copySelectionBySemanticRangeToClipboard();

      expect(handled, isTrue);
      final ops = controller.buildDocument().ops;
      expect(ops.length, 3);
      expect((ops[0] as PrivateDocTextOp).text, 'ab');
      expect(ops[1], isA<PrivateDocImageOp>());
      expect((ops[2] as PrivateDocTextOp).text, 'cd');
      expect(controller.selectionState.isCollapsed, isFalse);
      expect(controller.selectionCoversOp(0), isTrue);
      expect(controller.selectionCoversOp(1), isTrue);
      expect(controller.selectionCoversOp(2), isTrue);

      final clipboardCall = clipboardEvents.lastWhere(
        (e) => e.method == 'Clipboard.setData',
      );
      final text = (clipboardCall.arguments as Map)['text'] as String;
      expect(text, 'b[Image]c');

      controller.disposeController();
    });

    test('cutSelectionBySemanticRangeToClipboard copies mixed range then deletes', () async {
      final clipboardEvents = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            clipboardEvents.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(
        anchorOffset: 1,
        focusOffset: 4,
      );

      final handled = controller.cutSelectionBySemanticRangeToClipboard();

      expect(handled, isTrue);
      expect(controller.buildDocument().ops.length, 1);
      expect((controller.buildDocument().ops.single as PrivateDocTextOp).text, 'ad');
      expect(controller.selectionState.isCollapsed, isTrue);
      expect(controller.selectionState.anchorOffset, 1);

      final clipboardCall = clipboardEvents.lastWhere(
        (e) => e.method == 'Clipboard.setData',
      );
      final text = (clipboardCall.arguments as Map)['text'] as String;
      expect(text, 'b[Image]c');

      controller.disposeController();
    });

    test('handleCopy and handleCut route through semantic clipboard flow', () async {
      final clipboardEvents = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            clipboardEvents.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(anchorOffset: 1, focusOffset: 4);

      expect(controller.handleCopy(), isTrue);
      expect(PrivateSpaceClipboard.peekCopiedText(), 'b[Image]c');
      expect(clipboardEvents.isNotEmpty, isTrue);

      expect(controller.handleCut(), isTrue);
      expect(controller.buildDocument().ops.length, 1);
      expect((controller.buildDocument().ops.single as PrivateDocTextOp).text, 'ad');
      expect(controller.selectionState.isCollapsed, isTrue);

      controller.disposeController();
    });

    test('tryPasteImageFromClipboardText returns false for plain text', () {
      final controller = PrivateNoteDocumentController();

      expect(controller.tryPasteImageFromClipboardText('hello'), isFalse);

      controller.disposeController();
    });

    test('tryPasteInternalImage replaces semantic selection with image payload', () {
      const sample = PrivateImageData(
        id: 'img_src_2',
        path: '/tmp/replace.jpg',
        source: 'gallery',
      );
      PrivateSpaceClipboard.copyImage(sample);

      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(PrivateImageData(id: 'img-old', path: '/tmp/old.jpg')),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(anchorOffset: 1, focusOffset: 4);
      final consumed = controller.tryPasteInternalImage();

      expect(consumed, isTrue);
      final ops = controller.buildDocument().ops;
      expect(ops.length, 3);
      expect((ops[0] as PrivateDocTextOp).text, 'a');
      expect(ops[1], isA<PrivateDocImageOp>());
      expect((ops[2] as PrivateDocTextOp).text, 'd');
      controller.disposeController();
    });

    test('pasteTextAtCaret replaces semantic selection with internal text payload', () {
      PrivateSpaceClipboard.copyText('XYZ');
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(PrivateImageData(id: 'img-old-2', path: '/tmp/old2.jpg')),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(anchorOffset: 1, focusOffset: 4);
      final consumed = controller.tryPasteInternalImage();

      expect(consumed, isTrue);
      final ops = controller.buildDocument().ops;
      expect(ops.length, 1);
      expect((ops.single as PrivateDocTextOp).text, 'aXYZd');
      expect(controller.selectionState.isCollapsed, isTrue);
      expect(controller.selectionState.anchorOffset, 4);
      controller.disposeController();
    });

    test('external plain text replaces semantic selection by pasteTextAtCaret', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(PrivateImageData(id: 'img-old-3', path: '/tmp/old3.jpg')),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(anchorOffset: 1, focusOffset: 4);
      controller.pasteTextAtCaret('PLAIN');

      final ops = controller.buildDocument().ops;
      expect(ops.length, 1);
      expect((ops.single as PrivateDocTextOp).text, 'aPLAINd');
      expect(controller.selectionState.isCollapsed, isTrue);
      expect(controller.selectionState.anchorOffset, 6);
      controller.disposeController();
    });

    test('tryPasteInternalImage prioritizes image payload over text payload', () {
      const sample = PrivateImageData(
        id: 'img-priority',
        path: '/tmp/priority.jpg',
        source: 'gallery',
      );
      PrivateSpaceClipboard.copyText('TEXT_SHOULD_NOT_WIN');
      PrivateSpaceClipboard.copyImage(sample);

      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [PrivateDocTextOp('hello')],
        ),
      );

      controller.onTextFocus(0);
      controller.textControllers[0].selection =
          const TextSelection.collapsed(offset: 5);
      final consumed = controller.tryPasteInternalImage();

      expect(consumed, isTrue);
      final ops = controller.buildDocument().ops;
      expect(ops.length, 2);
      expect((ops[0] as PrivateDocTextOp).text, 'hello');
      expect(ops[1], isA<PrivateDocImageOp>());
      expect(ops.whereType<PrivateDocImageOp>().length, 1);
      expect(ops.whereType<PrivateDocTextOp>().map((e) => e.text).join(), 'hello');
      controller.disposeController();
    });
  });

  group('PrivateNoteDocumentController embed-as-character', () {
    test('deleteBackwardFromTextFieldStart lands on embed right without deleting', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('hello'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('world'),
          ],
        ),
      );

      controller.onTextFocus(1);
      controller.textControllers[1].selection =
          const TextSelection.collapsed(offset: 0);
      final handled = controller.handleDeleteBackwardFromTextField(1);

      expect(handled, isTrue);
      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>().length, 1);
      expect(controller.isCaretOnEmbed, isTrue);
      expect(controller.caret.opIndex, 1);
      expect(controller.caret.textOffset, 1);
      controller.disposeController();
    });

    test('two-step backspace from line below embed deletes image', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('hello'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('world'),
          ],
        ),
      );

      controller.onTextFocus(1);
      controller.textControllers[1].selection =
          const TextSelection.collapsed(offset: 0);
      expect(controller.handleDeleteBackwardFromTextField(1), isTrue);
      expect(controller.isCaretOnEmbed, isTrue);
      expect(controller.caret.textOffset, 1);

      expect(controller.handleDeleteBackwardOnEmbed(), isTrue);
      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>(), isEmpty);
      expect((controller.ops.single as PrivateDocTextOp).text, 'helloworld');
      controller.disposeController();
    });

    test('moveCaretLeft from text start lands on previous text end', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('hi'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('there'),
          ],
        ),
      );

      controller.onTextFocus(1);
      controller.textControllers[1].selection =
          const TextSelection.collapsed(offset: 0);
      final moved = controller.handleArrowLeftFromTextField(1);

      expect(moved, isTrue);
      expect(controller.isCaretOnEmbed, isFalse);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 2);
      controller.disposeController();
    });

    test('insertNewlineAtCaret after embed inserts empty line before next text', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('line'),
          ],
        ),
      );

      controller.placeCaretAfterEmbed(0);
      final handled = controller.insertNewlineAtCaret();

      expect(handled, isTrue);
      expect(controller.ops.length, 3);
      expect(controller.ops[1], isA<PrivateDocTextOp>());
      expect((controller.ops[1] as PrivateDocTextOp).text, isEmpty);
      expect((controller.ops[2] as PrivateDocTextOp).text, 'line');
      expect(controller.caret.opIndex, 1);
      expect(controller.caret.textOffset, 0);
      controller.disposeController();
    });

    test('insertNewlineAtCaret after embed with explicit spacer reuses that spacer', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp(''),
            PrivateDocTextOp('line'),
          ],
        ),
      );

      controller.placeCaretAfterEmbed(0);
      final handled = controller.insertNewlineAtCaret();

      expect(handled, isTrue);
      expect(controller.ops.length, 3);
      expect((controller.ops[1] as PrivateDocTextOp).text, isEmpty);
      controller.disposeController();
    });

    test('insertNewlineAtCaret after embed at end creates single empty line', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocVoiceOp(
              PrivateVoiceData(id: 'voice-1', path: '/tmp/v.m4a', durationMs: 900),
            ),
          ],
        ),
      );

      controller.placeCaretAfterEmbed(0);
      final handled = controller.insertNewlineAtCaret();

      expect(handled, isTrue);
      expect(controller.ops.length, 2);
      expect((controller.ops[1] as PrivateDocTextOp).text, isEmpty);
      expect(controller.caret.opIndex, 1);
      expect(controller.caret.textOffset, 0);
      controller.disposeController();
    });

    test('deleteable spacer text between embeds is removed by backspace', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp(''),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-2', path: '/tmp/b.jpg'),
            ),
          ],
        ),
      );

      controller.setCaret(const PrivateDocCaret(opIndex: 1, textOffset: 0));
      final handled = controller.handleDeleteBackwardFromTextField(0);

      expect(handled, isTrue);
      expect(controller.buildDocument().ops.length, 2);
      expect(controller.buildDocument().ops.whereType<PrivateDocTextOp>(), isEmpty);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 1);
      controller.disposeController();
    });

    test('newline spacer after embed lands caret on embed right edge', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('\n'),
            PrivateDocTextOp('below'),
          ],
        ),
      );

      controller.setCaret(const PrivateDocCaret(opIndex: 1, textOffset: 0));
      final handled = controller.handleDeleteBackwardFromTextField(0);

      expect(handled, isTrue);
      expect(controller.buildDocument().ops.length, 2);
      expect(
        (controller.buildDocument().ops[1] as PrivateDocTextOp).text,
        '\nbelow',
      );
      expect(controller.isCaretOnEmbed, isTrue);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 1);
      controller.disposeController();
    });

    test('non-deleteable spacer-like text at embed boundary keeps content', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('keep'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-2', path: '/tmp/b.jpg'),
            ),
          ],
        ),
      );

      controller.setCaret(const PrivateDocCaret(opIndex: 1, textOffset: 0));
      final handled = controller.handleDeleteBackwardFromTextField(0);

      expect(handled, isTrue);
      expect(controller.buildDocument().ops.length, 3);
      expect((controller.buildDocument().ops[1] as PrivateDocTextOp).text, 'keep');
      controller.disposeController();
    });

    test('backspace removes empty line after embed', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp(''),
            PrivateDocTextOp('below'),
          ],
        ),
      );

      controller.setCaret(const PrivateDocCaret(opIndex: 1, textOffset: 0));
      final handled = controller.handleDeleteBackwardFromTextField(0);

      expect(handled, isTrue);
      expect(controller.ops.length, 2);
      expect(controller.ops[0], isA<PrivateDocImageOp>());
      expect((controller.ops[1] as PrivateDocTextOp).text, 'below');
      expect(controller.isCaretOnEmbed, isTrue);
      expect(controller.caret.textOffset, 1);
      controller.disposeController();
    });

    test('insertNewlineAtCaret before embed appends newline to previous text', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('top'),
            PrivateDocTextOp('\n'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
          ],
        ),
      );

      controller.setCaret(const PrivateDocCaret(opIndex: 1, textOffset: 0));
      final handled = controller.insertNewlineAtCaret();

      expect(handled, isTrue);
      expect(controller.ops.length, 2);
      expect((controller.ops[0] as PrivateDocTextOp).text, 'top\n\n');
      expect(controller.ops[1], isA<PrivateDocImageOp>());
      controller.disposeController();
    });

    test('delete from text end before embed first lands on embed left then deletes', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('hello'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('world'),
          ],
        ),
      );

      controller.onTextFocus(0);
      controller.textControllerAt(0)!.selection =
          const TextSelection.collapsed(offset: 5);

      expect(controller.handleDeleteForwardFromTextField(0), isTrue);
      expect(controller.isCaretOnEmbed, isTrue);
      expect(controller.caret.opIndex, 1);
      expect(controller.caret.textOffset, 0);

      expect(controller.handleDeleteForwardOnEmbed(), isTrue);
      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>(), isEmpty);

      controller.disposeController();
    });

    test('placeCaretBeforeEmbed lands on embed with textOffset 0', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('hi'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
          ],
        ),
      );

      controller.placeCaretBeforeEmbed(1);

      expect(controller.isCaretOnEmbed, isTrue);
      expect(controller.caret.opIndex, 1);
      expect(controller.caret.textOffset, 0);
      controller.disposeController();
    });

    test('placeCaretAfterEmbed lands on embed with textOffset 1', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('tail'),
          ],
        ),
      );

      controller.placeCaretAfterEmbed(0);

      expect(controller.isCaretOnEmbed, isTrue);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 1);
      controller.disposeController();
    });

    test('deleteBackwardOnEmbed from left caret does not remove embed', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('hello'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('world'),
          ],
        ),
      );

      controller.placeCaretBeforeEmbed(1);
      final handled = controller.handleDeleteBackwardOnEmbed();

      expect(handled, isFalse);
      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>().length, 1);
      controller.disposeController();
    });

    test('deleteBackwardOnEmbed from right caret removes embed', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('hello'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocTextOp('world'),
          ],
        ),
      );

      controller.placeCaretAfterEmbed(1);
      final handled = controller.handleDeleteBackwardOnEmbed();

      expect(handled, isTrue);
      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>(), isEmpty);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 5);
      controller.disposeController();
    });

    test('backspace delete embed lands on previous line before embed', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('line1\nline2'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
          ],
        ),
      );

      controller.placeCaretAfterEmbed(1);
      final handled = controller.handleDeleteBackwardOnEmbed();

      expect(handled, isTrue);
      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>(), isEmpty);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 11);
      controller.disposeController();
    });

    test('deleteVoice preserves caret offset in text after embed', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocVoiceOp(
              PrivateVoiceData(id: 'voice-1', path: '/tmp/v.m4a', durationMs: 900),
            ),
            PrivateDocTextOp('line1\nline2\nline3'),
          ],
        ),
      );

      controller.onTextFocus(0);
      controller.textControllerAt(0)!.selection =
          const TextSelection.collapsed(offset: 12);
      controller.onTextSelectionChanged(0);
      controller.removeVoiceAt(0);

      expect(controller.buildDocument().ops.whereType<PrivateDocVoiceOp>(), isEmpty);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 0);
      controller.disposeController();
    });

    test('onTextSelectionChanged ignores updates when field is not focused', () {
      TestWidgetsFlutterBinding.ensureInitialized();

      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [PrivateDocTextOp('abcd')],
        ),
      );

      controller.onTextFocus(0);
      controller.onTextSelectionChanged(
        0,
        selection: const TextSelection(baseOffset: 3, extentOffset: 1),
      );

      expect(controller.selectionState.anchorOffset, 0);
      expect(controller.selectionState.focusOffset, 0);
      expect(controller.caret.textOffset, 4);

      controller.disposeController();
    });

    test('deleteVoice keeps caret on empty line after embed', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('intro'),
            PrivateDocVoiceOp(
              PrivateVoiceData(id: 'voice-1', path: '/tmp/v.m4a', durationMs: 900),
            ),
            PrivateDocTextOp(''),
          ],
        ),
      );

      controller.removeVoiceAt(1);

      expect(controller.buildDocument().ops.whereType<PrivateDocVoiceOp>(), isEmpty);
      expect(controller.ops.length, 2);
      expect((controller.ops[1] as PrivateDocTextOp).text, isEmpty);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 5);
      controller.disposeController();
    });

    test('removeImageAt with caret on embed lands on line before embed', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('line1\nline2\nline3'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
          ],
        ),
      );

      controller.placeCaretAfterEmbed(1);
      controller.removeImageAt(1);

      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>(), isEmpty);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 17);
      controller.disposeController();
    });

    test('removeImageAt syncs caret from text field selection before delete', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('line1\nline2\nline3'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
          ],
        ),
      );

      controller.onTextFocus(0);
      controller.textControllerAt(0)!.selection =
          const TextSelection.collapsed(offset: 12);
      controller.removeImageAt(1);

      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>(), isEmpty);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 17);
      controller.disposeController();
    });

    test('deleteForwardOnEmbed removes embed only from left caret', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('hello'),
            PrivateDocVoiceOp(
              PrivateVoiceData(id: 'voice-1', path: '/tmp/v.m4a', durationMs: 900),
            ),
            PrivateDocTextOp('world'),
          ],
        ),
      );

      controller.placeCaretAfterEmbed(1);
      expect(controller.handleDeleteForwardOnEmbed(), isFalse);
      expect(controller.buildDocument().ops.whereType<PrivateDocVoiceOp>().length, 1);

      controller.placeCaretBeforeEmbed(1);
      expect(controller.handleDeleteForwardOnEmbed(), isTrue);
      expect(controller.buildDocument().ops.whereType<PrivateDocVoiceOp>(), isEmpty);

      controller.disposeController();
    });

    test('backspace repeatedly removes consecutive embeds without jumping to start', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('head'),
            PrivateDocImageOp(PrivateImageData(id: 'img-1', path: '/tmp/a.jpg')),
            PrivateDocImageOp(PrivateImageData(id: 'img-2', path: '/tmp/b.jpg')),
            PrivateDocTextOp('tail'),
          ],
        ),
      );

      controller.placeCaretAfterEmbed(2);
      expect(controller.handleDeleteBackwardOnEmbed(), isTrue);
      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>().length, 1);
      expect(controller.caret.textOffset, 1);

      expect(controller.handleDeleteBackwardOnEmbed(), isTrue);
      expect(controller.buildDocument().ops.whereType<PrivateDocImageOp>(), isEmpty);
      expect(controller.caret.opIndex, 0);
      expect(controller.caret.textOffset, 4);

      controller.disposeController();
    });

    test('deleteSelectionBySemanticRange removes pure embed range and collapses caret', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(PrivateImageData(id: 'img-1', path: '/tmp/a.jpg')),
            PrivateDocImageOp(PrivateImageData(id: 'img-2', path: '/tmp/b.jpg')),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(anchorOffset: 2, focusOffset: 4);
      expect(controller.deleteSelectionBySemanticRange(), isTrue);

      final doc = controller.buildDocument();
      expect(doc.ops.whereType<PrivateDocImageOp>(), isEmpty);
      expect((doc.ops.single as PrivateDocTextOp).text, 'abcd');
      expect(controller.selectionState.isCollapsed, isTrue);
      expect(controller.selectionState.anchorOffset, 2);

      controller.disposeController();
    });

    test('reverse semantic selection deletion works for mixed text/embed range', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(PrivateImageData(id: 'img-1', path: '/tmp/a.jpg')),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(anchorOffset: 4, focusOffset: 1);
      expect(controller.deleteSelectionBySemanticRange(), isTrue);

      final doc = controller.buildDocument();
      expect(doc.ops.length, 1);
      expect((doc.ops.single as PrivateDocTextOp).text, 'ad');
      expect(controller.selectionState.isCollapsed, isTrue);
      expect(controller.selectionState.anchorOffset, 1);
      expect(controller.caret.textOffset, 1);

      controller.disposeController();
    });

    test('cutSelectionBySemanticRangeToClipboard supports reverse selection direction', () async {
      final clipboardEvents = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            clipboardEvents.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(PrivateImageData(id: 'img-1', path: '/tmp/a.jpg')),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(anchorOffset: 4, focusOffset: 1);
      expect(controller.cutSelectionBySemanticRangeToClipboard(), isTrue);

      final clipboardCall = clipboardEvents.lastWhere(
        (e) => e.method == 'Clipboard.setData',
      );
      final text = (clipboardCall.arguments as Map)['text'] as String;
      expect(text, 'b[Image]c');
      expect((controller.buildDocument().ops.single as PrivateDocTextOp).text, 'ad');

      controller.disposeController();
    });

    test('pasteTextAtCaret replaces reverse semantic selection with plain text', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(PrivateImageData(id: 'img-1', path: '/tmp/a.jpg')),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(anchorOffset: 4, focusOffset: 1);
      controller.pasteTextAtCaret('PLAIN');

      final doc = controller.buildDocument();
      expect(doc.ops.length, 1);
      expect((doc.ops.single as PrivateDocTextOp).text, 'aPLAINd');
      expect(controller.selectionState.isCollapsed, isTrue);
      expect(controller.selectionState.anchorOffset, 6);
      expect(controller.caret.textOffset, 6);

      controller.disposeController();
    });

    test('internal copied text replaces reverse semantic selection', () {
      PrivateSpaceClipboard.copyText('X');
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('ab'),
            PrivateDocImageOp(PrivateImageData(id: 'img-1', path: '/tmp/a.jpg')),
            PrivateDocTextOp('cd'),
          ],
        ),
      );

      controller.setSelectionBySemanticOffsets(anchorOffset: 4, focusOffset: 1);
      expect(controller.tryPasteInternalImage(), isTrue);

      final doc = controller.buildDocument();
      expect(doc.ops.length, 1);
      expect((doc.ops.single as PrivateDocTextOp).text, 'aXd');
      expect(controller.selectionState.isCollapsed, isTrue);
      expect(controller.selectionState.anchorOffset, 2);
      expect(controller.caret.textOffset, 2);

      controller.disposeController();
    });
  });

  group('undo/redo history', () {
    test('text edit undo restores previous content', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(ops: [PrivateDocTextOp('hi')]),
      );

      controller.textControllers[0].text = 'hello';
      controller.onTextEdited(0, 'hello');
      expect((controller.buildDocument().ops.single as PrivateDocTextOp).text, 'hello');
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect((controller.buildDocument().ops.single as PrivateDocTextOp).text, 'hi');

      controller.disposeController();
    });

    test('insert image undo removes embed', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(ops: [PrivateDocTextOp('')]),
      );

      controller.insertImageAtCaret(
        const PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
      );
      expect(controller.ops.any((op) => op is PrivateDocImageOp), isTrue);

      controller.undo();
      expect(controller.ops.any((op) => op is PrivateDocImageOp), isFalse);

      controller.disposeController();
    });

    test('moveOp undo restores original order', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('a'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-2', path: '/tmp/b.jpg'),
            ),
          ],
        ),
      );

      controller.moveOp(2, 1);
      final moved = controller.buildDocument().ops;
      expect((moved[1] as PrivateDocImageOp).image.id, 'img-2');

      controller.undo();
      final restored = controller.buildDocument().ops;
      expect((restored[1] as PrivateDocImageOp).image.id, 'img-1');
      expect(controller.canRedo, isTrue);

      controller.disposeController();
    });

    test('undo stack keeps at most 20 snapshots', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(ops: [PrivateDocTextOp('')]),
      );

      for (var i = 0; i < 25; i++) {
        controller.onTextEdited(0, 'x' * (i + 1));
      }

      var undoCount = 0;
      while (controller.canUndo) {
        controller.undo();
        undoCount++;
      }
      expect(undoCount, 20);

      controller.disposeController();
    });

    test('caret movement alone does not consume undo steps', () {
      final controller = PrivateNoteDocumentController(
        initial: const PrivateNoteDocument(
          ops: [
            PrivateDocTextOp('a'),
            PrivateDocImageOp(
              PrivateImageData(id: 'img-1', path: '/tmp/a.jpg'),
            ),
          ],
        ),
      );

      controller.moveCaretRight();
      controller.moveCaretLeft();
      expect(controller.canUndo, isFalse);

      controller.onTextEdited(0, 'ab');
      expect(controller.canUndo, isTrue);

      controller.disposeController();
    });
  });
}
