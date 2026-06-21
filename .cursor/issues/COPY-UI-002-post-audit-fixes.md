# COPY-UI-002: 文案/UI 审计后回归修复（9 项）

**Type:** Bug + Improvement | **Priority:** High | **Effort:** Medium–Large

**探索状态：** ✅ 已实现（2026-06-18）

**实现进度：** 100% — 见 [PLAN-COPY-UI-002.md](../plans/PLAN-COPY-UI-002.md)

---

## 已确认决策

| # | 决策 |
|---|------|
| 1 | **Finish 按钮消失**：Timer 全流程问卷 **与** Archive Logs 浮层 **两处均有** |
| 3 | **间距**：比例缩放 `28/852` + `clamp(20,40)` + 上部 `Flexible` 滚动兜底 |
| 5 | **小日历** = `‹ date ›` 点击日期展开的 `_showChartDatePicker`；Confirm 后跳转；`‹ ›` 与 picker 范围对齐 |
| 6 | Bowel Issue Grid **仅展示有问卷归因的 log** |
| 8 | Entries：`fontSize: 25`、`letterSpacing: 2` |
| 9 | 去掉 long press 文案；删除条用 PS 暖色玻璃底 |

---

## TL;DR

COPY-UI-001 落地后的手动走查发现 9 项问题，覆盖 Timer 问卷、Session Summary 排版、弹框样式、Chart Analysis 小日历/日期导航、Bowel Issue Grid 多 log 展示、Archive Logs 空态、Private Space 标题与分类删除 UI。

---

## 问题清单

### #1 Finish Logging 按钮消失（Bug）

| | |
|---|---|
| **当前** | `>>Finish Logging` 在部分场景下不可见或无法点击 |
| **预期** | 满足 `shouldShowFinishButton()` 时，按钮固定在问卷底部 sticky footer，始终可见可点 |
| **疑似根因** | `questionnaire_interactive_panel.dart` 改为 `Column` + `Expanded(SingleChildScrollView)` + footer；父级高度约束（Archive 284×406 浮层 / Timer 面板）可能导致 footer 被裁切；或 `#C6C6C8` 在浅色玻璃上对比度不足 |
| **文件** | `lib/features/questionnaire/widgets/questionnaire_interactive_panel.dart`、调用方 `timer_questionnaire_host.dart` / `logs_card.dart` |

**已确认：** Timer + Archive Logs **两处均复现**。

---

### #2 Selection Required 弹框居中（Bug）

| | |
|---|---|
| **当前** | 标题/正文视觉未居中（用户反馈） |
| **预期** | `Selection Required` 标题 + `Please select an option.` 正文均水平居中 |
| **文件** | `lib/core/widgets/app_glass_dialog.dart`、`lib/features/timer/widgets/timer_dialogs.dart`（`TimerSelectOptionAlertDialog`） |

**实现方向：** 核查 `AppTypography.dialogTitle` / `_messageStyle` 是否有非居中因素；`alert` 模式 title+message 统一 `textAlign: center` 并保证 `Column` 子项 `crossAxisAlignment: center`。

---

### #3 Session Summary CTA 与说明文间距过大（Improvement）✅ 已确认

| | |
|---|---|
| **当前** | 说明文（折叠区）与 `Log with me` / `Maybe Later` 之间留白很大 |
| **疑似根因** | `_SessionSummaryBody` 使用 `const Spacer()` 将 CTA 推至底部 |
| **文件** | `lib/features/timer/widgets/timer_session_summary.dart` |

**已确认方案（跨机型）：**

不按机型型号硬编码，沿用 Timer 页既有 **设计稿比例缩放**（基准 852×393）：

1. **固定比例间距**：`Spacer()` → `SizedBox(height: screenHeight * (28 / 852))`（与 `logButtonHeight: panelHeight * (57/636)` 同思路）
2. **夹紧上下限**：`gap.clamp(20.0, 40.0)`，避免 SE 过小 / Pro Max 过大
3. **内容溢出兜底**：说明文以上区域包进 `Flexible` + `SingleChildScrollView`；小屏、长暖心句、系统大字号时 **上部可滚**，CTA 区固定底部 + `SafeArea`
4. **不测机型表**：比例 + clamp + 滚动 覆盖 iPhone SE ~ Pro Max；实现后真机抽测 SE + 常规屏 + Dynamic Type 即可

---

### #4 Leave Timer 副文案改为 message 样式（Improvement）

| | |
|---|---|
| **当前** | `Leave Timer?\n\nThis session won't be saved.` 挤在 `title` 一行 |
| **预期** | `title: 'Leave Timer?'` + `message: "This session won't be saved."`（与 Maybe Later / Selection Required 两段式一致） |
| **文件** | `lib/features/timer/widgets/timer_dialogs.dart`、`lib/core/widgets/app_glass_dialog.dart`（`confirm` 模式需支持可选 `message`）、`test/timer_exit_dialogs_test.dart` |

---

### #5 Select Date 小日历确认 + 周期键范围统一（Feature/Bug）

| | |
|---|---|
| **当前** | ① 点击 `‹ date ›` 中 **日期文字** 打开 `_showChartDatePicker`（Cupertino / Material 日历）；滚动/点选日期后 **无法立即跳转**，仅点弹窗外才 `pop(selectedDate)`；无显式 Confirm/Cancel；② 同行 `‹ ›` 周期切换受 `maxChartOffsetDays(records)` 限制，**无 log 的日期区间无法通过箭头到达** |
| **预期** | ① 弹窗底部增加 **Cancel / Confirm**（或等价）；仅 Confirm 时调用 `offsetForSelectedDate` 并关闭；② `‹ ›` 可导航至与 picker 一致的日期范围（2025-01-01 ~ today，含无数据窗口） |
| **范围** | Chart Analysis **所有**使用 `_buildWindowNavigator(onDateTextTap: …)` 的区块（Status / Issue Radar / Stacked / Line 等）；**不含** `grid_on` 热力格弹窗、**不含** Archive Logs 日导航 |
| **文件** | `chart_analysis_card.dart`（`_showChartDatePicker`、`_buildWindowNavigator`）、`chart_analysis_logic.dart`（`resolveChartWindow` / `maxChartOffsetDays`） |

