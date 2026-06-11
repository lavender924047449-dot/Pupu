import 'package:pupu/models/private_entry.dart';

/// History list ordering: pinned first, then updatedAt ↓, createdAt ↓, id ↓.
int comparePrivateEntriesForHistory(PrivateEntry a, PrivateEntry b) {
  final aPinned = a.tags.contains('pinned');
  final bPinned = b.tags.contains('pinned');
  if (aPinned && !bPinned) return -1;
  if (!aPinned && bPinned) return 1;

  final updatedCmp = b.updatedAt.compareTo(a.updatedAt);
  if (updatedCmp != 0) return updatedCmp;

  final createdCmp = b.createdAt.compareTo(a.createdAt);
  if (createdCmp != 0) return createdCmp;

  return b.id.compareTo(a.id);
}

/// Returns a new list sorted for the History screen.
List<PrivateEntry> sortPrivateEntriesForHistory(Iterable<PrivateEntry> entries) {
  final copied = List<PrivateEntry>.from(entries);
  copied.sort(comparePrivateEntriesForHistory);
  return copied;
}
