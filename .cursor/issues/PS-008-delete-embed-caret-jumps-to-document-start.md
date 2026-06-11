# PS-008: Private Space — 删除 embed 后光标弹回第一行最左侧

**Type:** Bug | **Priority:** Normal | **Effort:** Small–Medium

**Labels:** `private-space` `editor` `caret` `regression`

**Status:** Done ✅

**Progress:** `100%`

**Related:** PS-004（embed 边缘删除）、PS-005（外置 caret + 两步 Backspace）

---

## TL;DR

删除图片/语音 embed 后，编辑光标跳到**文档第一行最左侧**（`opIndex: 0, textOffset: 0`），而非删除前正在编辑的位置。根因集中在 **`_resolveCaretAfterEmbedRemoval` 对「光标在 embed 上」未做保留**，以及 **UI 删除路径与键盘删除路径的 `preferAdjacentAfter` 不一致**。

---

## Current vs Expected

| # | 当前 | 预期 | 状态 |
|---|------|------|------|
| 1 | 删除 embed（菜单 / Backspace / Delete）后，光标常回到第一行行首 | 光标留在删除前的合理位置（原段落内 offset、或 embed 前一行末） | 🟩 |
| 2 | 在文末多行文字中删图后，光标跳到文首 | 仍在原行/原 offset（或合并后等价 stream offset） | 🟩 |

---

## 实现摘要

- [x] 🟩 `_tryPreserveCaretAfterEmbedRemoval`：处理 `c.opIndex == removedIndex`（光标在 embed 上）→ `_caretOnLineBeforeEmbed`
- [x] 🟩 `removeImageAt` / `removeVoiceAt`：`preferAdjacentAfter: false`，与键盘 `_removeEmbedAt` 对齐
- [x] 🟩 `_syncCaretFromFocusedTextField`：删除前从 focused TextField selection 刷新 `_caret`
- [x] 🟩 `_scheduleFocusForCaret`：`_bindTextControllers` 后立即 + post-frame 二次聚焦
- [x] 🟩 测试：菜单删图 + caret 在 embed 上、selection 同步、现有用例回归

---

## 改动文件

| 文件 | 动作 |
|------|------|
| `lib/features/private_space/private_note_document_controller.dart` | caret 保留、同步、聚焦、UI 删除路径 |
| `test/private_note_document_controller_test.dart` | +2 用例，更新 empty-line 删 voice 期望 |

---

## 验收标准

- [x] 🟩 多行文字 + 图片：菜单删除后光标不回到文首
- [x] 🟩 两步 Backspace 删 embed 后光标仍在 embed 前合理行
- [x] 🟩 光标在 embed 左/右缘删除，落点与键盘删除一致
- [x] 🟩 仅 embed 的笔记删除后落在空行
- [x] 🟩 `flutter test test/private_note_document_controller_test.dart` 通过

---

## 风险 / 注意

- 删 voice 后默认 caret 从「空行 spacer」改为「intro 末尾」——与键盘删 embed 行为一致
- 真机需回归：长按菜单删图 + gutter 选 embed 后删除

---

## 非目标

- 不改 History / 存储 schema
- 不重做 embed gutter UI（PS-005）
