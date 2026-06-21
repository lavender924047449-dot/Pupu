# PLAN-CHART-CALENDAR-001: Chart Analysis 日历快速跳转

**Overall Progress:** `88%`

---

## TLDR

为 Chart Analysis 的 4 处日期导航栏增加日历快速跳转：点击日期文字弹出平台自适应日历（iOS 滚轮 / Android 月历），选择日期后跳转到对应时间窗口块。不新增图标，现有热力格 `grid_on` 图标不变。

---

## 最终规格

| 项 | 决策 |
|----|------|
| 触发 | 点击日期文字打开日历；点箭头只翻页不打开 |
| 新图标 | **不加**——仅日期文字可点 |
| 热力格图标 | 保留不动，原有 2 处 `grid_on` 不受影响 |
| iOS 日历 | `CupertinoDatePicker`（date mode 滚轮） |
| Android 日历 | `CalendarDatePicker`（月历网格） |
| 弹窗样式 | 居中玻璃风弹窗（与 heatmap dialog 一致），非底部 sheet |
| 默认日期 | **今天** |
| 日期范围 | 2025-01-01 ~ 2100-12-31 |
| 跳转对齐 | 与箭头相同的整块对齐：`offset = ((today - selected).inDays ~/ windowDays) * windowDays` |
| 关闭 | 选日期**不自动关**；点空白处关闭弹窗，关闭时按所选日期跳转 |
| 无数据日期 | 允许跳转，展示空态/limited 提示 |
| 范围 | 仅 Chart Analysis（不含 Log Calendar / Logs） |

---

## Critical Decisions

- **无新图标，日期文字即入口** — 4 处导航一致；视觉不增加噪音；`grid_on` 保持各自语义
- **弹窗内选日期 + 弹窗关闭时跳转** — dialog 内部跟踪 `selectedDate`，pop 时返回；避免 dialog 打开状态下刷父 Widget 的复杂度
- **offset 计算下沉 Logic 层** — `chart_analysis_logic.dart` 新增纯函数 `offsetForSelectedDate()`，可单测、与 UI 解耦
- **平台分支仅在 dialog 内部** — `dart:io Platform.isIOS` 决定渲染哪种 Picker；外部调用方无感
- **`_buildWindowNavigator` 最小改动** — 仅给日期 Text 包 GestureDetector + 新参 `onDateTextTap`，不改 Row 布局

---

## 4 处导航调用点速查

| # | 区块 | offset 变量 | 行号 | 现有 `onCalendarTap`（热力格） |
|---|------|-------------|------|-------------------------------|
| 1 | Overall Status Distribution | `_statusDistributionWindowOffset` | ~170 | ✅ 有 |
| 2 | Status Trends | `_statusTrendsWindowOffset` | ~230 | ❌ 无 |
| 3 | Issue Radar View | `_issueWindowOffset` | ~1765 | ❌ 无 |
| 4 | Issue Stacked Bar / Line View | `_issueWindowOffset`（同 #3） | ~1789 | ✅ 有 |

---

## Tasks

- [x] 🟩 **Step 1: Logic 层 — `offsetForSelectedDate`** — `chart_analysis_logic.dart`
  - [x] 🟩 1a. 新增 `int offsetForSelectedDate({required DateTime selectedDate, required int windowDays, DateTime? now})`
    - 公式：`max(0, (today.difference(normalizeDay(selected)).inDays ~/ windowDays) * windowDays)`
    - 不依赖 records（无需 maxOffset clamp，UI 侧已有 `resolveChartWindow` 做 clamp）
  - [x] 🟩 1b. 单元测试 `test/chart_analysis_logic_test.dart`
    - 选今天 → offset 0
    - 选 7 天前 → offset 7（7 天模式）
    - 选 8 天前 → offset 7（对齐到块）
    - 选未来日期 → offset 0（clamp）
    - 30 天模式边界验证

- [x] 🟩 **Step 2: UI — `_buildWindowNavigator` 增加日期文字点击** — `chart_analysis_card.dart`
  - [x] 🟩 2a. 新增参数 `VoidCallback? onDateTextTap`
  - [x] 🟩 2b. 将 `Text(window.title, ...)` 包入 `GestureDetector(onTap: onDateTextTap, ...)`
  - [x] 🟩 2c. 日期文字增加视觉暗示（下划线虚线 or 轻微 opacity 变化），让用户发现可点击——**可选**，先不加，观察反馈

