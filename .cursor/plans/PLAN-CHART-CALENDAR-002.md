# PLAN-CHART-CALENDAR-002: Chart Analysis 小日历有数据标记

**Overall Progress:** `88%`

---

## TLDR

为 Chart Analysis 小日历（`_showChartDatePicker`）接入与 Log Calendar 同源的记录标记：有 log 日统一蓝底（0.5）、今天蓝字无蓝底、选中日白圈；双端统一自定义月历格（替换 iOS 滚轮 / Android `CalendarDatePicker`），弹窗外壳与 Confirm 流程不变；年份选择改为单列纵向滚动。

---

## 最终规格

| 项 | 规则 |
|----|------|
| 弹窗外壳 | **不变**（玻璃风 + `Select Date` + Cancel/Confirm） |
| 月历主体 | 保持现有 Material 月历格视觉；仅 picker 区域内替换为自定义组件 |
| 年份选择 | 点击年份 → **单列纵向**年份列表（2025–2100） |
| 数据口径 | 任意 `BowelRecord`（与 Log Calendar `dailyCounts` 一致） |
| 有记录日（非今天） | `#0088FF` @ **alpha 0.5** 背景 |
| 今天 | 数字 **蓝色**；**不显示**蓝底（即使有记录） |
| 选中日 | **白色空心圆圈** |
| 选中日 + 有记录（非今天） | **蓝底 + 白圈**；数字 **白色** |
| 今天且选中 | 蓝字 + 白圈；**无**蓝底 |
| 其它日期数字 | 白色 |
| 默认月份 | 打开时显示 **今天**所在月 |
| 范围 | 2025-01-01 ~ 2100-12-31；支持左右切月 |
| 跳转 | Confirm 后 `offsetForSelectedDate`（沿用现有逻辑） |

---

## Critical Decisions

> **范式：** 从问题本质出发——需在日期格子上画自定义样式 + 改年份为单列滚动；Flutter 内置 `CalendarDatePicker` / `CupertinoDatePicker` 均无法同时满足，故只替换 **picker 区域**，外壳与数据接线不动。

| # | 决策 | 第一性原理依据 |
|---|------|----------------|
| 1 | 新建 `chart_date_picker_calendar.dart` 单一自定义月历组件，双端共用 | 一个组件消除 iOS/Android 分叉；弹窗外壳留在 `chart_analysis_card`，职责清晰 |
| 2 | 日期样式规则下沉 `chart_analysis_logic.dart` 纯函数 `resolveChartPickerDayStyle()` | 5 条叠加规则易出错；纯函数可单测，Widget 只渲染 DTO |
| 3 | `logDaysFromRecords()` 在 logic 层从 `List<BowelRecord>` 构建 `Set<DateTime>` | 与 Log Calendar 同口径（`normalizeDay`）；Chart 已有 `_effectiveRecords`，零新数据源 |
| 4 | **不**重构 `_LogCalendarCard` | 两场景样式规则不同（深浅 vs 固定 0.5）；强行抽共享反而增加耦合；仅复用颜色常量 |
| 5 | 年份模式用 `ListView` 单列，月模式用 7 列网格 | 直接满足「单列纵向年份滚动」；不 hack `YearPicker` 内部 |
| 6 | 打开时日历 `displayMonth` 锚 **今天**，非图表窗口 end | 探索已确认 3.A；与选中日独立（用户可切月再选） |

**执行顺序依据：** Logic（数据 + 样式规则）→ Widget（月历 UI）→ 接线（替换 picker）→ 测试；每步可独立验证，样式 bug 在 Widget 前已被单测覆盖。

---

## Tasks

- [x] 🟩 **Step 1: Logic — 记录日与日期格样式** — `chart_analysis_logic.dart`
  - [x] 🟩 1a. `Set<DateTime> logDaysFromRecords(List<BowelRecord> records)`
  - [x] 🟩 1b. `ChartPickerDayStyle resolveChartPickerDayStyle(...)`
  - [x] 🟩 1c. 单测 `test/chart_analysis_logic_test.dart`

- [x] 🟩 **Step 2: Widget — `ChartDatePickerCalendar`** — `lib/features/archive/widgets/chart_date_picker_calendar.dart`
  - [x] 🟩 2a. 状态：`displayMonth`（初始 = 今天所在月）、`pickerMode`（month | year）、`selectedDate`
  - [x] 🟩 2b. 月视图：周标题行 + 7 列日期格 + 左右切月（边界 clamp 2025–2100）
  - [x] 🟩 2c. 日期格：调用 `resolveChartPickerDayStyle` 渲染蓝底 / 蓝字 / 白圈
  - [x] 🟩 2d. 顶栏：`‹  Month Year  ›`；点击 **Year** 进入年份模式
  - [x] 🟩 2e. 年份模式：`ListView` 单列纵向，项高 44，选中项高亮；点选回到月视图
  - [x] 🟩 2f. 视觉对齐 Material 深色主题（`#0088FF` primary、白字）

