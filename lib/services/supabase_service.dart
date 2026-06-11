/// Supabase 云端备份服务
/// 认证 + 本地↔云端同步

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pupu/services/local_storage.dart' as local_storage;

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// 是否已登录
  static bool get isLoggedIn => client.auth.currentUser != null;

  /// 当前用户 ID（用于 RLS）
  static String? get userId => client.auth.currentUser?.id;

  /// 匿名登录（用于备份，无邮箱门槛）
  static Future<void> signInAnonymously() async {
    await client.auth.signInAnonymously();
  }

  /// 邮箱登录
  static Future<void> signInWithEmail(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  /// 邮箱注册
  static Future<void> signUpWithEmail(String email, String password) async {
    await client.auth.signUp(email: email, password: password);
  }

  /// 登出
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// 本地 → 云端 上传备份
  static Future<void> uploadBackup() async {
    if (userId == null) return;

    final data = local_storage.LocalStorage.exportAll();
    await client.from('user_backups').upsert({
      'user_id': userId,
      'data': data,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// 云端 → 本地 恢复
  static Future<void> downloadBackup() async {
    if (userId == null) return;

    final res = await client
        .from('user_backups')
        .select('data')
        .eq('user_id', userId!)
        .maybeSingle();

    if (res != null && res['data'] != null) {
      await local_storage.LocalStorage.importFromBackup(
        res['data'] as Map<String, dynamic>,
      );
    }
  }

  /// 同步：先下载云端，再合并上传（以本地为主，云端覆盖后上传）
  static Future<void> sync() async {
    if (!isLoggedIn) return;
    await downloadBackup();
    await uploadBackup();
  }
}
