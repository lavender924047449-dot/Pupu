import 'package:flutter_test/flutter_test.dart';
import 'package:pupu/features/private_space/private_note_gallery_limits.dart';

void main() {
  group('galleryPickLimit', () {
    test('returns 5 when note has room', () {
      expect(
        galleryPickLimit(currentImageCount: 0),
        5,
      );
      expect(
        galleryPickLimit(currentImageCount: 30),
        5,
      );
    });

    test('returns remaining slots when below 5', () {
      expect(
        galleryPickLimit(currentImageCount: 33),
        2,
      );
    });

    test('returns 0 when at note cap', () {
      expect(
        galleryPickLimit(currentImageCount: 35),
        0,
      );
    });
  });

  group('shouldRejectGalleryBatch', () {
    test('rejects when picked exceeds limit', () {
      expect(shouldRejectGalleryBatch(6, 5), isTrue);
      expect(shouldRejectGalleryBatch(3, 2), isTrue);
    });

    test('accepts when picked equals limit', () {
      expect(shouldRejectGalleryBatch(5, 5), isFalse);
    });

    test('accepts when picked below limit', () {
      expect(shouldRejectGalleryBatch(3, 5), isFalse);
    });
  });
}
