# 弹层家族对照表

> **用途：** 新增或修改弹层/UI 反馈时，先归类再选 helper，避免 ad-hoc `showDialog` 样板代码。  
> **关联 plan：** [PLAN-DIALOG-001.md](../plans/PLAN-DIALOG-001.md)  
> **最后更新：** 2026-06-12

---

## 第一性原理（速记）

| 原则 | 含义 |
|------|------|
| 弹层 = 意图 + 呈现 + 平台 | Service 只表达意图（enum）；UI hub 决定怎么弹；平台分支在 helper 内 |
| 字体 = 策略 | 正文用 `AppTypography`；装饰字体（Raleway、Josefin）例外 |
| Helper = 怎么弹 | 内容、回调由调用方传；遮罩/Navigator/平台由 helper 固定 |

---

## 家族总览

| 家族 ID | 名称 | 视觉特征 | Helper / 入口 | 主要使用场景 | 状态 |
|---------|------|----------|---------------|--------------|------|
| **F1** | Timer 蓝玻璃 | 蓝渐变 `#0088FF`、blur 12、圆角 24、白边 | `TimerBlueGlassPanel` + `showTimerGlassDialog` | Finish Session、Unfinished、Stop、MaybeLater、必选警示、DayRecords 壳 | ✅ 已有 |
| **F2** | Private 分栏 | 实色 `#121A26`、圆角 14、左右分栏按钮 44px | `showPrivateTextDialog` / `showPrivateUnsavedChangesDialog` / `showPrivateDeleteRecordDialog` | Save Changes、Rename、Delete、Unsaved | ✅ 已有 |
| **F3** | Private 系统权限 | iOS 系统 Cupertino / Android Material | `showPrivatePermissionSettingsDialog` | 权限永久拒绝 → 去设置 | ✅ PLAN-DIALOG-001 |
| **F4** | Private 权限 Retry | Material SnackBar + Retry | `showPrivatePermissionRetrySnack` | 权限可重试拒绝 | ✅ PLAN-DIALOG-001 |
| **F5** | Private 底部 Sheet | `#121A26`、顶圆角 18、ListTile | `showPrivateActionSheet` | 图片 Copy/Cut/Delete、插入来源选择 | ✅ 已有 |
| **F6** | Private 语音 Sheet | `#0E1520`、顶圆角 20、金色顶边 | 直接 `showModalBottomSheet`（P2 可抽 helper） | 录音面板 | ✅ 字体已补 AppTypography |
| **F7** | Archive 白玻璃 | 白 20% + blur 25、圆角 16 | 内联 `showDialog`（**暂不抽 helper**） | 热力图、Issue Breakdown | ✅ 已有 |
| **F8** | 问卷 Overlay | 白 35% + blur 50、284×406、圆角 24 | `QuestionnaireOverlay` + `OverlayEntry` | 问卷只读/交互 | ✅ 已有 |
| **F9** | Chart 内联浮层 | 卡片 Stack 内 Positioned，非模态 | 无 helper（**不在统一 scope**） | Trend Popup、Status Grid Bubble | ✅ 已有 |
| **F10** | 全屏预览 | `Dialog.fullscreen` 纯黑 | 内联（P2 可抽） | Private 图片预览 | ✅ 已有 |

---

## 家族详情

### F1 — Timer 蓝玻璃

| 属性 | 值 |
|------|-----|
| 视觉壳 widget | `lib/core/widgets/timer_blue_glass_panel.dart` → `TimerBlueGlassPanel` |
| 挂载 helper | `lib/features/timer/widgets/timer_dialogs.dart` → `showTimerGlassDialog` |
| 遮罩 | `Colors.black @ 0.4`，`barrierDismissible: true`（默认） |
| Dialog 背景 | `Colors.transparent` |
| 字体 | 各内容 widget 内 inline SF Pro / `AppTypography`（PLAN-DIALOG-001 后） |
| 尺寸/字重 | **按设计各异，不统一** |

**内容 widget（均在 `timer_dialogs.dart`）：**

- `TimerSelectOptionAlertDialog`
- `TimerFinishSessionDialog`
- `TimerUnfinishedLogDialog`
- `TimerMaybeLaterDialog`
- `TimerStopConfirmDialog`

**复用 F1 壳的非 Timer 场景：**

- `DayRecordsSheet` — `TimerBlueGlassPanel` + 顶圆角 20

**规则：**

- 新 Timer 系模态弹窗 → 必须用 `showTimerGlassDialog`
- 禁止在 screen 内复制 `showDialog` + 透明 Dialog 样板（`timer_screen` Stop/MaybeLater 待收口）

---

### F2 — Private 分栏 Dialog

| 属性 | 值 |
|------|-----|
| 内部 shell | `_PrivateSpaceSplitDialog`（`private_space_ui.dart`） |
| 背景 | `PrivateSpaceColors.sheetBackground` `#121A26` |
| 圆角 | 14 |
| insetPadding | horizontal 52 |
| 标题样式 | `PrivateSpaceDialogStyles.title` → SF Pro 17 w600 `#F6E6B3` |
| 按钮 | 左 `white54` / 右 `accent #E2BE57`（默认项 w600） |
| barrierDismissible | Rename/Unsaved/Delete：`false` |

**公开 helper：**

- `showPrivateTextDialog`
- `showPrivateUnsavedChangesDialog`
- `showPrivateDeleteRecordDialog`

**规则：**

- Private 模块内「确认/取消」类对话框 → 复用 F2，勿用 Material `AlertDialog`

---

### F3 — Private 系统权限（去设置）

