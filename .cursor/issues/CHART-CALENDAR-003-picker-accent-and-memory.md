# CHART-CALENDAR-003: 小日历凸显色改黑 + 打开记忆选中日

**Type:** Improvement | **Priority:** Normal | **Effort:** Small

**探索状态：** ✅ 已实现

**Overall Progress:** `100%`

**关联：** [PLAN-CHART-CALENDAR-002](../plans/PLAN-CHART-CALENDAR-002.md)

---

## TL;DR

Chart Analysis 小日历凸显色改黑（今日、年份、Confirm）；有 log 蓝底不变。打开时默认锚定**当前区块窗口 end** 所在月，并以白圈标出该日。

---

## 已确认规格

| # | 项 | 规则 |
|---|-----|------|
| 1 | 今日日期数字 | **黑色** |
| 2 | Confirm 按钮文字 | **黑色** |
| 3 | 顶栏年份 + 年份列表选中文字 | **黑色** |
| 4 | 有 log 日底色 | `#0088FF` @ **0.5**（不变） |
| 5 | 选中日白圈 | 白色空心圆圈（不变） |
| 6 | 打开默认月 | **A** — 当前图表窗口 `end` 所在月 |

---

## Tasks

- [x] 🟩 **Step 1:** `chart_date_picker_calendar.dart` — `_emphasisColor` 黑 / `_logMarkColor` 蓝；`initState` 锚 `selectedDate` 月；年份选中背景改浅白
- [x] 🟩 **Step 2:** `chart_analysis_card.dart` — `_showChartDatePicker(initialSelectedDate)`；4 处传 `resolveChartWindow(...).end`；Confirm 黑色
- [x] 🟩 **Step 3:** `flutter analyze` + `chart_analysis_logic_test` 通过

---

## 验收清单

- [x] 今日数字、年份、Confirm 为黑色；有 log 日仍为 0.5 蓝底（代码）
- [ ] 再次打开落在窗口 end 月，end 日白圈（手动）
- [ ] 4 处日期入口一致（手动）
- [ ] Cancel 不改变窗口（手动）

---

## 测试记录

| 日期 | 设备/系统 | 测试人 | 通过项 | 问题摘要 |
|------|-----------|--------|--------|----------|
|      |           |        |        |        |
