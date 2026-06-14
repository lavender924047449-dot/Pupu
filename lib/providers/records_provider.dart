/// 排便记录 Provider
/// 对接 LocalStorage，提供记录刷新触发与统一读入口
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pupu/models/bowel_record.dart';
import 'package:pupu/services/local_storage.dart';

class RecordsRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// 刷新记录列表的 trigger
final recordsRefreshProvider =
    NotifierProvider<RecordsRefreshNotifier, int>(RecordsRefreshNotifier.new);

/// 带刷新的记录列表
final recordsWithRefreshProvider = FutureProvider<List<BowelRecord>>((ref) async {
  ref.watch(recordsRefreshProvider);
  return LocalStorage.getAllRecords();
});

void bumpRecordsRefresh(WidgetRef ref) {
  ref.read(recordsRefreshProvider.notifier).bump();
}
