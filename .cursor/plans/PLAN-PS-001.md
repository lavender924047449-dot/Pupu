# Feature Implementation Plan — PS-001 Word 式记事本

**Overall Progress:** `92%`

## TLDR

Private Space 已切换为 **schema v2 文档模型** + **Word 式连续编辑区**；旧笔记一次性清空；新 note 保存后仍进入 **History**。图片/语音在光标处内联；手写为整页层；底栏支持三键 ↔ 画笔工具条。

---

## Critical Decisions

- **存储：方案 B（`document.ops` + `handwriting.strokes`）** — `schema_version: 2`
- **旧数据：首次启动清空 Hive private_entries**（`shared_preferences` 标记，不迁移）
- **History 保留** — `saveEntry` → `_Stage.history` 列表展示
- **Embed：自研 segment 编辑器**（多 TextField + 内联 Widget，无 flutter_quill）
- **手写：整页 `PrivateFullPageHandwriting` 叠加层**，画笔模式与键盘互斥

---

## Tasks

- [x] 🟩 **Step 1: 清空旧数据 + 新文档模型**
  - [x] 🟩 `LocalStorage._purgeLegacyPrivateEntriesOnce`
  - [x] 🟩 `PrivateNoteDocument` + `PrivateDocOp` 类型
  - [x] 🟩 `PrivateEntry` v2 读写、`plainTextPreview`
  - [x] 🟩 单元测试 `test/private_note_document_test.dart`

- [x] 🟩 **Step 2: 文档控制器 + Embed 选型**
  - [x] 🟩 `PrivateNoteDocumentController`（光标、内联插入、图片计数）
  - [x] 🟩 自研 `PrivateNoteEditor`（segment 流式 UI）

- [x] 🟩 **Step 3: Word 式编辑区外壳**
  - [x] 🟩 替换 `_EditorBlockItem` 列表
  - [x] 🟩 进入自动 `focusFirstText`
  - [x] 🟩 无 hint / 无独立输入背景

- [x] 🟩 **Step 4: 底栏状态机（默认 ↔ 画笔）**
  - [x] 🟩 默认三键：图 / 画笔 / 录音
  - [x] 🟩 `PrivatePenToolbar` + 键盘退出
  - [x] 🟩 色盘循环、橡皮、undo/redo

- [x] 🟩 **Step 5: 光标处内联图片与语音**
  - [x] 🟩 `insertImageAtCaret` / `insertVoiceAtCaret`
  - [x] 🟩 删除图片、语音重命名、≤30 张

- [x] 🟩 **Step 6: 整页手写层**
  - [x] 🟩 `PrivateFullPageHandwriting` 全页触摸
  - [x] 🟩 笔画写入 `document.handwritingStrokes`

- [x] 🟨 **Step 7: History 流与清理**
  - [x] 🟩 `HistoryMixedContentPreview` 从 `document` 渲染
  - [x] 🟩 保存后 History、再编辑
  - [x] 🟩 删除旧 block 编辑器路径
  - [ ] 🟥 真机全路径 QA（权限拒绝、混排长文）

---

## 验收 / 构建

- [x] `flutter test test/private_note_document_test.dart`
- [x] `flutter build apk --debug`
- [ ] 真机：升级后 History 空 → 新建 → 保存 → 列表可见

---

## 主要文件

| 路径 | 状态 |
|------|------|
| `lib/models/private_note_document.dart` | 新建 |
| `lib/features/private_space/private_note_document_controller.dart` | 新建 |
| `lib/features/private_space/private_note_editor.dart` | 新建 |
| `lib/features/private_space/private_pen_toolbar.dart` | 新建 |
| `lib/features/private_space/private_fullpage_handwriting.dart` | 新建 |
| `lib/features/private_space/private_space_screen.dart` | 已重构 |
| `lib/services/local_storage.dart` | legacy 清空 |
| `lib/models/private_entry.dart` | v2 |
