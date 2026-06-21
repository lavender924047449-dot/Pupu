# PLAN-PS-PLACEHOLDER-001: Private Space 笔记引导词

**Overall Progress:** `100%`

## TLDR

为全新空白笔记的第一行增加英文引导词 `Speak to the galaxy...`；进入页面不自动聚焦、不弹键盘；用户点击笔记内容区（日期行除外）后光标出现并打开键盘；首次内容动作（输入 / 粘贴 / 插图片 / 插录音）后引导词永久消失（删光不重显）。

---

## 最终规格（探索已确认）

| 项 | 行为 |
|----|------|
| 文案 | `Speak to the galaxy...`（3 个英文省略号） |
| 显示时机 | 仅全新空白笔记（星标首次进入 / History FAB「+」新建） |
| 不显示 | 编辑已有记录；不存在「空历史记录」场景 |
| 点击聚焦 | 仅点击聚焦 → 引导词**仍显示**（1-A） |
| 消失触发 | 输入、粘贴、插图片、插录音任一发生即消失 |
| 删光后 | **不**重新出现 |
| 键盘 | 所有进入路径均不自动弹；含图片预览返回 |
| 点击区域 | 整个笔记纸面内容区；**日期行排除** |
| 颜色 | `PrivateSpaceColors.accent.withValues(alpha: 0.70)` |
| 字体 | 18pt / italic / Josefin Sans / w200 |

---

## Critical Decisions

- **Overlay 而非 hintText** — 多段 `TextField` 架构下用 `Stack` 叠第一行 `Text`，样式完全可控，不与正文 `Segoe UI` 混用
- **一次性 dismissed 标记** — `controller.isEmpty` 不足以区分「删光」与「未开始」；用 `dismissEntryPlaceholder()` 单向置位，会话内不重置
- **仅新建会话启用** — `PrivateNoteDocumentController` 构造时 `showEntryPlaceholder: true`；`_resetEditor(entry)` 带 entry 时为 `false`
- **移除自动聚焦** — 删除 `_focusEditorAfterOpen()`；`PrivateNoteEditor` 内 `GestureDetector` 点击纸面调用 `focusFirstText(requestKeyboard: true)`
- **日期行隔离** — 引导词与点击聚焦均在日期行下方 `Expanded` 内容区（`PrivateNoteEditor` 已覆盖）
- **不扩 scope** — 不改保存逻辑、不改 embed 行为、不加动画

---

## Tasks

- [x] 🟩 **Step 1: Controller 引导词状态** — `lib/features/private_space/private_note_document_controller.dart`
  - [x] 🟩 1a. 构造参数 `showEntryPlaceholder`（默认 `false`）
  - [x] 🟩 1b. 私有 `_entryPlaceholderDismissed` + `bool get showEntryPlaceholder`
  - [x] 🟩 1c. `void dismissEntryPlaceholder()` — 单向置位并 `notifyListeners()`
  - [x] 🟩 1d. 在 `onTextEdited`、`pasteTextAtCaret`、`insertImageAtCaret`、`insertVoiceAtCaret` 调用 dismiss

- [x] 🟩 **Step 2: 移除自动聚焦** — `lib/features/private_space/private_space_screen.dart`
  - [x] 🟩 2a. 删除 `_openFromStar` / `_createNoteFromHistory` / `_editFromHistory` 中的 `_focusEditorAfterOpen()` 调用
  - [x] 🟩 2b. 删除图片预览返回后的 `_focusEditorAfterOpen()`
  - [x] 🟩 2c. `_resetEditor()` 新建时传 `showEntryPlaceholder: entry == null`；编辑时 `false`
  - [x] 🟩 2d. 插 embed dismiss 由 controller 方法统一处理

- [x] 🟩 **Step 3: 引导词 Overlay + 纸面点击** — `lib/features/private_space/private_note_editor.dart`
  - [x] 🟩 3a. `Stack` 第一行叠加引导词 `Text`（对齐 `ListView` padding / 首行 baseline）
  - [x] 🟩 3b. 引导词样式 token 常量（accent @ 0.70 / 18 / italic / Josefin Sans / w200）
  - [x] 🟩 3c. `showEntryPlaceholder == true` 时显示；内容动作经 controller dismiss
  - [x] 🟩 3d. `GestureDetector` 包裹 `ListView`，`onTap` → `focusFirstText`（不 dismiss）
  - [x] 🟩 3e. `HitTestBehavior.translucent`；embed / TextField 子组件优先接收手势

- [x] 🟩 **Step 4: 测试与回归**
  - [x] 🟩 4a. `test/private_note_placeholder_test.dart` — 11 条单测全部通过
  - [ ] 🟨 4b. 手动：进入不弹键盘 → 点纸面弹键盘且引导词仍在 → 首字后消失
  - [ ] 🟨 4c. 手动：粘贴 / 插图 / 插录音 → 引导词消失；图片预览返回不自动弹键盘

---

## 文件清单

| 操作 | 路径 |
|------|------|
| 修改 | `lib/features/private_space/private_note_document_controller.dart` |
| 修改 | `lib/features/private_space/private_space_screen.dart` |
| 修改 | `lib/features/private_space/private_note_editor.dart` |
| 新建 | `test/private_note_placeholder_test.dart` |

---

## 风险 / 备注

- `Josefin Sans` 仅注册 w300/w400，w200 可能回落到 w300；italic 为合成斜体——接受，不另加字体文件
- 纸面 `GestureDetector` 与 embed 拖拽/长按需真机验证
- `focusFirstText` 在 embed-only 空文档时会走 virtual text field 路径

---

## 验收清单

- [ ] 星标进入（无历史）→ 见引导词，无光标，无键盘
- [ ] History FAB「+」→ 同上
- [ ] 点击内容区（非日期行）→ 光标 + 键盘，引导词仍在
- [ ] 输入首字 / 粘贴 / 插图 / 插录音 → 引导词消失
- [ ] 删光全部内容 → 引导词不出现
- [ ] 编辑已有记录 → 无引导词
- [ ] 图片预览关闭返回 → 不自动弹键盘
