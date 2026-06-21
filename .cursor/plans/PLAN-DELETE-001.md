# PLAN-DELETE-001: Log Calendar & Logs 记录删除功能

**Overall Progress:** `100%`

## TLDR

为 Log Calendar 底部弹窗和 Logs 页面新增排便记录删除功能。Calendar 支持**左滑揭示**和**长按气泡**两种触发方式，Logs 仅支持**长按气泡**。点击垃圾桶后弹出液体玻璃样式确认弹窗，确认后删除整条 `BowelRecord`，两页 + 图表通过共享 Provider 自动同步。

## Critical Decisions

- **删除范围：** 整条 `BowelRecord`（不论有无问卷），调用已有的 `LocalStorage.deleteRecord(id)`
- **数据同步：** 删除后调用 `bumpRecordsRefresh(ref)` 即可，两页 + 图表共享 `recordsWithRefreshProvider` 自动刷新
- **Calendar 两种手势并存：** 左滑揭示 + 长按气泡，共存于 `DayRecordsSheet` 的 `ListView` 行
- **Logs 仅长按：** 长按整个记录卡片区域出气泡
- **确认弹窗样式：** 复用 Private Space `_PrivateSpaceSplitDialog` 的字体排布结构，但将 `sheetBackground` 替换为 `TimerBlueGlassPanel` 液体玻璃样式
- **垃圾桶气泡样式：** 液体玻璃背景（`TimerBlueGlassPanel` 同款渐变） + 白色 `Icons.delete_outline`
- **深蓝色 = `0xFF0088FF`：** 滑动揭示区域背景色（Archive 专属蓝）

## Architecture — 新增文件与修改点

### 新建 1 个文件（共享删除 UI 组件）

```
lib/features/archive/widgets/record_delete_ui.dart
```

包含 3 个组件：
1. **`DeleteBubble`** — 长按气泡（液体玻璃 + 白色垃圾桶），使用 `OverlayEntry` 定位于目标上方居中
2. **`showRecordDeleteConfirmDialog()`** — 确认弹窗（液体玻璃版 SplitDialog）
3. **`deleteRecordAndRefresh()`** — 统一删除逻辑（`LocalStorage.deleteRecord` + `bumpRecordsRefresh`）

### 修改 2 个现有文件

| 文件 | 改动 |
|------|------|
| `day_records_sheet.dart` | ListView 行包裹 `_SwipeToDeleteRow`（左滑）+ `GestureDetector.onLongPress`（气泡） |
| `logs_card.dart` | 每条记录 `GestureDetector.onLongPress` → 弹出气泡 |

### 不动的文件

| 文件 | 原因 |
|------|------|
| `local_storage.dart` | `deleteRecord(id)` 已存在 |
| `records_provider.dart` | `bumpRecordsRefresh` 已存在 |
| `bowel_record.dart` | 数据模型无需变更 |
| `new_archive_screen.dart` | Provider watch 已就位，自动刷新 |

## Tasks

- [x] 🟩 **Step 1: 新建 `record_delete_ui.dart` — 共享删除 UI 组件**
  - [x] 🟩 1a. `DeleteBubble` widget — 液体玻璃气泡
    - 圆角胶囊形状，使用 `TimerBlueGlassPanel` 同款渐变（`0xFF0088FF` @ 34%→48% alpha + blur 12）
    - 内含白色 `Icons.delete_outline`（size 24）+ 轻触 padding
    - 通过 `OverlayEntry` 插入，定位于目标 widget 正上方居中（使用 `GlobalKey` + `RenderBox` 计算位置）
    - 点击外部区域自动 dismiss
    - 触发 `HapticFeedback.mediumImpact()` 反馈
  - [x] 🟩 1b. `showRecordDeleteConfirmDialog()` — 液体玻璃确认弹窗
    - 复用 Private Space `_PrivateSpaceSplitDialog` 的**字体排布**（标题居中 + 底部双按钮 No/Yes）
    - 将 `backgroundColor: sheetBackground` 替换为液体玻璃装饰（同 `TimerBlueGlassPanel`）
    - 标题文案：`"Delete Record?"`
    - 按钮：`No`（白色半透明） / `Yes`（`0xFF0088FF` 蓝色加粗）
    - 返回 `Future<bool?>` 
  - [x] 🟩 1c. `deleteRecordAndRefresh()` 辅助函数
    - 签名：`Future<void> deleteRecordAndRefresh(WidgetRef ref, String recordId)`
    - 内部：`await LocalStorage.deleteRecord(id)` → `bumpRecordsRefresh(ref)`

- [x] 🟩 **Step 2: `DayRecordsSheet` — 左滑揭示删除**
  - [x] 🟩 2a. 创建 `_SwipeToDeleteRow` 内部 widget
    - 使用 `AnimationController` + `GestureDetector` 实现水平拖拽（非 `Dismissible`，因为只揭示不自动移除）
    - 拖拽方向：仅允许从右向左（`dx < 0`）
    - 揭示区域：右侧固定宽度（~64px），背景色 `0xFF0088FF`，白色 `Icons.delete_outline` 居中
    - 松手后：超过阈值 snap open，否则 snap close
    - 点击垃圾桶 → 调用 `showRecordDeleteConfirmDialog()` → 确认后 `deleteRecordAndRefresh()`
    - 确认/取消后自动 snap close
  - [x] 🟩 2b. 将现有 `InkWell > ListTile` 包裹进 `_SwipeToDeleteRow`
    - 保留原有 `onTap` → `_onRowTap(record)` 行为不变
    - 需要 `ClipRRect` 裁切圆角以匹配列表行样式

