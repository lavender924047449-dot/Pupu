# PS-010: Private Space — 离开保存策略、逐层返回、排序时间语义

**Type:** Improvement | **Priority:** Normal | **Effort:** Medium

**Labels:** `private-space` `navigation` `save-flow` `history-sort`

**Status:** In Progress 🟨

**Progress:** `85%`

**Related:** PS-001（notepad 编辑器）、`private_entry_sort.dart`（History 排序）

---

## 实现进度

| Phase | 内容 | 状态 |
|-------|------|------|
| 1 | `copyWith` updatedAt 语义 + category 保留时间 | 🟩 Done |
| 1 | 单测 updatedAt / dirty 检测 | 🟩 Done |
| 2 | dirty 检测 + unsaved dialog + `_persistNote` | 🟩 Done |
| 2 | `PopScope` + 统一 `_handleBack` | 🟩 Done |
| 3 | 真机验收（6 条验收标准） | 🟨 Pending |

---

## 改动文件（实际）

| 文件 | 动作 | 状态 |
|------|------|------|
| `lib/models/private_entry.dart` | `copyWith` 省略时保留 `updatedAt` | 🟩 |
| `lib/features/private_space/entry_edit_screen.dart` | 显式保存时 bump `updatedAt` | 🟩 |
| `lib/features/private_space/private_space_screen.dart` | `_persistNote` / `_handleBack` / `PopScope` | 🟩 |
| `lib/features/private_space/private_space_ui.dart` | `showPrivateUnsavedChangesDialog` | 🟩 |
| `lib/features/private_space/private_note_document_controller.dart` | `hasUnsavedEdits` baseline | 🟩 |
| `test/private_space_boundary_test.dart` | PS-010 单测 4 条 | 🟩 |

---

## TL;DR

统一 Private Space 三条 UX 规则：**(1)** 新建笔记离开默认自动保存；已有笔记编辑后离开若有未保存改动则弹确认；**(2)** 系统返回键与 App 内返回键行为一致，按界面层级逐层退出；**(3)** 仅「进入编辑并点保存」才刷新 `updatedAt`，查看/置顶/改分类等元数据操作不改变排序时间。

---

## Current vs Expected

| # | 当前 | 预期 |
|---|------|------|
| 1 | `_backFromNotepad()` 直接丢弃内容返回，不保存（`private_space_screen.dart` L174–181） | **新建**（`_editingEntryId == null`）：有内容 → 静默自动保存；**空内容 → 作废，不创建 entry** ✅ |
| 1b | 同上 | **编辑已有**（`_editingEntryId != null`）：dirty 时弹居中 Dialog — 标题「是否保存更改？」，按钮 **Save / Don't Save**（英文）✅ |
| 2 | 无 `PopScope`；系统返回键直接 `Navigator.pop` 整页退出 Home | 系统返回 ≡ App 内 `<`：按栈逐层退（overlay → stage → route） |
| 3 | `PrivateEntry.copyWith()` 一律写 `updatedAt: DateTime.now()`（L330）；批量改分类走 `copyWith` 会误刷时间（L597） | 仅显式保存笔记内容时更新 `updatedAt`；pin/unpin、批量改分类均保留原时间 ✅ |

---

## 导航栈（已确认 ✅）

Private Space 内共有 **3 个主 stage + 2 个 overlay**：

| 层级 | 用户看到的 | 触发方式 |
|------|-----------|---------|
| **idle** | 星空 + 金色星标入口 | 进入 Private Space 默认页 |
| **history** | RECORDS 历史列表 | 点星标进入（有记录时） |
| **notepad** | 笔记编辑页（纸页 + 输入） | 列表点卡片 / 右下角 + |
| **selectionMode** | 历史列表多选 + 底部栏（Share / Delete / **Mark** / All） | 长按某条记录 |
| **markBoard** | 底部弹出 **「Select Category」** 分类面板 | 多选模式下点 Mark |

