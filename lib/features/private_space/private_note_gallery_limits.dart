/// Gallery pick limits for Private Space note image imports.
int galleryPickLimit({
  required int currentImageCount,
  int maxImagesPerNote = 35,
  int maxGalleryPickCount = 5,
}) {
  final remaining = maxImagesPerNote - currentImageCount;
  if (remaining <= 0) return 0;
  return remaining < maxGalleryPickCount ? remaining : maxGalleryPickCount;
}

/// True when the picker returned more files than [pickLimit] (reject entire batch).
bool shouldRejectGalleryBatch(int pickedLength, int pickLimit) {
  return pickedLength > pickLimit;
}
