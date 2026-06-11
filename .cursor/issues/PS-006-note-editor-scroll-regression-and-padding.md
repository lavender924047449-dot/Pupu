# PS-006: Private Space — 编辑时异常自动滚动 + 缩小可编辑区内边距

**Type:** Bug / Improvement | **Priority:** Normal | **Effort:** Medium

**Labels:** `private-space` `editor` `ux` `regression`

**Status:** Done ✅

**Progress:** `100%`

**Related:** PS-003（条件自动滚动，已 Done）、PS-005（embed gutter）

---

## TL;DR

Private Space 笔记记录页在编辑过程中页面**持续上下跳动**；需查清根因并修复，使自动滚动**仅在用户操作且光标/焦点离开可视区域时**触发。另：缩小可编辑文字区域与笔记本边框之间的间距，提高纸面利用率。

---

## Current vs Expected

| # | 当前 | 预期 | 状态 |
|---|------|------|------|
| 1 | 打字/退格/换行时页面反复上下滚动，体验不稳定 | 光标在可视区内时**不滚动**；仅当用户操作导致 caret 离开可视区（含键盘 inset）时才滚动 | 🟩 |
| 2 | 可编辑区与笔记本内边框留白偏大 | 缩小 horizontal / vertical padding，文字更贴近边框但不贴边 | 🟩 |

---

## 根因（已确认）

1. **可见性检测对象过大** — 使用整个 `TextField` `RenderBox` 而非 caret rect；多行增长时底部越界误触发滚动。
2. **`alignment: 0.5` 过度居中** — `Scrollable.ensureVisible` 造成 overshoot 与下一帧反向滚动振荡。
3. **同帧多次 post-frame scroll** — 每 keystroke 触发独立 callback，与 rebuild 叠加放大跳动。

---

## 实现摘要

- [x] 🟩 `_caretGlobalRect`：通过 `RenderEditable.getLocalRectForCaret` 获取 caret 全局 bounds
- [x] 🟩 `_minimalScrollDelta` + `scrollController.animateTo`：最小增量滚动，移除 `ensureVisible(alignment: 0.5)`
- [x] 🟩 同帧 scroll 请求合并（`_scrollScheduled` / `_pendingScrollTextIndex`）
- [x] 🟩 ListView padding：`16→10`；screen horizontal `22→16`、top `22→14`
- [x] 🟩 widget 测试：可见 caret 不滚、视口外 caret 滚一次且无振荡

---

## 改动文件

| 文件 | 动作 |
|------|------|
| `lib/features/private_space/private_note_editor.dart` | caret 滚动检测、最小滚动、padding |
| `lib/features/private_space/private_space_screen.dart` | 缩小 Editor 外层 padding |
| `test/private_note_editor_widget_test.dart` | 新增 2 条条件滚动测试 |

---

## 验收标准

- [x] 🟩 光标在可视区内连续打字，页面**不**发生滚动
- [x] 🟩 光标在可视区内退格/换行不滚动（caret rect 逻辑覆盖）
- [x] 🟩 光标离开可视区后输入，**一次**滚回，无来回振荡
- [x] 🟩 可编辑区与边框间距缩小（horizontal 16、top 14、ListView 10）
- [x] 🟩 `flutter test` private note 相关用例通过

---

## 风险 / 注意

- embed 左右 20px gutter（PS-005）未改动
- 真机软键盘动画期间建议手动回归（Android / iOS）

---

## 非目标

- 不改 History / 存储 schema
- 不调整笔记本外框尺寸（312×474）
- 不重做 embed gutter 交互