- [x] 🟩 **Step 3: UI — 平台自适应日历弹窗** — `chart_analysis_card.dart`
  - [x] 🟩 3a. 新增 `Future<DateTime?> _showChartDatePicker(BuildContext context)` 方法
  - [x] 🟩 3b. 玻璃风 Dialog 外壳（复用 heatmap dialog 同款视觉：`BackdropFilter` + 半透明白底 + 圆角）
  - [x] 🟩 3c. iOS 分支：`CupertinoDatePicker(mode: CupertinoDatePickerMode.date, ...)`
    - `minimumDate: DateTime(2025, 1, 1)`
    - `maximumDate: DateTime(2100, 12, 31)`
    - `initialDateTime: DateTime.now()`（normalizeDay）
    - `onDateTimeChanged` → 更新 dialog 内 `selectedDate`
  - [x] 🟩 3d. Android 分支：`CalendarDatePicker(...)`
    - `firstDate: DateTime(2025, 1, 1)`
    - `lastDate: DateTime(2100, 12, 31)`
    - `initialDate: DateTime.now()`
    - `onDateChanged` → 更新 dialog 内 `selectedDate`
  - [x] 🟩 3e. 点空白处关闭；dialog pop 时返回 `selectedDate`
  - [x] 🟩 3f. 深色主题适配：CalendarDatePicker 需包 `Theme(data: ...)` 覆盖文字/选中色为白/蓝

- [x] 🟩 **Step 4: 接线 — 4 处导航全部传入 `onDateTextTap`** — `chart_analysis_card.dart`
  - [x] 🟩 4a. **Distribution**（~L170）：`onDateTextTap` → `_showChartDatePicker` → `offsetForSelectedDate(days)` → `setState _statusDistributionWindowOffset`
  - [x] 🟩 4b. **Status Trends**（~L230）：同上 → `setState _statusTrendsWindowOffset`；30 天模式触发 `_pendingStatusTrendScrollToEnd = true`
  - [x] 🟩 4c. **Issue Radar**（~L1765）：同上 → `setState _issueWindowOffset`；30 天模式触发 `_pendingIssueTrendScrollToEnd = true`
  - [x] 🟩 4d. **Issue Bar/Line**（~L1789）：同上 → 与 Radar 共用 `_issueWindowOffset`；同 4c 逻辑

- [ ] 🟨 **Step 5: 回归验证**
  - [x] 🟩 5a. `flutter analyze` 无新 warning
  - [x] 🟩 5b. 现有 `test/chart_analysis_logic_test.dart` 全绿
  - [ ] 🟥 5c. 热力格 `grid_on` 功能不受影响（手动）
  - [ ] 🟥 5d. 手动验证 4 处日历跳转
  - [ ] 🟥 5e. 手动验证选 2025 年无数据日期 → 空态展示正确

---

## 文件清单

| 操作 | 路径 |
|------|------|
| 修改 | `lib/features/archive/chart_analysis_logic.dart`（+1 函数 ~12 行） |
| 修改 | `lib/features/archive/chart_analysis_card.dart`（改 navigator + 新 dialog ~80 行 + 4 处接线） |
| 修改 | `test/chart_analysis_logic_test.dart`（+1 test group ~30 行） |

**总改动量：~120 行净增**，无新文件。

---

## 执行顺序理由

1→2→3→4→5 是严格依赖链：
- Step 1（Logic）零 UI 依赖，可独立写 + 测
- Step 2（Navigator 参数）是 Step 4 的前置，改动最小
- Step 3（Dialog）是 Step 4 的前置，自包含
- Step 4（接线）依赖 1+2+3 全部就绪
- Step 5 收尾

---

## 风险

- `CupertinoDatePicker` 需 `import 'package:flutter/cupertino.dart'`；若项目未导入需确认无冲突
- `Platform.isIOS` 需 `import 'dart:io'`；Web 平台不适用——当前仅 iOS/Android，可接受
- CalendarDatePicker 默认 Material 亮色；需 `Theme` 包裹做深色适配，可能需要微调颜色直到视觉满意
