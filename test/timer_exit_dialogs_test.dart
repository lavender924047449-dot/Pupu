import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/timer/widgets/timer_dialogs.dart';

void main() {
  group('TimerLeaveTimerConfirmDialog', () {
    testWidgets('renders title and action labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTimerGlassDialog(
                context,
                child: const TimerLeaveTimerConfirmDialog(
                  onLeave: _noop,
                  onCancel: _noop,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Leave Timer?'), findsOneWidget);
      expect(find.textContaining('This session won\'t be saved.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
    });

    testWidgets('Leave invokes callback and closes dialog', (tester) async {
      var leaveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTimerGlassDialog(
                context,
                child: TimerLeaveTimerConfirmDialog(
                  onLeave: () => leaveCalled = true,
                  onCancel: () {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(leaveCalled, isTrue);
      expect(find.text('Leave Timer?'), findsNothing);
    });

    testWidgets('Cancel invokes callback and closes dialog', (tester) async {
      var cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTimerGlassDialog(
                context,
                child: TimerLeaveTimerConfirmDialog(
                  onLeave: () {},
                  onCancel: () => cancelCalled = true,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });
  });

  group('TimerQuestionnaireLeaveConfirmDialog', () {
    testWidgets('renders title and action labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTimerGlassDialog(
                context,
                child: const TimerQuestionnaireLeaveConfirmDialog(
                  onLeave: _noop,
                  onCancel: _noop,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('You haven\'t finished logging.'), findsOneWidget);
      expect(find.textContaining('Leave anyway?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
    });

    testWidgets('Leave invokes callback and closes dialog', (tester) async {
      var leaveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTimerGlassDialog(
                context,
                child: TimerQuestionnaireLeaveConfirmDialog(
                  onLeave: () => leaveCalled = true,
                  onCancel: () {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(leaveCalled, isTrue);
      expect(find.textContaining('Leave anyway?'), findsNothing);
    });
  });
}

void _noop() {}
