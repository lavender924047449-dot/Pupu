/// 私人空间条目 Provider
/// 对接 LocalStorage，提供条目刷新触发与统一读入口
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/services/local_storage.dart';

class EntriesRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// 刷新条目的 trigger
final entriesRefreshProvider =
    NotifierProvider<EntriesRefreshNotifier, int>(EntriesRefreshNotifier.new);

/// 带刷新的条目列表
final entriesWithRefreshProvider = FutureProvider<List<PrivateEntry>>((ref) async {
  ref.watch(entriesRefreshProvider);
  return LocalStorage.getAllEntries();
});

void bumpEntriesRefresh(WidgetRef ref) {
  ref.read(entriesRefreshProvider.notifier).bump();
}
