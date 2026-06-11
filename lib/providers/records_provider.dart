/// 排便记录 Provider
/// 对接 LocalStorage，提供记录刷新触发与统一读入口

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pupu/models/bowel_record.dart';
import 'package:pupu/services/local_storage.dart';

/// 刷新记录列表的 trigger
final recordsRefreshProvider = StateProvider<int>((ref) => 0);

/// 带刷新的记录列表
final recordsWithRefreshProvider = FutureProvider<List<BowelRecord>>((ref) async {
  ref.watch(recordsRefreshProvider);
  return LocalStorage.getAllRecords();
});

void bumpRecordsRefresh(WidgetRef ref) {
  ref.read(recordsRefreshProvider.notifier).update((state) => state + 1);
}
