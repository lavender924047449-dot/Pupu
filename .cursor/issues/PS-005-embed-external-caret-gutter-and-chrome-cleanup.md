# PS-005: Private Space — Embed 外置光标间隙 + 两行 Backspace 删 embed + 移除右侧控件

**Type:** Bug / Improvement | **Priority:** Normal | **Effort:** Medium

**Labels:** `private-space` `editor` `ux`

**Status:** Done ✅

**Progress:** `100%`

**Related:** PS-004（edge caret + 删除）、PS-003（embed 布局）

---

## TL;DR

Embed 光标视觉上落在图片/语音**内部**而非外侧间隙；embed 下方一行 Backspace **两次**删 embed 的流程需修复/保证；图片/语音 embed 右上角 **drag handle + ⋮ 菜单** 移除，拖拽重排一并废弃。

---

## 产品决策（已定稿）

| 议题 | 决策 | 状态 |
|------|------|------|
| 拖拽排序 | **完全放弃** embed 拖拽重排 | 🟩 |
| Voice 重命名 | **长按** voice bubble | 🟩 |
| 图片 Copy/Cut | **不要** ⋮ 菜单 | 🟩 |
| 下一行删 embed | **两次** Backspace：① 落到 embed 右侧 → ② 删 embed | 🟩 |

---

## Current vs Expected

| # | 当前 | 预期 | 状态 |
|---|------|------|------|
| 1 | Caret 叠在 embed 内部 | 左右 20px gutter，caret 外置；tap 后软键盘可用 | 🟩 |
| 2 | 下一行 Backspace 流程不稳定 | 严格两步：行首 → embed 右侧 → 删 embed | 🟩 |
| 3 | drag handle + ⋮ | 全部删除 | 🟩 |

---

## 实现摘要

- [x] 🟩 `_wrapEmbedInteractive`：Row + 左右 `_embedGutterWidth`（20px）外置 caret
- [x] 🟩 `_buildEmbedKeyboardProxy`：embed caret 时 invisible TextField 保持软键盘
- [x] 🟩 `_deleteBackwardFromCaret`：text 行首 → 落到 embed 右侧（不删）；embed 右侧 → 删
- [x] 🟩 `handleDeleteBackwardOnEmbed` / `handleDeleteForwardOnEmbed`：仅右侧 Backspace / 左侧 Delete 删 embed
- [x] 🟩 移除 `_EmbedDragHandle`、`PopupMenuButton`、`DragTarget`、drag controller API
- [x] 🟩 测试：两步删 embed、drag 测试改为 `moveOp`、25 相关用例通过

---

## 验收标准

- [x] 🟩 Embed 左右可见间隙，caret 在间隙而非图内
- [x] 🟩 点选 embed 左/右间隙后软键盘可弹出
- [x] 🟩 光标在 embed 下一行：第 1 次 Backspace → embed 右侧 caret；第 2 次 → 删 embed
- [x] 🟩 **不能**从 embed 下一行一次 Backspace 删 embed
- [x] 🟩 图片/语音无 drag handle、无 ⋮；无拖拽重排
- [x] 🟩 Voice **长按** bubble 可重命名
- [x] 🟩 图片 double-tap / long-press 不受影响
- [x] 🟩 `flutter test` 通过（private note 相关 25/25）

---

## 改动文件

| 文件 | 动作 |
|------|------|
| `private_note_editor.dart` | gutter 布局、keyboard proxy、移除 chrome/drag |
| `private_note_document_controller.dart` | 两步删 embed、embed keyboard focus、删 drag API |
| `private_note_document_controller_test.dart` | 更新删 embed / 移除 drag 测试 |
| `private_note_document_test.dart` | drag → `moveOp` 测试 |

---

## 非目标

- 不改 History / 存储 schema
- 不恢复 ⋮ Copy/Cut/Delete 菜单
