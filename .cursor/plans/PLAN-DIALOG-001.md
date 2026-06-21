# 统一玻璃弹框 Widget 提取与改造



**Overall Progress:** `100%`



## TLDR



将 Log Calendar 删除确认弹框的视觉样式提取为全局通用 Widget `AppGlassDialog`，放置在 `lib/core/widgets/`。然后将 Timer 页的 4 个弹框全部改造为使用该通用组件，实现除 Private Space 外的全局弹框样式统一。



## Critical Decisions



- **Widget 位置**：放 `lib/core/widgets/app_glass_dialog.dart` — 因为需跨 feature 复用

- **宽度策略**：使用 `insetPadding: horizontal 52` 响应式宽度，替代 Timer 原有的固定 width/height

- **按钮顺序**：统一 No 左 / Yes 右（Timer Stop 原为 Yes 左 / No 右，需翻转）

- **MaybeLater**：保持单按钮，但字号/padding/面板参数统一

- **SelectOptionAlert**：无按钮纯提示，仅统一面板+字体，保留 autoDismiss 机制

- **Private Space**：完全不动



## 目标样式规格（源自 `showRecordDeleteConfirmDialog`）



| 属性 | 值 |

|------|-----|

| 面板 | `TimerBlueGlassPanel`, `borderRadius: 14` |

| Dialog insetPadding | `EdgeInsets.symmetric(horizontal: 52)` |

| 标题样式 | `AppTypography.dialogTitle(color: Color(0xFFE6F0FF))` — size 17, w600 |

| 标题 padding | `EdgeInsets.fromLTRB(16, 20, 16, 20)` |

| 按钮行高 | 44 |

| No 按钮 | `AppTypography.body(size: 17, weight: w400, color: Colors.white70)` |

| Yes 按钮 | `AppTypography.body(size: 17, weight: w600, color: Color(0xFF0088FF))` |

| 按钮布局 | `Row` + 双 `Expanded`，各包裹 `Material(transparent) > InkWell > Center > Text` |

| barrierDismissible | 双按钮默认 false，单/无按钮默认 true |



## 涉及文件



| 文件 | 操作 |

|------|------|

| `lib/core/widgets/app_glass_dialog.dart` | **新建** — 通用 Widget + show 函数 |

| `lib/features/timer/widgets/timer_dialogs.dart` | **改写** — 4 个弹框全部改用 AppGlassDialog |

| `lib/features/archive/widgets/record_delete_ui.dart` | **改写** — 删除确认弹框改用 AppGlassDialog，删除本地 `_DialogActionButton` |



## Tasks



- [x] 🟩 **Step 1: 新建 `lib/core/widgets/app_glass_dialog.dart`**

  - [x] 🟩 1.1 创建 `AppGlassDialog` Widget，支持三种模式：

    - 双按钮模式（title + leftLabel/rightLabel + onLeft/onRight）

    - 单按钮模式（title + singleLabel + onSingle）

    - 无按钮模式（title only）

  - [x] 🟩 1.2 内部结构：`TimerBlueGlassPanel(borderRadius: 14)` > `Column(mainAxisSize: min)` > 标题 Padding + 可选按钮行

  - [x] 🟩 1.3 内部提取 `_DialogActionButton`（从 record_delete_ui.dart 移来），双按钮模式下左按钮用 white70/w400，右按钮用 #0088FF/w600

  - [x] 🟩 1.4 创建 `showAppGlassDialog()` 快捷函数，封装 `showDialog` + `Dialog(transparent, insetPadding: h52)` + 可选 `autoDismissSeconds`

  - [x] 🟩 1.5 **API 设计细节**：

    ```dart

    /// 双按钮用法：

    showAppGlassDialog(context,

      child: AppGlassDialog.confirm(

        title: 'Delete Record?',

        onNo: () => Navigator.pop(ctx, false),

        onYes: () => Navigator.pop(ctx, true),

      ),

    );

    

    /// 单按钮用法：

    showAppGlassDialog(context,

      child: AppGlassDialog.single(

        title: 'You can always log it later...',

        buttonLabel: 'Got it(Back to Home)',

        onTap: () => ...,

      ),

    );

    

    /// 无按钮用法（自动消失）：

    showAppGlassDialog(context,

      autoDismissSeconds: 2,

      child: AppGlassDialog.alert(

        title: 'Please select an option',

      ),

    );

    ```



- [x] 🟩 **Step 2: 改造 `timer_dialogs.dart` 的 4 个弹框**

  - [x] 🟩 2.1 `TimerStopConfirmDialog` → 使用 `AppGlassDialog.confirm(title: 'Stop timing?')`，按钮改为 No 左 / Yes 右

  - [x] 🟩 2.2 `TimerFinishSessionDialog` → 使用 `AppGlassDialog.confirm(title: 'Are you sure you are finished?')`

  - [x] 🟩 2.3 `TimerMaybeLaterDialog` → 使用 `AppGlassDialog.single(title: 'You can always log it later...', buttonLabel: 'Got it(Back to Home)')`

  - [x] 🟩 2.4 `TimerSelectOptionAlertDialog` → 使用 `AppGlassDialog.alert(title: 'Please select an option')`

  - [x] 🟩 2.5 保留 `showTimerGlassDialog` 函数签名不变（内部可委托给 `showAppGlassDialog`），避免改动 `timer_screen.dart` 和 `questionnaire_interactive_panel.dart` 的调用处

  - [x] 🟩 2.6 清理已废弃的 `_AutoDismissGlassDialogWrapper`（逻辑已移入 `showAppGlassDialog`）



- [x] 🟩 **Step 3: 改造 `record_delete_ui.dart`**

  - [x] 🟩 3.1 `showRecordDeleteConfirmDialog` 改为调用 `showAppGlassDialog` + `AppGlassDialog.confirm`

  - [x] 🟩 3.2 删除本地 `_DialogActionButton` 类（已移入核心）

  - [x] 🟩 3.3 `showDeleteBubble` 和 `deleteRecordAndRefresh` 保持不变



- [x] 🟩 **Step 4: 验证**

  - [x] 🟩 4.1 确认 `timer_screen.dart` 中 `_showStopConfirmDialog` / `_showMaybeLaterDialog` / `_onFinishLoggingTapped` 无需改动（因为 Widget 名字和构造参数保持兼容）

  - [x] 🟩 4.2 确认 `questionnaire_interactive_panel.dart` 中 `showTimerGlassDialog` + `TimerSelectOptionAlertDialog` 无需改动

  - [x] 🟩 4.3 运行 `flutter analyze` 确保无编译错误

  - [x] 🟩 4.4 运行已有测试 `test/record_delete_ui_test.dart`



## 执行顺序说明



**必须按 Step 1 → 2 → 3 → 4 顺序执行**，原因：

- Step 1 是基础设施，后续步骤依赖它

- Step 2 改 Timer 弹框时需要 AppGlassDialog 已存在

- Step 3 改 Archive 弹框可以在 Step 2 之后并行，但放后面是因为 Archive 是样式源头，最后改可以做最终对比验证

- Step 4 是全局验证，必须最后



## 风险点



- `TimerStopConfirmDialog` 按钮顺序翻转（Yes↔No），用户习惯可能需适应

- `showTimerGlassDialog` 保留为薄包装，如果将来要废弃需单独 PR


