/// Pupu - 心理+生理健康管理 App
/// MVP: 排便记录、健康管理、私人空间

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pupu/app.dart';
import 'package:pupu/services/local_storage.dart' as local_storage;

// TODO: 替换为你的 Supabase 项目 URL 和 anon key
const String _supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const String _supabaseAnonKey = 'YOUR_ANON_KEY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 竖屏锁定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 初始化本地存储
  await local_storage.LocalStorage.init();

  // 初始化 Supabase（若未配置则跳过，云端备份功能不可用）
  try {
    if (!_supabaseUrl.contains('YOUR_PROJECT')) {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
    }
  } catch (_) {
    // Supabase 未配置或初始化失败，本地功能仍可用
  }

  runApp(const ProviderScope(child: PupuApp()));
}