| 属性 | 值 |
|------|-----|
| Helper | `showPrivatePermissionSettingsDialog` | ✅ `private_space_ui.dart` |
| 触发 | `PrivatePermissionResult.deniedPermanently` |
| iOS | `CupertinoAlertDialog` — **系统默认外观**（白/模糊，不套 Private 深色） |
| Android | Material `AlertDialog` + `AppTypography` + SF Pro |
| 架构 | UI 在 `private_space_ui.dart`；`PrivatePermissionHelper` 零 UI |

**与系统权限弹窗的区别：**

- **首次权限请求** — iOS/Android **系统原生**，`permission_handler` 自动弹出，**不可自定义**
- **F3** — 仅「永久拒绝后引导去设置」的 **App 内** dialog

---

### F4 — Private 权限 Retry

| 属性 | 值 |
|------|-----|
| Helper | `showPrivatePermissionRetrySnack` + `resolvePrivatePermissionResult` | ✅ `private_space_ui.dart` |
| 触发 | `PrivatePermissionResult.deniedRetryable` |
| 形式 | SnackBar + Retry action |
| 字体 | `AppTypography.body()` |

**注意：** 非全局 SnackBar 统一；仅权限模块专用。

---

### F5 — Private 底部 Action Sheet

| 属性 | 值 |
|------|-----|
| Helper | `showPrivateActionSheet` |
| 背景 | `#121A26` |
| 顶圆角 | 18 |
| 行样式 | ListTile，accent icon，白字 title，white38 subtitle |
| Haptic | `PrivateSpaceHaptics.menuOpen()` |

**相关：** `privatePopupMenuItem` — PopupMenu 行样式与 sheet 对齐

---

### F6 — Private 语音录音 Sheet

| 属性 | 值 |
|------|-----|
| 入口 | `private_space_screen` → `showModalBottomSheet(transparent)` |
| Widget | `PrivateVoiceRecordSheet` |
| 背景 | `#0E1520`（与 F2/F5 的 `#121A26`  intentionally 不同 — 设计预期） |
| 顶圆角 | 20 |
| 顶边 | 金色 `#55D9B34A` |

**P2 可选：** 抽 `showPrivateVoiceRecordSheet` helper

---

### F7 — Archive 白玻璃 Dialog

| 属性 | 值 |
|------|-----|
| 位置 | `chart_analysis_card.dart` 内联 |
| 背景 | 白 20% + blur 25 |
| 圆角 | 16 |
| 遮罩 | `black @ 0.35` |
| Helper | **暂无**（与 F1 参数不同，本次不抽） |

---

### F8 — 问卷 Overlay

| 属性 | 值 |
|------|-----|
| Widget | `QuestionnaireOverlay` |
| 挂载 | `OverlayEntry`（非 `showDialog`） |
| 尺寸 | 284 × 406 |
| 背景 | 白 35% + blur 50，圆角 24 |
| 关闭 | 点遮罩 / PopScope |

**使用方：** `day_records_sheet.dart`、`logs_card.dart`

---

### F9 — Chart 内联浮层（非模态）

| 类型 | 实现 | 说明 |
|------|------|------|
| Trend Popup | `_buildTrendPopup` | 折线图点上方，Stack Positioned |
| Status Grid Bubble | `_buildStatusGridBubble` | 热力格选中后，Stack Positioned |

**与 showDialog 区别：**

- 不阻塞全屏；不走 Navigator 弹栈
- 生命周期由 Chart state 管理
- **不在 PLAN-DIALOG-001 scope**

---

### F10 — 全屏预览

| 属性 | 值 |
|------|-----|
| 位置 | `private_space_screen.dart` |
| 形式 | `Dialog.fullscreen`，纯黑背景 + 关闭按钮 |

---

## 字体策略（跨家族）

| 场景 | 字体来源 |
|------|----------|
| 正文 / 弹框 / SnackBar（scope 内） | `AppTypography.bodyFontFamily` — iOS: `.SF Pro Text`；其它: `'SF Pro'` |
| Private 分栏标题/按钮 | `PrivateSpaceDialogStyles` → 引用 AppTypography |
| 装饰性 copy | `@decorative` — Raleway（Home）、Josefin Sans（Timer 音频/摘要） |
| Cupertino 系统 alert（F3 iOS） | 系统字体，不 override |

---

## 新弹层决策流程

```
新 UI 反馈需求
    │
    ├─ 需要阻塞全屏、Navigator 弹栈？
    │   ├─ 否 → 是否 Chart 内局部？→ F9 或自定义 Stack
    │   └─ 是 ↓
    │
    ├─ Timer / 日志模块 + 蓝玻璃？ → F1 + showTimerGlassDialog
    ├─ Private 确认/输入？         → F2 + showPrivate*Dialog
    ├─ Private 权限永久拒绝？      → F3
    ├─ Private 权限可重试？        → F4
    ├─ Private 操作列表？          → F5
    ├─ Archive 图表大图？          → F7（内联，或未来抽 helper）
    ├─ 问卷表单？                  → F8
    └─ 以上都不符？                → 先与产品/架构确认，再考虑新家族
```

---

## 禁止模式

- ❌ 在 `services/` 内 `showDialog` / `SnackBar`
- ❌ 新增 Material `AlertDialog` 于 Private 模块（应用 F2 或 F3）
- ❌ 复制 `showDialog(barrierColor: ..., Dialog(transparent...))` 样板 — 用已有 helper
- ❌ 在 scope 文件硬编码 `'Segoe UI'` 或非 AppTypography 的正文字体
- ❌ 为统一而统一各弹框尺寸/字重（设计预期差异）

---

## 相关文档

- [PLAN-DIALOG-001.md](../plans/PLAN-DIALOG-001.md) — 实施计划
- [PS-011-permission-dialog-layer.md](../issues/PS-011-permission-dialog-layer.md) — 权限分层 issue
- [PLAN-ARCH-001.md](../plans/PLAN-ARCH-001.md) — 全库四层架构
