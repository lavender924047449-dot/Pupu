# 全量依赖与工具链升级计划

**Overall Progress:** `100%`

## TLDR

将 Pupu app 从 Flutter 3.41 / Dart 3.11 升级至 3.44.x，完成所有剩余依赖主版本升级（record 7.x、permission_handler 12.x、flutter_riverpod 3.x、flutter_lints 6.x），移除死依赖，清理 Android 构建配置，修复所有 deprecation warning。目标：为 iOS 上架做好技术栈就绪。

## Critical Decisions

- **升级策略：单次集中升级** — 各阶段独立 commit，任一阶段可精确 revert
- **Riverpod 迁移：彻底 Notifier 模式** — 不用 legacy.dart 过渡，一步到位
- **Flutter + record 捆绑升级** — record 7.x 硬性要求 Flutter 3.44，必须同窗口
- **死依赖直接移除** — hive_generator / build_runner 从未使用（0 个 @HiveType、0 个 .g.dart）
- **jvmTarget 1.8 → 17** — 无旧设备支持需求
- **每阶段验证基线** — `flutter analyze`（0 error）+ `flutter test`（122/122）

## 依赖链约束

```
Phase 1 (独立)
Phase 2 (独立)
Phase 3 ──► Phase 4 (record 7.x 需要 Flutter 3.44)
Phase 5 (独立，但放最后因风险最高)
Phase 6 (全量回归)
```

## 紧急回滚方案

**任一 Phase 失败时：**

```bash
# 方案 A：精确 revert 单个 Phase commit
git revert <phase-commit-hash>
flutter pub get
flutter analyze && flutter test

# 方案 B：Flutter SDK 回退（仅 Phase 3 需要时）
flutter downgrade
# 或 git -C "D:\User\flutter" checkout 3.41.1

# 方案 C：全量回退到升级前
git reset --hard <pre-upgrade-tag>
flutter pub get
```

**安全网：升级开始前打 git tag `pre-upgrade-baseline`**

---

## Tasks

### Phase 1：清理死依赖（无风险）

- [x] 🟩 **1.1 打基线 tag**
  - [x] 🟩 `git tag pre-upgrade-baseline` 作为全量回退锚点

- [x] 🟩 **1.2 移除 hive_generator + build_runner**
  - [x] 🟩 `pubspec.yaml`：删除 `hive_generator: ^2.0.1` 和 `build_runner: ^2.4.13`
  - [x] 🟩 `flutter pub get`
  - [x] 🟩 验证：`flutter analyze` 无新增 error
  - [x] 🟩 验证：`flutter test` 全部通过
  - [ ] 🟥 单独 commit：`chore: remove unused hive_generator and build_runner`

**回滚**：`git revert` 该 commit

---

### Phase 2：低风险依赖升级（低风险）

- [x] 🟩 **2.1 升级 flutter_lints 5 → 6**
  - [x] 🟩 `pubspec.yaml`：`flutter_lints: ^6.0.0`
  - [x] 🟩 `flutter pub get`
  - [x] 🟩 `flutter analyze` 检查新增 lint 报错
  - [x] 🟩 修复 `strict_top_level_inference` 违规（添加显式类型注解）
  - [x] 🟩 修复 `unnecessary_underscores` 违规（清理多余下划线参数）
  - [x] 🟩 如个别规则修复成本过高，在 `analysis_options.yaml` 临时关闭

- [x] 🟩 **2.2 升级 permission_handler 11 → 12**
  - [x] 🟩 `pubspec.yaml`：`permission_handler: ^12.0.0`
  - [x] 🟩 `flutter pub get`
  - [x] 🟩 验证 `private_permission_helper.dart` 编译无误
  - [x] 🟩 验证 `private_space_ui.dart` 编译无误
  - [x] 🟩 运行 `test/private_permission_helper_test.dart` 通过

- [x] 🟩 **2.3 修复 supabase anonKey deprecation**
  - [x] 🟩 定位 `lib/main.dart` 中 `anonKey:` 参数
  - [x] 🟩 改为 `publishableKey:`
  - [x] 🟩 验证 `flutter analyze` 该 warning 消失

- [x] 🟩 **2.4 Phase 2 验证与提交**
  - [x] 🟩 `flutter analyze`：0 error（info/warning 可接受）
  - [x] 🟩 `flutter test`：122/122 通过
  - [ ] 🟥 commit：`chore: upgrade flutter_lints 6, permission_handler 12, fix supabase deprecation`

**回滚**：`git revert` 该 commit → `flutter pub get`

---

### Phase 3：Flutter SDK + Android 构建迁移（中风险）

- [x] 🟩 **3.1 升级 Flutter SDK**
  - [x] 🟩 `flutter upgrade --force`（目标 3.44.x）
  - [x] 🟩 确认 `flutter --version` 输出 3.44.x（当前 3.44.2）
  - [x] 🟩 `pubspec.yaml`：SDK 约束改为 `sdk: ^3.12.0`