- [x] 🟩 **Step 3: `DayRecordsSheet` — 长按气泡删除**
  - [x] 🟩 3a. 为每行 `ListTile` 添加 `onLongPress`
    - 使用 `GlobalKey` 获取行的 `RenderBox` 位置
    - 调用 `DeleteBubble` 显示气泡于行的正上方居中
    - `HapticFeedback.mediumImpact()`
  - [x] 🟩 3b. 气泡内垃圾桶点击 → `showRecordDeleteConfirmDialog()` → 确认后删除
  - [x] 🟩 3c. 确保左滑与长按不冲突
    - `_SwipeToDeleteRow` 的 `GestureDetector` 仅处理水平拖拽
    - 长按由外层 `GestureDetector` 处理
    - 如果行处于滑开状态，长按先 snap close 再弹气泡

- [x] 🟩 **Step 4: `LogsCard` — 长按气泡删除**
  - [x] 🟩 4a. 为 `_buildLogList()` 中每条记录的外层 `Padding` 包裹 `GestureDetector`
    - `onLongPress` → 使用 `GlobalKey` 获取位置 → 显示 `DeleteBubble`
    - `HapticFeedback.mediumImpact()`
  - [x] 🟩 4b. 气泡内垃圾桶点击 → `showRecordDeleteConfirmDialog()` → 确认后 `deleteRecordAndRefresh()`
  - [x] 🟩 4c. `LogsCard` 需要升级为 `ConsumerStatefulWidget`（当前是 `StatefulWidget`）以访问 `WidgetRef`
    - 或通过回调 `onDeleteRecord` 将删除操作上抛至 `NewArchiveScreen`（已有 ref）
    - **推荐方案：回调上抛**，保持 `LogsCard` 职责单一，在 `NewArchiveScreen` 统一处理删除
  - [x] 🟩 4d. 删除后如果当日记录清空，自动显示 `"No Logs Yet"` 占位（已有逻辑，Provider 刷新后自动触发）

- [x] 🟩 **Step 5: 边界情况处理与测试**
  - [x] 🟩 5a. Calendar 底部弹窗：删除最后一条记录后自动关闭 sheet（`Navigator.pop`）
  - [x] 🟩 5b. Calendar 底部弹窗：删除后序号自动重排（Provider 刷新 → `ListView.builder` 自动重建）
  - [x] 🟩 5c. 如果有 overlay（只读/交互问卷）打开中，长按/滑动应被忽略或先关闭 overlay
  - [x] 🟩 5d. 编写 widget test：确认弹窗 Yes/No 行为、删除后列表更新

## Execution Order Rationale

1. **Step 1 先行**：共享组件是 Step 2-4 的依赖，先建立稳定的基础 API
2. **Step 2 → Step 3**：Calendar 的两种交互在同一文件内，先做滑动（独立性高），再叠加长按（需处理冲突）
3. **Step 4 在后**：Logs 页面交互更简单（仅长按），且可复用 Step 1 + Step 3 的气泡逻辑
4. **Step 5 收尾**：边界情况需要 Step 2-4 完成后才能全面验证

## Key Implementation Notes

### 滑动揭示（非 Dismissible）
不使用 Flutter 内置 `Dismissible`，因为需求是「揭示垃圾桶按钮」而非「滑走整行」。用 `AnimationController` + `GestureDetector.onHorizontalDragUpdate/End` 手动控制，类似 Private Space 的 `_SwipeRevealCard` 但更简单（仅一个 action）。

### 气泡定位策略
```dart
// 获取目标 widget 在屏幕中的位置
final RenderBox box = key.currentContext!.findRenderObject() as RenderBox;
final Offset target = box.localToGlobal(Offset.zero);
final Size size = box.size;

// 气泡居中于目标上方
final bubbleLeft = target.dx + size.width / 2 - bubbleWidth / 2;
final bubbleTop = target.dy - bubbleHeight - 8; // 8px gap
```

### 确认弹窗（液体玻璃版）
基于 `_PrivateSpaceSplitDialog` 结构，但 `Dialog.backgroundColor` 设为透明，外层包裹 `TimerBlueGlassPanel`：
```dart
Dialog(
  backgroundColor: Colors.transparent,
  child: TimerBlueGlassPanel(
    child: Column(/* 标题 + 按钮，排布同 _PrivateSpaceSplitDialog */),
  ),
)
```

### LogsCard 删除回调链
```
LogsCard.onDeleteRecord(recordId)
  → NewArchiveScreen._handleDeleteRecord(recordId)
    → showRecordDeleteConfirmDialog()
    → deleteRecordAndRefresh(ref, recordId)
```
避免 `LogsCard` 持有 `WidgetRef`，保持与现有 `onSubmitAnswers` 回调模式一致。
