# Pupu

心理 + 生理健康管理 App（Flutter）。以「排便 session 记录」为核心，结合正念计时、结构化问卷、趋势分析与私人笔记，帮助用户温和地觉察身体状态。

> 版本 `0.1.0+1` · 本地优先（Hive），Supabase 云端备份已预留接口、尚未接入 UI。

---

## 功能概览

### 首页 · 星空（`HomeScreen`）

- 星空背景 + 呼吸动画云朵，主文案 **Flow with me**
- **点击文案** → 进入计时页
- **长按云朵** → 进入私人空间
- **右下角光晕** → 进入档案页
- **音乐星星开关**：古典 BGM 播放 / 暂停（跨日自动换曲，切后台不中断）

### 计时页（`TimerScreen`）

- Session 计时器（数字 / 波形两种显示）
- 内置引导音频（呼吸、Hz、雨声、颂钵等）与背景图切换
- 定时浮现**暖心语句**（`warm_sentences_timer.dart`）
- 结束 session 后可填写 **Log with me** 结构化问卷
- 退出前确认对话框，防止误触丢失进度
- 记录写入本地：`BowelRecord`（开始时间 + 时长 + 问卷答案）

### 档案页（`NewArchiveScreen`）

左右滑动切换两个视图：

| 视图 | 说明 |
|------|------|
| **Logs** | 按日浏览记录；补填 / 编辑问卷；删除记录 |
| **Chart Analysis** | 日历热力图、状态分布、趋势曲线、Issue 拆解（生理 / 心理 / 外部因素） |

图表逻辑见 `chart_analysis_logic.dart` 与 `status_scoring.dart`，支持 7 日 / 自定义日期窗口。

### 私人空间（`PrivateSpaceScreen`）

- 富文本文档编辑器（schema v3，操作式 undo/redo）
- 支持**文字、图片（相册/相机）、语音**混排
- 自定义**分类标签**与历史列表
- 媒体文件存本地（`private_media_storage.dart`），权限由 `permission_handler` 管理

### 问卷（`questionnaire_spec.dart`）

计时结束或档案页补录时触发的多步问卷，覆盖：

- 排便结果、用力程度、排空感、形态与颜色
- 血/黏液/油性等观察项
- 过程中的疼痛、焦虑、阻塞感
- （可选）当日其他不适、饮食/作息/压力等背景因素

问卷为**英文 UI**，答案编码后存入 `BowelRecord.questionnaireAnswers`。

---

## 技术栈