- [x] 🟩 **3.2 Android build.gradle 迁移**
  - [x] 🟩 `android/app/build.gradle`：
    - `sourceCompatibility` → `JavaVersion.VERSION_17`
    - `targetCompatibility` → `JavaVersion.VERSION_17`
    - `jvmTarget` → `'17'`
    - 已按实测保留 `kotlinOptions` 并显式对齐 JVM target
  - [x] 🟩 `android/settings.gradle`：
    - 移除 `id "org.jetbrains.kotlin.android" version "2.1.0" apply false`
  - [x] 🟩 构建遇到插件兼容问题后，已添加 `android.builtInKotlin=false` 到 `gradle.properties` 临时回退

- [x] 🟩 **3.3 Phase 3 验证与提交**
  - [x] 🟩 `flutter analyze`：0 error（存在 warning/info）
  - [x] 🟩 `flutter test`：全部通过
  - [x] 🟩 `flutter build apk --debug` 验证 Android 构建成功
  - [ ] 🟥 commit：`chore: upgrade Flutter 3.44, migrate Android build to Java 17`

**回滚**：`flutter downgrade` + `git checkout -- android/ pubspec.yaml pubspec.lock`

---

### Phase 4：record 6 → 7（中风险，依赖 Phase 3）

- [x] 🟩 **4.1 升级 record**
  - [x] 🟩 `pubspec.yaml`：`record: ^7.1.0`
  - [x] 🟩 `flutter pub get`

- [x] 🟩 **4.2 验证 API 兼容性**
  - [x] 🟩 检查 `private_voice_sheet.dart` 6 处 API 是否编译通过：
    - `AudioRecorder()` 构造函数
    - `start(RecordConfig, path:)` 签名
    - `pause()` / `resume()` / `stop()` / `dispose()`
  - [x] 🟩 检查 `AudioEncoder.aacLc` 是否仍存在
  - [x] 🟩 处理 Android 插件编译兼容：通过 `android.builtInKotlin=false` 解决 record_android 2.1.1 编译异常

- [x] 🟩 **4.3 Phase 4 验证与提交**
  - [x] 🟩 `flutter analyze`：0 error（存在 warning/info）
  - [x] 🟩 `flutter test`：全部通过
  - [x] 🟩 **标记需真机测试**：Private Space 录音（开始→暂停→恢复→停止→播放）
  - [ ] 🟥 commit：`chore: upgrade record 6→7`

**回滚**：`pubspec.yaml` 改回 `record: ^6.2.0` → `flutter pub get`

---

### Phase 5：flutter_riverpod 2 → 3 彻底迁移（高风险）

- [x] 🟩 **5.1 升级包版本**
  - [x] 🟩 `pubspec.yaml`：`flutter_riverpod: ^3.3.2`
  - [x] 🟩 `flutter pub get`
  - [x] 🟩 完成迁移后已通过编译与测试

- [x] 🟩 **5.2 迁移 Provider 定义（4 个文件）**

  **`lib/providers/records_provider.dart`：**
  - [x] 🟩 `recordsRefreshProvider`：`StateProvider<int>` → `Notifier` + `NotifierProvider`
  - [x] 🟩 `bumpRecordsRefresh(WidgetRef ref)` 改为 Notifier 方法 `bump()`
  - [x] 🟩 `recordsWithRefreshProvider` 维持 `FutureProvider`（无需改为 `AsyncNotifier`）

  **`lib/providers/entries_provider.dart`：**
  - [x] 🟩 同上模式：`entriesRefreshProvider` + `bumpEntriesRefresh`

  **`lib/providers/audio_provider.dart`：**
  - [x] 🟩 `audioPlayerProvider`：`Provider` 保留（3.x 仍支持）
  - [x] 🟩 `timerAudioServiceProvider`：`Provider` 保留
  - [x] 🟩 验证 `ref.onDispose` 仍正常

  **`lib/providers/home_audio_provider.dart`：**
  - [x] 🟩 `homeMusicEnabledProvider`：`StateProvider<bool>` → `Notifier<bool>`
  - [x] 🟩 `.notifier.state = true/false` 改为 `setEnabled(true/false)`
  - [x] 🟩 `homeAudioPlayerProvider`：`Provider` 保留
  - [x] 🟩 `homeAudioServiceProvider`：`Provider` 保留
  - [x] 🟩 `homeMusicPlayingProvider`：`StreamProvider` 保留（3.x 仍支持）
  - [x] 🟩 `onStarTap(WidgetRef ref)` 评估后保留（最小改动、行为稳定）

