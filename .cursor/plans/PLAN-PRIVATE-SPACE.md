# Feature Implementation Plan — Private Space 混合记事

**Overall Progress:** `100%`

**本轮收尾 Progress：** `100%`（P2-R1～R5 全部完成）

> 2026-05-19：需求锁定；本轮 = 剪贴板统一 + 删外部贴图 + 条件自动滚动。历史 Phase 见下方完整展开。
>
> 2026-05-18：PS-002 手写已移除；schema v3 清库。

---

## TLDR

Private Space：**键盘 + 图片 embed + 录音 embed** 单页流式记事（无手写）。历史阶段（模型、流式编辑、图片/录音、History、UI 抛光）已交付。**本轮**补齐 Phase 2 Step 3–4：统一剪贴板、跨段纯文字、条件滚动，并删除外部 Paste Image。

---

## Critical Decisions

| # | 决策 | 理由 |
|---|------|------|
| 1 | `Clipboard` + `pupu-private-clip:` JSON | 图片与文字同路径；对外不可还原 embed |
| 2 | 仅图片可复制/剪切/粘贴；录音永远不可 | 产品锁定 |
| 3 | 跨段纯文字；选区不含 embed | 多 `TextField` 架构 |
| 4 | 粘贴：对内图 → 还原；纯文字 → 插入；其余静默 | 无 SnackBar |
| 5 | 滚动：手动为主；自动仅打字/删除/拖 embed（15px） | 保持 `resizeToAvoidBottomInset: false` |
| 6 | 保存写 anchor；打开 `focusFirstText()` 不恢复 | 已对齐 |
| 7 | v3 清库；非法 op 静默空行 | 不扩 scope |
| 8 | 删除外部贴图与 Android clipboard channel | 仅相册/相机插入 |

**历史（仍有效）**：无手写；仅手动保存；embed 同笔记拖拽；置顶不改 `updatedAt`。

---

## 产品约束

- 键盘、图片、语音同一纸面；`document.ops` 混排
- 图片：相册/相机；同笔记复制/剪切/粘贴/删除/拖拽；**不可**外部贴图
- 录音：插入、拖拽、重命名、删除；**不可**复制/粘贴/剪切
- 允许外部 **纯文字** 粘贴；未知载荷 **静默**
- History 置顶仅影响排序；保存仅手动

## 关键交互约束

- 首行作标题；无独立标题样式
- 图片：双击 > 单击；长按 > 拖动；全屏可返回编辑
- 同笔记：跨段纯文字复制/粘贴；图片对内 JSON 完整还原；录音不可剪贴板操作
- 文本选区邻接 embed 时 **不**自动包含 embed

---

## 推荐执行顺序

### 全项目（已完成路径）

1. Phase 1 数据模型  
2. Phase 2 Step 1–2 + Phase 2.5  
3. Phase 2.6 PS-002  
4. Phase 3–5 图片/录音/History  
5. Phase 6 UI 抛光  

### 本轮收尾（当前）

```text
P2-R1 删外部贴图 + private_space_clipboard.dart
  → P2-R2 图片 Copy/Cut/Paste
  → P2-R3 跨段纯文字
  → P2-R4 ensureVisible
  → P2-R5 测试 + 文档 100%
```

---

## Tasks

### Phase 1：数据模型与存储骨架 — 🟩 `100%`

- [x] 🟩 **Step 1：冻结 `PrivateContentBlock` / document 字段**
  - [x] 🟩 文本 / 图片 / 录音最小字段集（`PrivateDoc*Op`、`PrivateImageData`、`PrivateVoiceData`）
  - [x] 🟩 block 顺序、id、时间戳、锚点（`ops`、`PrivateDocAnchor`、`createdAt`/`updatedAt`）
  - [x] 🟩 序列化与版本边界（`schema_version` v3；无 handwriting）

- [x] 🟩 **Step 2：`PrivateEntry` 持久化**
  - [x] 🟩 note 与 History 元数据分离（`document` vs `title`/`tags`/`category`）
  - [x] 🟩 置顶字段（`tags` → `pinned`；`private_entry_sort.dart`）
  - [x] 🟩 手动保存 vs 草稿（仅 `_saveNote` 写 Hive）

- [x] 🟩 **Step 3：锚点与兼容**
  - [x] 🟩 `PrivateDocCaret` / `PrivateDocAnchor`
  - [x] 🟨 旧纯文本 → text block（**v3 清库**，非逐条迁移；`normalizedBlocks` 未接加载链）
  - [x] 🟨 非法 block → 空 `PrivateDocTextOp` + 坏图占位

---

### Phase 2：基础编辑器与文本流式交互 — 🟩 `100%`

- [x] 🟩 **Step 1：纯文本流式闭环**
  - [x] 🟩 首行标题、多段换行/退格/删除（多 `TextField` + `_mergeAdjacentText`）
  - [x] 🟩 光标跨段落、选区与粘贴（`private_space_text_selection.dart` + `pasteTextAtCaret`）