| 类别 | 选型 |
|------|------|
| 框架 | Flutter 3.x / Dart SDK `^3.12.0` |
| 状态管理 | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) `^3.3.2` |
| 本地存储 | [Hive](https://pub.dev/packages/hive) + [shared_preferences](https://pub.dev/packages/shared_preferences) |
| 云端（预留） | [Supabase](https://supabase.com) — 认证 + JSON 备份 |
| 音频 | [audioplayers](https://pub.dev/packages/audioplayers)（计时页 + 首页 BGM） |
| 录音 | [record](https://pub.dev/packages/record)（私人空间语音） |
| 媒体 | [image_picker](https://pub.dev/packages/image_picker) + [permission_handler](https://pub.dev/packages/permission_handler) |
| 工具 | intl、uuid |

---

## 支持平台

| 平台 | 状态 |
|------|------|
| **Android** | ✅ 已有 `android/` 工程 |
| **Web** | ✅ 已有 `web/` 工程 |
| **iOS** | ⚠️ 尚未生成；需执行 `flutter create . --platforms=ios` |

App 启动时锁定竖屏（`main.dart`）。

---

## 快速开始

### 环境要求

- [Flutter SDK](https://docs.flutter.dev/get-started/install)（含 Dart `^3.12.0`）
- Android Studio / VS Code + Flutter 插件
- （可选）Supabase 账号

### 安装与运行

```bash
cd "Pupu app"
flutter pub get
flutter run
```

指定设备：

```bash
flutter run -d chrome      # Web
flutter run -d <device-id> # Android 模拟器或真机
```

若 Android 工程不完整：

```bash
flutter create . --project-name pupu --org com.pupu
```

### 静态分析

```bash
flutter analyze
```

### 测试

```bash
flutter test
```

当前测试覆盖问卷校验、图表逻辑、私人空间文档控制器、权限助手、删除对话框、计时退出流程等（`test/` 目录，19 个测试文件）。

---

## 项目结构

```
lib/
├── main.dart                 # 入口：Hive 初始化、Supabase 可选初始化、竖屏锁定
├── app.dart                  # MaterialApp + 夜间主题
├── core/                     # 主题、字体、常量、通用 Widget（玻璃对话框等）
├── models/
│   ├── bowel_record.dart     # 排便 session 记录
│   └── private_entry.dart    # 私人空间条目（schema v3）
├── providers/                # Riverpod：records / entries / audio
├── services/
│   ├── local_storage.dart    # Hive CRUD + 导入导出
│   ├── supabase_service.dart # 云端备份（尚未接线 UI）
│   ├── private_media_storage.dart
│   └── private_permission_helper.dart
└── features/
    ├── home/                 # 星空首页 + BGM
    ├── timer/                # 计时、音频、session 摘要、暖心语句
    ├── archive/              # 档案、日历、图表分析、日志卡片
    ├── questionnaire/        # 问卷流程、校验、编解码
    └── private_space/        # 私人笔记、分类、历史、语音

assets/
├── audio/                    # 计时页引导音频
├── audio/home_music/         # 首页古典 BGM
├── fonts/                    # Josefin Sans、Raleway、Inter、Nunito
└── images/                   # 背景与 UI 素材

supabase/migrations/          # 云端表结构 SQL
test/                         # 单元 / Widget 测试
```

---

## 数据模型

### `BowelRecord`

```dart
{
  id, dateTime,           // session 开始时间
  durationSeconds,        // 计时时长
  questionnaireAnswers, // Map<questionId, List<optionValue>>
  createdAt
}
```

### `PrivateEntry`（schema v3）

文档式内容块（文本 / 图片 / 语音），含分类、时间戳；媒体路径指向 app 私有目录。

### 本地存储

- Hive box `bowel_records` — 排便记录
- Hive box `private_entries` — 私人空间
- Schema 升级时会**一次性清空**旧数据（不迁移），见 `LocalStorage.init()`

---

## 架构约定（ARCH-001）

```
UI → Feature Logic → Domain → Data
```

- **UI 层**：渲染、动画、导航、`ref.watch`；不写业务规则
- **Provider 模式**：`XWithRefreshProvider` + `bumpXRefresh()` 触发列表刷新
- **文件体量**（软约束）：Screen 建议 < 400 行，超出则拆到 `widgets/` 或纯 Dart 逻辑文件
- 已拆分的大屏：`timer_screen.dart`、`private_space_screen.dart`

---

## Supabase 配置（可选）

> 默认不配置 Supabase 也可完整使用本地功能。`SupabaseService` 已实现 upload / download / sync，**尚未接入任何 UI 入口**。

1. 在 [Supabase](https://supabase.com) 创建项目
2. 在 SQL Editor 依次执行：
   - `supabase/migrations/001_initial.sql`
   - `supabase/migrations/002_storage_attachments.sql`（Storage bucket 需在 Dashboard 手动创建）
3. 修改 `lib/main.dart` 中的占位符：

```dart
const String _supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const String _supabasePublishableKey = 'YOUR_PUBLISHABLE_KEY';
```

4. 后续可在设置页接入 `SupabaseService.signInAnonymously()` / `uploadBackup()` / `downloadBackup()`

---

## 设计资源

- Figma 交互原型参考：`Private_Space_Entry/Figma/Interactivestarnotebox-review/`
- 视觉主题：宇宙夜间色板（`core/theme.dart`、`core/constants.dart`）
- 字体映射：UI 标注 SF Pro → 实际加载 Inter / Nunito

---

## 开发说明

### Cursor / 迭代文档

- 计划与 Issue：`.cursor/plans/`、`.cursor/issues/`
- 架构与 UI 规范：`.cursor/docs/`

### 已知限制

- 无 PDF / Excel / CSV 导出（CHANGELOG 中相关描述为规划项，未实现）
- 无 GAD-2 / PHQ-2 独立心理量表；心理维度通过排便问卷与 Issue 拆解体现
- iOS 工程未生成
- 云端备份需后续 UI ticket 接线

---

## License

未指定开源协议。如需对外发布，请先补充 LICENSE 文件。
