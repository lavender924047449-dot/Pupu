/// 本地存储服务
/// 使用 Hive 存储排便记录与私人空间

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:pupu/models/bowel_record.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _boxRecords = 'bowel_records';
  static const String _boxEntries = 'private_entries';
  static const String _prefLegacyPurged = 'private_space_v3_handwriting_purged';
  static const String _prefRecordsV2Purged = 'bowel_records_v2_schema_purged';

  static late Box<String> _recordsBox;
  static late Box<String> _entriesBox;

  /// 初始化 Hive；一次性清除 v1 Private Space 条目（不迁移）。
  static Future<void> init() async {
    await Hive.initFlutter();
    _recordsBox = await Hive.openBox<String>(_boxRecords);
    _entriesBox = await Hive.openBox<String>(_boxEntries);
    await _purgeLegacyPrivateEntriesOnce();
    await _purgeLegacyBowelRecordsOnce();
  }

  /// 升级至 v2 schema 时一次性清空旧版排便记录（不迁移）。
  static Future<void> _purgeLegacyBowelRecordsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefRecordsV2Purged) == true) return;
    await _recordsBox.clear();
    await prefs.setBool(_prefRecordsV2Purged, true);
  }

  /// 首次升级至 schema v2 时一次性清空私人空间 Hive box（不迁移）。
  static Future<void> _purgeLegacyPrivateEntriesOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefLegacyPurged) == true) return;
    await _entriesBox.clear();
    await prefs.setBool(_prefLegacyPurged, true);
  }

  // ----- 排便记录 -----

  static Future<void> saveRecord(BowelRecord record) async {
    await _recordsBox.put(record.id, jsonEncode(record.toJson()));
  }

  static Future<void> deleteRecord(String id) async {
    await _recordsBox.delete(id);
  }

  static List<BowelRecord> getAllRecords() {
    return _recordsBox.values
        .map((s) => BowelRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  static BowelRecord? getRecord(String id) {
    final s = _recordsBox.get(id);
    if (s == null) return null;
    return BowelRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  static List<BowelRecord> getRecordsInRange(DateTime start, DateTime end) {
    return getAllRecords().where((r) {
      return !r.dateTime.isBefore(start) && !r.dateTime.isAfter(end);
    }).toList();
  }

  // ----- 私人空间 -----

  static Future<void> saveEntry(PrivateEntry entry) async {
    await _entriesBox.put(entry.id, jsonEncode(entry.toJson()));
  }

  static Future<void> deleteEntry(String id) async {
    await _entriesBox.delete(id);
  }

  static List<PrivateEntry> getAllEntries() {
    return _entriesBox.values
        .map((s) => PrivateEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .where((e) => e.schemaVersion >= kPrivateEntrySchemaVersion)
        .toList()
      ..sort((a, b) {
        final aPinned = a.tags.contains('pinned');
        final bPinned = b.tags.contains('pinned');
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        final aPinnedSortKey = a.tags.contains('pinned') ? a.createdAt : a.updatedAt;
        final bPinnedSortKey = b.tags.contains('pinned') ? b.createdAt : b.updatedAt;
        return bPinnedSortKey.compareTo(aPinnedSortKey);
      });
  }

  static PrivateEntry? getEntry(String id) {
    final s = _entriesBox.get(id);
    if (s == null) return null;
    return PrivateEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  /// 导出全部数据（用于云端备份）
  static Map<String, dynamic> exportAll() {
    return {
      'records': getAllRecords().map((r) => r.toJson()).toList(),
      'entries': getAllEntries().map((e) => e.toJson()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  /// 从备份恢复
  static Future<void> importFromBackup(Map<String, dynamic> data) async {
    final records = (data['records'] as List<dynamic>?)
        ?.map((e) => BowelRecord.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    final entries = (data['entries'] as List<dynamic>?)
        ?.map((e) => PrivateEntry.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    for (final r in records) {
      await saveRecord(r);
    }
    for (final e in entries) {
      await saveEntry(e);
    }
  }
}