- [x] 🟩 **Step 2：embed 内联**
  - [x] 🟩 图片/录音 inline + `insert*AtCaret`
  - [x] 🟩 `removeImageAt` / `removeVoiceAt`、菜单删除

- [x] 🟩 **Step 3：剪贴板**
  - [x] 🟩 跨段纯文字；图片对内 JSON；粘贴静默规则

- [x] 🟩 **Step 4：滚动、焦点、手动保存**
  - [x] 🟩 自动滚动（`ensureVisible` · `alignmentPadding: 15`）
  - [x] 🟩 无自动保存；保存后不恢复光标（写 anchor，打开 `focusFirstText()`）

---

### Phase 2.5：编辑器偏差修复 — 🟩 `100%`

- [x] 🟩 **Step 1：去除文本「独立输入块」视觉**
  - [x] 🟩 透明 `TextField`、无卡片边框

- [x] 🟩 **Step 2：移除文本段落拖拽手柄**
  - [x] 🟩 `ListView` 替代 `ReorderableListView`；仅 embed 可拖

- [x] 🟩 **Step 3：修复拖拽 `RangeError`**
  - [x] 🟩 opIndex / caret clamp；`test/private_note_document_test.dart`

- [x] 🟩 **Step 4：收敛为流式体验**
  - [x] 🟩 embed 与文字编辑解耦

---

### Phase 2.6：移除手写/笔画（PS-002）— 🟩 `100%`

> [PS-002](.cursor/issues/PS-002-remove-handwriting-from-private-space.md)