- [x] 🟩 **Step 3: 接线 — 替换 `_showChartDatePicker` 内 picker** — `chart_analysis_card.dart`
  - [x] 🟩 3a. 删除 `Platform.isIOS` 分支及 `CupertinoDatePicker` / `CalendarDatePicker`
  - [x] 🟩 3b. 构建 `logDays = logDaysFromRecords(_effectiveRecords)`
  - [x] 🟩 3c. picker 区域改为 `ChartDatePickerCalendar(...)`；Dialog 外壳不变
  - [x] 🟩 3d. 移除 `cupertino.dart` / `foundation` 平台判断 import

- [ ] 🟨 **Step 4: 验证**
  - [x] 🟩 4a. `flutter test test/chart_analysis_logic_test.dart`
  - [x] 🟩 4b. `flutter analyze` 相关文件无 warning
  - [ ] 🟥 4c. 手动测试清单（见下文）

---

## 详细改动清单

### 1. Logic 层

| 位置 | 改前 | 改后 | 文件 |
|------|------|------|------|
| 记录日集合 | 无 | `logDaysFromRecords(records)` | `chart_analysis_logic.dart` |
| 日期格样式 | 无 | `ChartPickerDayStyle` + `resolveChartPickerDayStyle(...)` | `chart_analysis_logic.dart` |
| 单测 | 无覆盖 | log 去重 + 样式规则组合 | `test/chart_analysis_logic_test.dart` |

### 2. 新 Widget

| 位置 | 改前 | 改后 | 文件 |
|------|------|------|------|
| 小日历 picker | 平台分叉 | `ChartDatePickerCalendar` | `widgets/chart_date_picker_calendar.dart` |

### 3. Chart Analysis Card

| 位置 | 改前 | 改后 | 文件 |
|------|------|------|------|
| `_showChartDatePicker` picker | iOS/Android 分叉 | 统一 `ChartDatePickerCalendar` | `chart_analysis_card.dart` |

---

## 手动测试清单

### A. 有数据标记

- [ ] **A1** 选有 log 的非今天日期所在月 → 该日显示 **0.5 蓝底**，数字白色
- [ ] **A2** 选今天的日期 → 数字 **蓝色**，**无**蓝底（即使今天有 log）
- [ ] **A3** 与 Log Calendar 对照：有 log 的日期集合一致（随机抽 3 天）

### B. 选中与交互

- [ ] **B1** 点击某日 → **白色空心圆圈**出现；Confirm 后图表窗口 end = 该日
- [ ] **B2** 选中有 log 的非今天 → **蓝底 + 白圈** 同时可见
- [ ] **B3** 今天且选中 → **蓝字 + 白圈**，无蓝底
- [ ] **B4** Cancel → 不跳转，窗口不变

### C. 导航与年份

- [ ] **C1** 打开小日历 → 默认显示 **今天**所在月
- [ ] **C2** `‹ ›` 切月正常；2025 年 1 月 / 2100 年 12 月边界不崩溃
- [ ] **C3** 点击年份 → **单列纵向**年份列表；选择年份后回到月视图且年份正确
- [ ] **C4** iOS 与 Android（或 Web）均为月历格，无滚轮

### D. 弹窗外壳回归

- [ ] **D1** 玻璃风 Dialog、`Select Date` 标题、Cancel/Confirm 布局与改前一致
- [ ] **D2** Chart Analysis 4 处日期文字入口均可打开小日历
- [ ] **D3** 热力格 `grid_on` 图标功能不受影响

### E. 回归 / 未改项

- [ ] **E1** Confirm 后 `offsetForSelectedDate` 跳转逻辑不变
- [ ] **E2** Log Calendar 页深浅热力不变

---

## 测试记录（你可填）

| 日期 | 设备/系统 | 测试人 | 通过项 | 问题摘要 |
|------|-----------|--------|--------|----------|
|      |           |        |        |        |

---

## 文件清单

| 操作 | 路径 |
|------|------|
| 新建 | `lib/features/archive/widgets/chart_date_picker_calendar.dart` |
| 修改 | `lib/features/archive/chart_analysis_logic.dart` |
| 修改 | `lib/features/archive/chart_analysis_card.dart` |
| 修改 | `test/chart_analysis_logic_test.dart` |