**逐层返回顺序（系统返回 ≡ App 内 `<`）：**
1. markBoard 开着 → 关闭分类面板（仍在多选）
2. selectionMode → 退出多选，回普通 history 列表
3. notepad → history（无历史记录则 → idle）；dirty 时先走保存 Dialog
4. history → idle
5. idle → `Navigator.pop` 回 Home

---

## 实现要点

### 1. 保存 / 离开策略

- 在 `PrivateNoteDocumentController` 增加 **dirty 检测**（加载 snapshot vs `buildDocument()` 比较，或 `_editGeneration` 基准）
- 抽取 `_persistNote({required bool touchUpdatedAt})` 供手动保存与自动保存复用
- 新建离开：有内容 → auto-save；空内容 → 直接返回，不写 storage ✅
- 编辑离开 dirty：`showPrivateUnsavedChangesDialog` — 标题中文「是否保存更改？」，按钮 **Save / Don't Save** ✅
- 触发点：notepad 左上角返回、系统返回（经统一 `_handleBack()`）

### 2. 逐层返回

- 根 widget 包 `PopScope(canPop: false, onPopInvokedWithResult: ...)`
- 单一 `_handleBack()` 分发：overlay → stage → `Navigator.pop`
- History / notepad 内 `<` 按钮改调 `_handleBack()`，不再各写一套

### 3. 排序时间

- `PrivateEntry.copyWith` 增加 `DateTime? updatedAt` 可选参数；默认 `DateTime.now()` 改为「仅显式传入才更新」或拆 `copyWithContent` / `copyWithMetadata`
- `_saveNote` / auto-save：**传入新 `updatedAt`**
- pin/unpin、改 category、批量 mark：**保留原 `updatedAt`**（pin 已实现，category 需修）
- 排序规则不变：`sortPrivateEntriesForHistory` — pinned first → `updatedAt` ↓

---

## 改动文件（预估）

| 文件 | 动作 |
|------|------|
| `lib/features/private_space/private_space_screen.dart` | 离开保存、PopScope、统一 back |
| `lib/features/private_space/private_space_ui.dart` | 新增 unsaved-changes 确认 dialog |
| `lib/models/private_entry.dart` | `copyWith` 支持保留 `updatedAt` |
| `lib/features/private_space/private_note_document_controller.dart` | dirty / baseline snapshot |
| `test/private_space_boundary_test.dart` 或新建 | back 栈 + sort 语义单测 |

---

## 验收标准

- [ ] 🟨 新建笔记写入内容后，不点 ✓ 直接返回 → entry 出现在 History，顺序按保存时间
- [ ] 🟨 打开已有 entry 修改文字/图片/语音后返回 → 弹出「是否保存更改？」；选 Save 则持久化并刷新 `updatedAt`；选 Don't Save 则丢弃改动、时间不变
- [ ] 🟨 打开已有 entry **未修改**直接返回 → 无弹窗，`updatedAt` 不变
- [ ] 🟨 系统返回键与 App 内 `<` 行为完全一致（含 markBoard / selectionMode）
- [ ] 🟨 置顶 / 改分类后 History 排序位置不因操作而改变（相对同 updatedAt 条目）
- [ ] 🟨 手动点 ✓ 保存后 `updatedAt` 更新，条目在 unpinned 区上移

---

## 风险 / 注意

- dirty 检测需覆盖 embed（图片/语音）增删改，避免仅比 text
- auto-save 与 voice/image 异步写入时序：先落盘 media 再 save entry
- `copyWith` API 变更需审计所有 call site（`entry_edit_screen.dart` 等 legacy 路径）

---

## 产品确认（全部完成 ✅）

- [x] 新建空笔记离开 → 作废不创建
- [x] 未保存确认 → 居中 Dialog，标题「是否保存更改？」，按钮 Save / Don't Save
- [x] 逐层返回 1→5 全部正确
- [x] 批量改分类不更新 `updatedAt`（与置顶同逻辑）

---

## 非目标

- 不改 History 卡片视觉
- 不引入云端同步 / Supabase 字段变更
- 不改 pinned-first 排序规则本身
