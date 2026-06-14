import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_note_blocks.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';

void main() {
  testWidgets('history preview with text and image uses compact thumbnail', (tester) async {
    final entry = PrivateEntry(
      id: 'entry-1',
      title: '',
      document: const PrivateNoteDocument(
        ops: [
          PrivateDocTextOp('1234555'),
          PrivateDocImageOp(
            PrivateImageData(id: 'img-1', path: '/tmp/missing.jpg'),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: HistoryMixedContentPreview(entry: entry),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('1234555'), findsOneWidget);

    final thumbnail = tester.widgetList<SizedBox>(
      find.descendant(
        of: find.byType(HistoryMixedContentPreview),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 56,
        ),
      ),
    );
    expect(thumbnail, hasLength(1));
    expect(thumbnail.single.height, 56);
  });

  testWidgets('history preview with long text does not overflow card width', (tester) async {
    final entry = PrivateEntry(
      id: 'entry-2',
      title: '',
      document: const PrivateNoteDocument(
        ops: [
          PrivateDocTextOp(
            '大三的深夜，情绪翻涌，但还好有一间只属于自己的房间。'
            '继续写一些文字来模拟 history 卡片里的多行预览内容。',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: HistoryMixedContentPreview(entry: entry),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Text), findsOneWidget);
  });
}
