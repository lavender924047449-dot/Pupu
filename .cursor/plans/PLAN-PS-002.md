# Feature Implementation Plan — PS-002 RECORDS 删除确认弹窗

**Overall Progress:** `100%`

## TLDR

在 Private Space **RECORDS**（History 列表）的两处删除入口（左滑删除图标、长按多选后底部 Delete）前增加确认弹窗；视觉与 `Save Changes?` 完全一致。顺带删除已无引用的 legacy `EntryEditScreen`。

---

## Critical Decisions

- **复用 `_PrivateSpaceSplitDialog`** — 与 `showPrivateUnsavedChangesDialog` 同壳，零新 UI 组件，维护成本最低
- **新增 `showPrivateDeleteRecordDialog({required bool plural})`** — 单一入口，单/复数文案由 `plural` 控制
- **按钮布局** — 左 `No`（灰）/ 右 `Yes`（金色 accent + w600），与 Save Changes 左右语义一致
- **文案** — 1 条：`Delete Record?`；≥2 条：`Delete Records?`
- **`barrierDismissible: false`** — 与 Save Changes 相同，必须点 Yes/No
- **点 No** — 不删除；左滑场景须收起 `_SwipeRevealCard` 操作区
- **范围** — 仅 RECORDS 列表两处删除；不改 `entry_edit_screen` 以外的其他模块
- **死代码** — 删除 `entry_edit_screen.dart`（全项目无 import/路由引用）

---

## Tasks

- [x] 🟩 **Step 1: 删除 legacy `EntryEditScreen`**
  - [x] 🟩 删除 `lib/features/private_space/entry_edit_screen.dart`
  - [x] 🟩 确认 `lib/` 无残留引用；`flutter analyze` 已执行（存在仓库既有问题，见下方验收）

- [x] 🟩 **Step 2: 新增删除确认弹窗 API**
  - [x] 🟩 在 `private_space_ui.dart` 新增 `showPrivateDeleteRecordDialog`
  - [x] 🟩 复用 `_PrivateSpaceSplitDialog` + `PrivateSpaceDialogStyles`
  - [x] 🟩 返回 `bool?`：`true` = Yes，`false` = No，`null` = 未选择（不应出现，因不可 dismiss）

- [x] 🟩 **Step 3: 接入单条删除（左滑）**
  - [x] 🟩 `_deleteEntry` 改为先弹窗、Yes 后再调 `LocalStorage.deleteEntry`
  - [x] 🟩 `_HistoryEntryCard` / `_SwipeRevealCard`：点 No 或取消时触发关闭收起滑出区
  - [x] 🟩 最小改动：通过 `shouldClose` 信号关闭 `_SwipeRevealCard`，不重构手势逻辑

- [x] 🟩 **Step 4: 接入批量删除（长按多选）**
  - [x] 🟩 `_batchDeleteSelected` 先弹窗，`plural: _selectedEntries.length >= 2`
  - [x] 🟩 Yes 后批量删除并退出选择模式（保持现有 `_loadEntries` + state 清理逻辑）

---

## 关键文件

| 路径 | 变更 |
|------|------|
| `lib/features/private_space/private_space_ui.dart` | 新增 `showPrivateDeleteRecordDialog` |
| `lib/features/private_space/private_space_screen.dart` | 删除流程加确认；滑卡收起 |
| `lib/features/private_space/entry_edit_screen.dart` | **删除** |

---

## 验收清单

- [x] 左滑 → 点删除 → 弹窗 `Delete Record?` → No：不删、滑出区收起（代码路径已接入）
- [x] 左滑 → 点删除 → Yes：记录消失（代码路径已接入）
- [x] 长按选 1 条 → Delete → `Delete Record?`（由 `plural` 动态控制）
- [x] 长按选 ≥2 条 → Delete → `Delete Records?`（由 `plural` 动态控制）
- [x] 批量点 No：不删、保持选择模式（代码路径已接入）
- [x] 批量点 Yes：全部删除、退出选择模式（代码路径已接入）
- [x] 弹窗样式/字号/位置与 Save Changes 一致；点外部不关闭（复用同一 Dialog 壳）
- [x] `flutter analyze` 已运行：存在仓库既有告警与无关错误（`test/private_space_clipboard_test.dart` 的 `encodeImage`）

---

## 回滚

- 恢复 `entry_edit_screen.dart`（若需）
- 移除 `showPrivateDeleteRecordDialog`，`_deleteEntry` / `_batchDeleteSelected` 恢复直接删除
