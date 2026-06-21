# PLAN-PS-HISTORY-SCROLL-001: Private Space History 滚动位置记忆

**Overall Progress:** `100%`

## TLDR

RECORDS 列表在「点进记录编辑 → 返回」后恢复离开前的 scroll offset；FAB「+」新建并**保存**后回到顶部；离开 Private Space（history → idle）不跨 session 记忆。

## Critical Decisions

- **记忆范围：** 仅 notepad ↔ history 切换；history → idle → 再进从顶部开始
- **保存已有记录：** 保持原 scroll（条目因 `updatedAt` 重排也不跟随）
- **FAB 新建保存：** `jumpTo(0)`（含 Back 自动保存路径）
- **FAB 新建未保存返回：** 恢复进入前的 scroll
- **恢复方式：** `jumpTo`，无动画；对 `maxScrollExtent` clamp
- **Controller 分离：** 主列表用 `_historyListScrollController`；分类面板用 `_categoryPanelScrollController`

## Tasks

- [x] 🟩 **Step 1: 滚动工具与 state**
  - [x] 🟩 1a. `clampHistoryScrollOffset()` 纯函数（`private_space_history.dart`）
  - [x] 🟩 1b. `_historyListScrollController` + `_HistoryScrollOnShow` intent enum
  - [x] 🟩 1c. `_captureHistoryListScrollOffset()` / `_applyPendingHistoryScroll()`

- [x] 🟩 **Step 2: 导航钩子**
  - [x] 🟩 2a. `_editFromHistory` / `_createNoteFromHistory` 离开前 capture
  - [x] 🟩 2b. `_exitNotepad` → restore；`_saveNote` / 新建 Back 自动保存 → top
  - [x] 🟩 2c. history → idle 清除记忆（`_clearHistoryScrollMemory`）
  - [x] 🟩 2d. ListView 绑定 `_historyListScrollController`

- [x] 🟩 **Step 3: 测试**
  - [x] 🟩 3a. `test/private_space_history_scroll_test.dart` — clamp 单元测试 4 条

## Changed Files

| 文件 | 改动 |
|------|------|
| `lib/features/private_space/private_space_screen.dart` | scroll controller、intent、导航钩子 |
| `lib/features/private_space/private_space_history.dart` | `clampHistoryScrollOffset()` |
| `test/private_space_history_scroll_test.dart` | 新建 |

## First-Record Navigation Fix (2026-06-15)

保存第一条 record 后误回 idle：`_returnToHistoryFromNotepad` 读 `_entries.isEmpty`，但 Provider 异步刷新尚未完成。修复：`_persistNote` 保存后立即乐观更新 `_entries`。


History 在 Chrome/Web 崩溃 `Platform._operatingSystem`：
- 根因：History 卡片预览调用 `dart:io` `File()`；`AppTypography` 使用 `Platform.isIOS`
- 修复：新增 `PrivateNoteImage`（web 安全）；`AppTypography` / permission helper 改用 `kIsWeb` + `defaultTargetPlatform`


- [ ] 滚到列表底部 → 点记录 → Back → 位置不变
- [ ] 滚到中间 → 点记录 → Save → 位置不变（条目可能已排到顶部）
- [ ] FAB「+」→ 输入内容 → Save → 回到顶部
- [ ] FAB「+」→ 空内容 Back → 位置不变
- [ ] history → idle（chevron）→ 再进 → 从顶部开始
