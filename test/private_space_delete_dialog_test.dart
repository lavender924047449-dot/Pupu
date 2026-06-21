import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_space_ui.dart';

void main() {
  testWidgets('showPrivateDeleteRecordDialog renders singular copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPrivateDeleteRecordDialog(
              context: context,
              plural: false,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Entry?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('showPrivateDeleteRecordDialog renders plural copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPrivateDeleteRecordDialog(
              context: context,
              plural: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Entries?'), findsOneWidget);
  });

  testWidgets('showPrivateDeleteRecordDialog Cancel returns false', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showPrivateDeleteRecordDialog(
                context: context,
                plural: false,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
