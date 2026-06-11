# Pupu

心理+生理健康管理 App。MVP 包含：排便记录、健康管理、私人空间。

## 技术栈

- Flutter (Dart)
- Supabase (云端备份)
- Hive (本地存储)
- flutter_riverpod (状态管理)
- audioplayers (本地音频)

## 运行

1. 安装 [Flutter](https://flutter.dev/docs/get-started/install)
2. 克隆项目后执行：
   ```bash
   cd "Pupu app"
   flutter pub get
   flutter run
   ```
3. 若 Android/iOS 目录不完整，可执行：
   ```bash
   flutter create . --project-name pupu --org com.pupu
   ```

## 当前架构约定（ARCH-001）

- 分层：`UI -> Feature Logic -> Domain -> Data`
- UI 层仅做渲染、动画、导航与 Provider watch，避免内联业务规则
- Provider 统一模式：`XWithRefreshProvider + bumpXRefresh`
- 文件体量约束（软约束）：
  - `Screen` 建议 `< 400` 行
  - 超过后优先抽 `widgets/` 子组件与纯 Dart 逻辑文件
- God Screen 拆分已完成：
  - `private_space_screen.dart` 已拆分为 history/background/notepad/categories 子模块
  - `timer_screen.dart` 已拆分为 `timer_session_summary` / `timer_questionnaire_host` / `timer_dialogs` / `timer_wave_painter`

## Supabase 配置

1. 在 [Supabase](https://supabase.com) 创建项目
2. 在 SQL Editor 中执行 `supabase/migrations/001_initial.sql`
3. 将 `lib/main.dart` 中的 `_supabaseUrl` 和 `_supabaseAnonKey` 替换为你的项目值

> 说明：当前默认运行以本地 Hive 为主，Supabase 接线保留为后续功能迭代。

## 功能

- **排便记录**：布里斯托形态、颜色、疼痛、时长、血/黏液、备注；图表与周/月/年统计
- **健康管理**：GAD-2 + PHQ-2 问卷；引导内容（正念、暖心话语）；基于记录的倾向提示
- **私人空间**：日记/灵感/宣泄，支持标签与分类
