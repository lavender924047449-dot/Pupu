import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_space_history.dart';

void main() {
  group('clampHistoryScrollOffset', () {
    test('returns saved offset when within range', () {
      expect(
        clampHistoryScrollOffset(savedOffset: 120, maxScrollExtent: 500),
        120,
      );
    });

    test('clamps to maxScrollExtent when list shrinks', () {
      expect(
        clampHistoryScrollOffset(savedOffset: 800, maxScrollExtent: 300),
        300,
      );
    });

    test('returns zero when maxScrollExtent is zero', () {
      expect(
        clampHistoryScrollOffset(savedOffset: 200, maxScrollExtent: 0),
        0,
      );
    });

    test('clamps negative offsets to zero', () {
      expect(
        clampHistoryScrollOffset(savedOffset: -10, maxScrollExtent: 100),
        0,
      );
    });
  });
}