- [x] 🟩 **Step 1：计划与文档**
- [x] 🟩 **Step 2：模型与存储**（删 handwriting 字段；v3 清库）
- [x] 🟩 **Step 3：删 UI/文件**（`private_handwriting_*`、`private_pen_toolbar` 等）
- [x] 🟩 **Step 4：History、测试、回归**（见 [PS-002 手动回归清单](#ps-002-手动回归清单)）

---

### Phase 3：图片能力 — 🟩 `100%`

- [x] 🟩 **Step 1：插入与持久化**
  - [x] 🟩 相册/相机、`PrivateMediaStorage`、大小上限

- [x] 🟩 **Step 2：外部剪贴板** → **已删除（P2-R1）**
  - [x] 🟩 ~~Paste Image / MethodChannel~~ 移除；仅插入

- [x] 🟩 **Step 3：剪切/复制/删除**
  - [x] 🟩 菜单 Copy/Cut/Delete UI 已有
  - [x] 🟩 `pupu-private-clip:` JSON（`private_space_clipboard.dart`）

- [x] 🟩 **Step 4：同笔记内拖拽重排**
  - [x] 🟩 embed drag delay；拖拽中抑制双击/长按

- [x] 🟩 **Step 5：辅助交互**
  - [x] 🟩 双击全屏、长按菜单、`private_space_ui.dart`

---

### Phase 4：录音能力 — 🟩 `100%`

- [x] 🟩 **Step 1：插入主流程**（`PrivateVoiceRecordSheet`、`insertVoiceAtCaret`）
- [x] 🟩 **Step 2：有限操作**（无 copy/cut/paste；rename/delete/拖）
- [x] 🟩 **Step 3：拖拽与播放**（History `readOnly` 预览）

---

### Phase 5：History、置顶与列表 — 🟩 `100%`

- [x] 🟩 **Step 1：排序**（`sortPrivateEntriesForHistory`；pin 不改 `updatedAt`）
- [x] 🟩 **Step 2：混合预览**（`HistoryMixedContentPreview` 聚合摘要）
- [x] 🟩 **Step 3：历史 vs 编辑**（只读预览；全屏图关闭回焦）

---

### Phase 6：UI 抛光 — 🟩 `100%`

- [x] 🟩 **Step 1：视觉语言**（纸面一体、无文本 drag handle）
- [x] 🟩 **Step 2：交互反馈**（`private_space_ui.dart` 菜单/触觉/手势时长）
- [x] 🟩 **Step 3：边界测试**（`test/private_space_boundary_test.dart`；本轮后补剪贴板/滚动用例）

---

## Phase 2 收尾（本轮执行）

**Progress：** `100%` · 范围：Step 3 + Step 4 + 删外部贴图 + 测试

| 顺序 | 步骤 | 依赖 |
|------|------|------|
| 1 | P2-R1 | — |
| 2 | P2-R2 | R1 |
| 3 | P2-R3 | R1 |
| 4 | P2-R4 | 建议 R3 后 |
| 5 | P2-R5 | 全部 |

### P2-R1：清除外部贴图 + 剪贴板模块

- [x] 🟩 **删除** `private_space_screen.dart`：`paste` enum、`_pasteImageFromClipboard`、`_readImageBytesFromSystemClipboardText`、`_clipboardImageChannel`、Paste Image 菜单项、`pupu-image-base64:`
- [x] 🟩 **删除** `MainActivity.kt`：`pupu/private_clipboard_image` 整段
- [x] 🟩 **新增** `private_space_clipboard.dart`（`encode` / `decode` / `tryReadPlainText`）
- [x] 🟩 `flutter analyze` 通过

### P2-R2：图片 embed 走统一剪贴板

- [x] 🟩 `_copyImageAt` / `_cutImageAt` → 对内 JSON
- [x] 🟩 文本处 Paste：`decode` → `insertImageAtCaret`；否则静默
- [x] 🟩 对外不可还原 embed

### P2-R3：跨段纯文字复制/粘贴

- [x] 🟩 自定义 `TextSelectionControls`（选区不含 embed）
- [x] 🟩 Copy/Cut 跨段纯文字；Paste 不触发图片还原
- [x] 🟩 外部 App 纯文字粘贴

### P2-R4：条件自动滚动

- [x] 🟩 `ensureVisible`，`alignmentPadding: 15`
- [x] 🟩 触发：打字、删除、拖 embed；不触发：仅聚焦、插入图/录音

### P2-R5：测试与文档

- [x] 🟩 `test/private_space_clipboard_test.dart`
- [x] 🟩 `test/private_note_document_controller_test.dart`（剪贴板粘贴 · 跨段文字 · 静默规则）
- [x] 🟩 Phase 2 Step 3–4、Phase 3 Step 3 → 🟩；Overall → `100%`

---

## 代码变更清单（清除 / 修改）

### 删除（P2-R1）

| 文件 | 内容 |
|------|------|
| `private_space_screen.dart` | 外部贴图相关 enum/方法/channel/菜单 |
| `MainActivity.kt` | `clipboardImageChannel` 及 image read/write helpers |

### 新建 / 修改

| 文件 | 动作 |
|------|------|
| `private_space_clipboard.dart` | 新建 |
| `private_space_screen.dart` | 图片 Copy/Cut/Paste 走新模块 |
| `private_note_document_controller.dart` | `pasteTextAtCaret`、跨段 cut 等 |
| `private_note_editor.dart` | SelectionControls + `ensureVisible` |

### 不修改

`local_storage.dart` 清库 · 录音无 copy · `resizeToAvoidBottomInset: false`

---

## 粘贴决策表

| 剪贴板 | 行为 |
|--------|------|
| `pupu-private-clip:` + `image` | `insertImageAtCaret` |
| 纯文本（含外部） | caret 插入 |
| 旧 base64 / 外部图 / 未知 | **静默** |

---

## 验收顺序

### 历史（已通过）

1. 无 handwriting · 流式 UI · 图片/录音/History · UI 抛光  

### 本轮

1. P2-R1：无 Paste Image；无 Android channel  
2. P2-R2：Copy 图 → Paste 还原  
3. P2-R3：跨段文字 + 外部纯文字  
4. P2-R4：打字/删/拖 自动滚  
5. 打开笔记光标在文首 · `flutter test` 全绿  

---

## Phase 2 收尾手动验收

- [ ] 🟥 图片 Copy/Cut → Paste 还原
- [ ] 🟥 跨段纯文字 Copy/Paste（不含图）
- [ ] 🟥 外部「hello」可贴入；旧 base64 静默
- [ ] 🟥 录音无剪贴板菜单
- [ ] 🟥 打字/删/拖 embed 自动滚；插入图/录音不自动滚

---

## 文件索引

| 模块 | 路径 |
|------|------|
| 模型 | `lib/models/private_entry.dart`、`lib/models/private_note_document.dart` |
| 存储 | `lib/services/local_storage.dart` |
| 剪贴板（新） | `lib/features/private_space/private_space_clipboard.dart`、`private_space_text_selection.dart` |
| 控制器 | `lib/features/private_space/private_note_document_controller.dart` |
| 编辑器 | `lib/features/private_space/private_note_editor.dart` |
| 主屏 | `lib/features/private_space/private_space_screen.dart` |
| UI | `lib/features/private_space/private_space_ui.dart` |
| 排序 | `lib/features/private_space/private_entry_sort.dart` |
| 语音 | `lib/features/private_space/private_voice_sheet.dart` |
| Android | `android/app/src/main/kotlin/com/pupu/pupu/MainActivity.kt` |
| 测试 | `test/private_note_document_test.dart`、`test/private_note_document_controller_test.dart`、`test/private_space_boundary_test.dart`、`test/private_space_clipboard_test.dart` |

---

## PS-002 手动回归清单

- [x] 🟩 无画笔/手写入口
- [x] 🟩 键盘输入无独立文本卡片
- [x] 🟩 图片插入与 embed 拖拽无 `RangeError`
- [x] 🟩 录音插入/重命名/删除
- [x] 🟩 History 仅 text/image/voice
- [x] 🟩 无文本 drag handle
- [x] 🟩 手动保存回读一致

---

## Backlog（本轮不做）

- History/编辑页手势冲突（遇 bug 再修）
- iOS 真机剪贴板/滚动回归
- `normalizedBlocks` 逐条迁移

---

## Release Note（收尾后）

> Unified in-app clipboard for images; cross-paragraph text copy/paste; removed system paste-image. Opening notes focuses at start (anchor saved but not restored).
