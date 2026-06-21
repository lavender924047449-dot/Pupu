# PLAN-COPY-UI-002: 审计后回归修复

**Issue:** [COPY-UI-002-post-audit-fixes.md](../issues/COPY-UI-002-post-audit-fixes.md)  
**进度:** 100% ✅

---

## Tasks

| Phase | 任务 | 状态 |
|-------|------|------|
| 1 | #1 Finish 按钮修复 | ✅ |
| 1 | #7 Logs 空态/日期键 | ✅ |
| 2 | #2 Selection Required 居中 | ✅ |
| 2 | #4 Leave Timer message 样式 | ✅ |
| 3 | #3 Session Summary 间距 | ✅ |
| 4 | #5 Select Date Confirm + 周期键 | ✅ |
| 4 | #6 Bowel Issue Grid 多 log | ✅ |
| 5 | #8 Entries 字号 | ✅ |
| 5 | #9 Category 删除 UI | ✅ |
| — | `flutter test` 148/148 | ✅ |

---

## 改动摘要

### #1 Finish 按钮
- `questionnaire_interactive_panel.dart`：`showFinish` 移入 `AnimatedBuilder` builder（修复 stale 状态）
- 新增 `flow.addListener` + `_scheduleScrollBottomSync()`：短内容无需滚动也能显示 Finish

### #2 / #4 弹框
- `app_glass_dialog.dart`：`confirm` 支持 `message`；`Column` stretch + `SizedBox(width: infinity)` 居中
- `timer_dialogs.dart`：Leave Timer 拆 title/message

### #3 Session Summary
- `timer_session_summary.dart`：`Spacer` → 比例 `ctaGap`（28/852 clamp 20–40）；上部 `Flexible`+滚动

### #5 Chart 日期
- `chart_analysis_logic.dart`：`maxChartOffsetDays` 基于 `chartPickerMinDate()`（2025-01-01）至 today
- `chart_analysis_card.dart`：Select Date 增加 Cancel/Confirm，取消点外确认

### #6 Bowel Issue Grid
- 当日 records 按 `dateTime` 排序；`recordIndex` 为归因 log 序号
- breakdown dialog `ConstrainedBox` + `SingleChildScrollView` 多 log 可滚

### #7 Logs
- 无 log 日：header 固定显示日期导航；空态文案居中

### #8 / #9 Private Space
- `Entries`：fontSize 25、letterSpacing 2、bold
- 分类：去掉 long press 文案；删除条用 category 暖色底

---

## 测试

```text
flutter test → 148/148 passed
```
