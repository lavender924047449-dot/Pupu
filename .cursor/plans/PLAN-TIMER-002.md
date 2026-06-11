# TIMER-002 音乐按钮与音频面板视觉微调实施计划

**Overall Progress:** `100%`

## TLDR

在 TIMER-001 已落地架构上，做**纯视觉抛光**：音乐按钮右移 16px、背景对齐主操作按钮玻璃样式、🎵 改白；音频面板列表上移并收紧标题间距；旋转改为 **6s/圈**。仅改 2 个文件，无新 state、无新 provider。

---

## Critical Decisions

- **不扩架构** — TIMER-001 的 3 文件分层已足够；本期只动 `audio_picker.dart` + `timer_screen.dart`，不新建 widget / provider
- **样式对齐方式** — `TimerMusicButton` 内联复制 `_actionButton` 容器三参数（`white@7%`、阴影、`borderRadius` 用 `1000` 保正圆），加注释锚点 `timer_screen.dart _actionButton`；不抽第三文件（改动面 <10 行，抽公共层收益低）
- **间距常量** — `_buildActionRow` 三处 `SizedBox(width: 8)` 统一改为 `16`；可用局部常量 `const _musicButtonGap = 16.0` 防漂移
- **面板排版** — 顶距 `sy(26)→sy(20)`；标题去掉双换行，改 `SizedBox(height: sy(8))` 控制标题与列表间距（Figma 基准约 8px）
- **旋转速度** — 已确认：**6s/圈**（`_audioRotationController.duration`）

---

## 变更映射

| 需求 | 文件 | 改动点 |
|------|------|--------|
| 右移 +8px（总 16px） | `timer_screen.dart` | `_buildActionRow` 三处 gap |
| 按钮玻璃样式 + 白 🎵 | `audio_picker.dart` | `TimerMusicButton` decoration + TextStyle |
| 列表上移 + 标题间距 | `audio_picker.dart` | `AudioPickerLayer` padding + 标题结构 |
| 6s/圈 | `timer_screen.dart` | `initState` `_audioRotationController` duration |

---

## 目标参数速查

### TimerMusicButton（33×33 圆形）

```dart
// 对齐 _actionButton 容器（非文字层）
color: Colors.white.withValues(alpha: 0.07)
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1000))
shadows: [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 8))]
// emoji
color: Colors.white
```

### AudioPickerLayer 内容区

```dart
padding: EdgeInsets.only(top: sy(20))   // 原 sy(26)
// 标题
Text('Choose an audio you like:')      // 去掉 trailing \n\n
SizedBox(height: sy(8))                // 标题与列表间距
// 列表 generate...
```

### 旋转

```dart
_audioRotationController = AnimationController(
  vsync: this,
  duration: const Duration(seconds: 6),  // 原 3
);
```

---

## Tasks

- [x] 🟩 **Step 1: 音乐按钮位置**
  - [x] 🟩 `timer_screen.dart` `_buildActionRow`：idle / running / paused 三处 gap 已统一为 `16`（以局部常量 `musicButtonGap`）
  - [x] 🟩 静态验算 running 宽度：309/393 仍安全

- [x] 🟩 **Step 2: 音乐按钮样式**
  - [x] 🟩 `audio_picker.dart` `TimerMusicButton`：已移除 `#F7F7F7` / `0x1E000000` 旧参数
  - [x] 🟩 应用与 `_actionButton` 一致的玻璃容器参数（圆角 `1000` 保持正圆）
  - [x] 🟩 🎵 `color` 改为 `Colors.white`

- [x] 🟩 **Step 3: 音频面板排版**
  - [x] 🟩 内容区 `padding.top`：`sy(26)` → `sy(20)`
  - [x] 🟩 标题改为单行文案 + `SizedBox(height: sy(8))` 再接 12 条列表
  - [x] 🟩 真机验收：列表上移、标题间距观感通过

- [x] 🟩 **Step 4: 旋转速度**
  - [x] 🟩 `timer_screen.dart` `_audioRotationController` duration：`3s` → `6s`
  - [x] 🟩 旋转状态机逻辑未改，A→B 切换不中断（沿用 TIMER-001 逻辑）

- [x] 🟩 **Step 5: 验证与收尾**
  - [x] 🟩 `flutter analyze` 已执行；`audio_picker.dart` 无新增问题，`timer_screen.dart` 仅既有 info 级提示
  - [x] 🟩 真机 Test Plan 6 项全部通过（2026-06-06）
  - [x] 🟩 本 plan 进度已更新至 100%

---

## Test Plan（真机验收 2026-06-06）

| # | 用例 | 状态 | 验证方式 |
|---|------|------|----------|
| 1 | idle：Start 与 🎵 间距 16px | 🟩 通过 | 真机 + 代码 `musicButtonGap = 16` |
| 2 | running / paused：🎵 间距 16px | 🟩 通过 | 真机 + 三态 Row 均用同一 gap |
| 3 | 🎵 背景玻璃半透明（同 Start） | 🟩 通过 | 真机 + `white@7%` + `0x33000000` 阴影 |
| 4 | 🎵 符号白色 | 🟩 通过 | 真机 + `Colors.white` |
| 5 | 面板列表上移、标题间距收紧 | 🟩 通过 | 真机 + `sy(20)` + `SizedBox(sy(8))` |
| 6 | 旋转约 6s/圈 | 🟩 通过 | 真机 + `Duration(seconds: 6)` |

**结论：** TIMER-002 视觉微调验收完成，可关闭 issue。

---

## 不在本期范围

- 抽 `timer_button_styles.dart` 公共样式文件
- 修改面板尺寸 / 液体玻璃 / 交互逻辑
- `audio_provider` 接入

---

## 回滚

还原 `audio_picker.dart` 与 `timer_screen.dart` 中上述 4 处改动即可。

---

## 变更文件清单

| 文件 | 操作 |
|------|------|
| `lib/features/timer/widgets/audio_picker.dart` | 修改 |
| `lib/features/timer/timer_screen.dart` | 修改 |
| `.cursor/issues/TIMER-002-*.md` | 参考 |
| `.cursor/plans/PLAN-TIMER-002.md` | 本文档 |