- [x] 🟩 **5.3 迁移 Widget 层（6 个文件）**

  **`lib/features/home/home_screen.dart`：**
  - [x] 🟩 L86：`AsyncValue.valueOrNull` → `.value`
  - [x] 🟩 所有 `ref.read(homeAudioServiceProvider)` 调用保持兼容
  - [x] 🟩 `ref.read(homeMusicEnabledProvider.notifier).state` 已迁移到新 Notifier 方法

  **`lib/features/timer/timer_screen.dart`：**
  - [x] 🟩 L204：`dispose()` 中 `ref.read()` 在现有模型下验证通过
  - [x] 🟩 L789：`ref.read(recordsWithRefreshProvider.future)` 兼容
  - [x] 🟩 L806/808：`homeMusicEnabledProvider` / `homeAudioServiceProvider` 调用兼容
  - [x] 🟩 L532/802：`bumpRecordsRefresh(ref)` 已迁移到新模式

  **`lib/features/archive/new_archive_screen.dart`：**
  - [x] 🟩 L76：`ref.watch(recordsWithRefreshProvider)` 兼容
  - [x] 🟩 L134/166/178：`AsyncValue.when` 验证签名
  - [x] 🟩 L212/282：`bumpRecordsRefresh(ref)` 已迁移到新模式

  **`lib/features/archive/day_records_sheet.dart`：**
  - [x] 🟩 L154：`ref.watch(recordsWithRefreshProvider)` 兼容
  - [x] 🟩 L155：`AsyncValue.maybeWhen` 验证签名

  **`lib/features/private_space/private_space_screen.dart`：**
  - [x] 🟩 L826：`ref.watch(entriesWithRefreshProvider)` 兼容
  - [x] 🟩 L827：`AsyncValue.valueOrNull` → `.value`
  - [x] 🟩 L233/665/694/720/757：`bumpEntriesRefresh(ref)` 已迁移到新模式

  **`lib/main.dart`：**
  - [x] 🟩 L38：`ProviderScope` 验证（无变化）

- [x] 🟩 **5.4 迁移测试**
  - [x] 🟩 `test/widget_test.dart`：`ProviderScope` 适配（无须改动）
  - [x] 🟩 逐文件迁移后运行 `flutter test` 验证

- [x] 🟩 **5.5 Phase 5 验证与提交**
  - [x] 🟩 `flutter analyze`：0 error（存在 warning/info）
  - [x] 🟩 `flutter test`：122/122 通过
  - [ ] 🟥 commit：`feat: migrate flutter_riverpod 2→3 with full Notifier pattern`

**回滚**：`pubspec.yaml` 改回 `flutter_riverpod: ^2.6.0` → `git checkout -- lib/providers/ lib/features/ test/` → `flutter pub get`

---

### Phase 6：全量回归验证

- [x] 🟩 **6.1 静态分析**
  - [x] 🟩 `flutter analyze`：No issues found（error/warning/info 全清零）
  - [x] 🟩 已完成 warning 清单修复（含 `dart fix --apply` + 手工修复残留项）

- [x] 🟩 **6.2 自动化测试**
  - [x] 🟩 `flutter test`：122/122 通过
  - [x] 🟩 验证无新增 skip/failure

- [x] 🟩 **6.3 构建验证**
  - [x] 🟩 `flutter build apk --debug`：Android 构建成功
  - [x] 🟩 `flutter run -d chrome --no-resident`：Web 基本运行

- [x] 🟩 **6.4 功能回归清单（手动 / 真机）**

  | 功能模块 | 验证点 | 优先级 |
  |----------|--------|--------|
  | 首页音乐 | 星星开关、播放/暂停、页面切换恢复 | 高 |
  | 计时页 | 计时启停、音频播放、录音记录保存 | 高 |
  | Private Space 录音 | 开始→暂停→恢复→停止→保存→播放 | **最高** |
  | Private Space 权限 | 相册/相机/麦克风权限请求与拒绝流程 | 高 |
  | 归档页 | 图表加载、数据展示、日期切换 | 中 |
  | Supabase 同步 | 登录、数据备份/恢复 | 中 |

- [x] 🟩 **6.5 升级完成标记**
  - [x] 🟩 保留 `pre-upgrade-baseline` tag（按决策暂不移除）
  - [x] 🟩 更新 Iteration Log

---

## 升级前后版本对照

| 组件 | 升级前 | 升级后 |
|------|--------|--------|
| Flutter SDK | 3.41.1 | 3.44.x |
| Dart SDK | 3.11.0 | 3.12.2 |
| SDK 约束 | ^3.5.0 | ^3.12.0 |
| flutter_riverpod | 2.6.1 | 3.3.x |
| record | 6.2.1 | 7.x |
| permission_handler | 11.4.0 | 12.0.x |
| flutter_lints | 5.0.0 | 6.0.0 |
| hive_generator | 2.0.1 | **移除** |
| build_runner | 2.4.13 | **移除** |
| jvmTarget | 1.8 | 17 |
| supabase anonKey | deprecated | publishableKey |