**已确认：** 专指 **日期文字** 展开的小日历，非 Bowel Issue Grid。

---

### #6 Bowel Issue Grid 显示当日全部 log 归因柱（Bug/Feature）

| | |
|---|---|
| **当前** | Stacked/Line 的 Bowel Issue Grid 点日仅展示一条 log 的 Phys/Psych/Ext 柱状维度 |
| **预期** | 当日所有 log 的归因柱（Log 1、Log 2…）均展示；内容区可滚动 |
| **现状代码** | `_showIssueRecordBreakdownDialog` 已 `generate(issueRecordBreakdowns.length)`；`issueBreakdowns` 仅包含 `computeIssueBreakdown != null` 的记录 |
| **文件** | `lib/features/archive/chart_analysis_card.dart`、`lib/features/archive/status_scoring.dart` |

**已确认：** 无问卷归因的 log **不展示**。

**实现方向：** 修复只显示一条的真实根因；为 dialog 设 `maxHeight` + 可靠 `SingleChildScrollView`；有归因的多 log 纵向排列 `_buildIssueRecordChart`。

---

### #7 Logs 空态居中 + 无 log 日日期键消失（Bug）

| | |
|---|---|
| **当前** | ① `No logs yet.` 视觉未居中；② 切换到无 log 日后，日期 `〈 ›` 导航消失 |
| **疑似根因** | 空态分支 `Positioned.fill(top: 72)` 仅 `Center(Text)`，未含日期导航；有数据时导航在 scroll 内或 pinned header，空态完全未渲染 `_buildDateNavigator` |
| **预期** | 空态文案在内容区垂直水平居中；**任意日期**（含无 log）均显示日期切换键 |
| **文件** | `lib/features/archive/logs_card.dart`、`lib/features/archive/new_archive_screen.dart` |

---

### #8 Private Space 标题 Entries 字号（Improvement）✅ 已确认

| | |
|---|---|
| **当前** | `Entries` 无 `fontSize`，偏小 |
| **预期** | `fontSize: 25`、`fontWeight: w700`、`letterSpacing: 2`（对齐 Archive Logs 标题） |
| **文件** | `lib/features/private_space/private_space_screen.dart` |

---

### #9 Select Category 删除 UI 精简（Improvement）✅ 已确认

| | |
|---|---|
| **当前** | 每个标签旁显示 `Long press to delete`；长按后删除条为红色 `#EF4444` |
| **预期** | 去掉说明文案；保留长按删除；删除条复用分类行暖色玻璃底（`category.color` 半透明 + 白边），去掉红底 |
| **文件** | `lib/features/private_space/private_space_categories.dart` |

---

## 相关文件汇总

| 模块 | 文件 |
|------|------|
| 问卷 Finish | `questionnaire_interactive_panel.dart` |
| 弹框 | `app_glass_dialog.dart`, `timer_dialogs.dart` |
| Session Summary | `timer_session_summary.dart` |
| Chart / Grid | `chart_analysis_card.dart`, `chart_analysis_logic.dart`, `status_scoring.dart` |
| Archive Logs | `logs_card.dart`, `new_archive_screen.dart` |
| Private Space | `private_space_screen.dart`, `private_space_categories.dart` |
| 测试 | `timer_exit_dialogs_test.dart`, `questionnaire_flow_finish_test.dart`, chart/logs 相关 test |

---

## 风险 / 备注

- **#4** 需扩展 `AppGlassDialog.confirm` 支持 `message`，影响所有 confirm 弹框调用方（改动面小）
- **#5** 放宽日期导航可能让图表窗口显示「无 log 数据」空态，需与 `No log data in this period.` 文案一致
- **#1** 两处父级约束均需排查（`timer_questionnaire_host.dart` + `logs_card.dart` overlay）
- **#3** 默认采用 `SizedBox(sy(28))` 替代 `Spacer()`，真机可微调
- **#5** 放宽 `‹ ›` 后空窗口需正常显示 `No log data in this period.`

---

## 建议实现分期

| Phase | 内容 |
|-------|------|
| **1** | #1 Finish 按钮、#7 Logs 空态/日期键（高优先级回归） |
| **2** | #2 #4 弹框样式统一 |
| **3** | #3 Session Summary 间距 |
| **4** | #5 #6 Chart 日历与 Bowel Issue Grid |
| **5** | #8 #9 Private Space 抛光 |

---

## Test Plan

- [x] Timer / Archive 问卷：Finish 按钮可见、可点、不被最后一题遮挡
- [x] 多选未选 Next → Selection Required 标题+正文居中
- [x] Session Summary：说明文与 CTA 间距合理（小屏 + 大字号）
- [x] 计时中系统返回 → Leave Timer? + message 副文案
- [x] Chart Analysis：点日期文字 → Select Date → Confirm 后窗口跳转；Cancel 不跳转
- [x] Chart Analysis：`‹ ›` 可到达无 log 数据的时间窗口
- [x] 同日多 log：Bowel Issue Grid 展示全部归因柱且可滚动
- [x] Logs 无 log 日：No logs yet. 居中 + 日期键仍在
- [x] Private Space：Entries 字号与旧 RECORDS 一致；分类无 long press 文案；删除条配色一致
- [x] `flutter test` 148/148 全绿
