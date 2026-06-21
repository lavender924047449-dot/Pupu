# PLAN-COPY-UI-001: 全 App 英文文案统一 + UI 排版优化

**Overall Progress:** `100%`

---

## TLDR

系统性统一全 App 面向用户的英文用词（Log / Entry 术语体系、iOS 大小写、弹框范式、问卷语法）并优化关键面板 UI 排版（Session Summary 流式布局 + 统计两列对齐 + 说明文折叠、Questionnaire 浮层 sticky footer、Archive 卡片弹性尺寸）。**内部函数/类名不重命名**，仅改字符串与 UI 结构；相关 widget test 随文案同步更新。

**状态：已完成。** `flutter test` 147/147 全绿。

---

## 术语词典（产品级，全文件通用）

| 语境 | 术语 | 禁用 |
|------|------|------|
| 肠道追踪数据 | **log** (n./v.) / **logs** (pl.) | record |
| 问卷填写内容集合 | **log details** | questionnaire (用户可见层) |
| 图表空数据提示 | **log data** | questionnaire data |
| 私人笔记条目 | **entry** / **entries** | record |
| 计时会话 | **session** | — |
| 弹框按钮 | iOS sentence case: Cancel / Leave / Delete / Stop | ALL CAPS |
| 斜杠标签 | 空格斜杠空格: `Dry / Hard` | `Dry/Hard` |
| 缩写 | Phys / Psych / Ext（drill-down 内用） | — |

---

## Critical Decisions

| # | 决策 | 理由 |
|---|------|------|
| 1 | **只改字符串 + UI 结构，不重命名内部函数/类** | 文案轮聚焦用户可见层；函数重命名另开 refactor ticket，降低本轮 regression 风险 |
| 2 | **去 Q 编号仅改 UI 渲染，QuestionId / codec / flow 不动** | Q 编号是 UI 生成的 `index+1`，与逻辑层 `QuestionId` 枚举完全解耦；删除安全 |
| 3 | **Session Summary 改流式 Column + Flexible，不改绝对坐标系** | 现 `sx/sy` 仍保留用于水平缩放；垂直方向由 Column 自动分配，解决 S1 重叠 + S6 小屏底部问题 |
| 4 | **说明文折叠复用问卷 `▼/▲` 交互模式** | 零新组件；用户已在问卷 "Any other little details?" 接触过此模式 |
| 5 | **Questionnaire 浮层外框 284×406 不改** | 牵动 Archive 全页布局；通过 sticky footer + scroll padding 解决 Finish 挡内容 |
| 6 | **`AppGlassDialog.alert` 新增可选 `message` 参数** | 支持 title + body 双区结构（Selection Required 等）；向后兼容，message 为 null 时行为不变 |
| 7 | **Private Space 日期改为 `MMM d, yyyy`** | 与 Archive 统一；减少 App 内日期格式分裂 |
| 8 | **Timer 全角冒号 `：` → ASCII `:`** | 非 iOS/Latin 标点；全 App 数字分隔符统一 |

---

## 执行注意（写入此文档供 Cursor 参考）

### C3 去 Q 编号安全说明
- `questionnaire_interactive_panel.dart`：删除 `'Q${index + 1} '` 前缀，保留 `spec.title`
- `questionnaire_readonly_panel.dart`：同上 + 顶部新增 **Log Details** 小标题
- **不改** `questionnaire_spec.dart` 的 `QuestionId`、`questionnaire_codec.dart`、`questionnaire_flow.dart`、`questionnaire_validation.dart`

### Test 同步清单
- `timer_exit_dialogs_test.dart`：Stop Timing → Stop Timer; 文案断言更新
- `record_delete_ui_test.dart`：Delete Record → Delete Log
- `private_space_delete_dialog_test.dart`：Delete Record(s) → Delete Entry/Entries
- `private_permission_helper_test.dart`：Photo library → Photos

### 说明文折叠 Session Summary
- 默认折叠一行：*You can add log details to better understand your body.*
- 展开后：*Track how it went, how you felt, and anything unusual. Smooth or not, these details help you spot patterns over time.*
- 交互：标题行 + `▼`/`▲`，点击切换；默认折叠

---

## Tasks

### Phase 1: 文案统一

- [x] 🟩 **Step 1: 基础设施 — `AppGlassDialog` 增加 `message` 参数**
  - [x] 🟩 `app_glass_dialog.dart`：`AppGlassDialog.alert` 新增可选 `String? message`；当非 null 时在 title 下方渲染 body 文本（sentence case, `#C6C6C8`, SF Pro 15）
  - [x] 🟩 向后兼容：现有所有 `.alert(title:)` 调用行为不变

- [x] 🟩 **Step 2: Timer 弹框文案**
  - [x] 🟩 `timer_dialogs.dart`：`Stop Timing?` → `Stop Timer?`
  - [x] 🟩 `timer_dialogs.dart`：`Got It (Back to Home)` → `Back to Home`
  - [x] 🟩 `timer_dialogs.dart` MaybeLater：title + message 两段式
  - [x] 🟩 `timer_session_summary.dart`：`hr` 单位（Phase 2 重构时一并处理）

- [x] 🟩 **Step 3: Questionnaire 文案**
  - [x] 🟩 `questionnaire_spec.dart`：语法修正 + stay for a long time
  - [x] 🟩 `questionnaire_interactive_panel.dart`：去 Q 编号 + Selection Required alert
  - [x] 🟩 `questionnaire_readonly_panel.dart`：去 Q 编号 + Log Details 标题

- [x] 🟩 **Step 4: Archive 文案**
  - [x] 🟩 全部完成（Delete Log、No logs、chart tooltip、Log 1 等）

- [x] 🟩 **Step 5: Private Space 文案**
  - [x] 🟩 全部完成（Entries、Category、Photos Access Blocked 等）

- [x] 🟩 **Step 6: 测试文案同步**
  - [x] 🟩 4 个 test 文件已更新
  - [x] 🟩 `flutter test` 147/147 全绿

---

### Phase 2: UI 排版优化

- [x] 🟩 **Step 7: Timer 全角冒号修复**
  - [x] 🟩 `timer_screen.dart`：ASCII 冒号

- [x] 🟩 **Step 8: Session Summary 面板重构**
  - [x] 🟩 S1 流式 Column + S5 两列统计 + S3 TextButton + S4 Semantics + S6 SafeArea
  - [x] 🟩 说明文折叠组件（方案 B）
  - [x] 🟩 S2 保持黑色 Session Summary 标题

- [x] 🟩 **Step 9: Questionnaire 浮层优化**
  - [x] 🟩 sticky footer Column 布局
  - [x] 🟩 compact 题面 16pt
  - [x] 🟩 Finish 灰色保持现状

- [x] 🟩 **Step 10: Archive 卡片排版**
  - [x] 🟩 A5 letterSpacing、A6 比例高度、A7 两行 meta、A8 Expanded 空状态

- [x] 🟩 **Step 11: Private Space 排版**
  - [x] 🟩 P1 比例高度、P2 日期格式、P3 folder_outlined

- [x] 🟩 **Step 12: 弹框结构优化**
  - [x] 🟩 alert title+message、MaybeLater 两段式

- [x] 🟩 **Step 13: 最终验证**
  - [x] 🟩 `flutter test` 147/147 全绿

---

## 改动文件清单

| 文件 | 变更类型 |
|------|----------|
| `lib/core/widgets/app_glass_dialog.dart` | message 参数 + 两段式排版 |
| `lib/features/timer/widgets/timer_dialogs.dart` | 文案 + MaybeLater 结构 |
| `lib/features/timer/widgets/timer_session_summary.dart` | 全面重构（Column/折叠/两列） |
| `lib/features/timer/timer_screen.dart` | ASCII 冒号 |
| `lib/features/questionnaire/questionnaire_spec.dart` | 语法修正 |
| `lib/features/questionnaire/widgets/questionnaire_interactive_panel.dart` | 去 Q + sticky footer + compact 16pt |
| `lib/features/questionnaire/widgets/questionnaire_readonly_panel.dart` | Log Details 标题 |
| `lib/features/archive/*` | 文案 + 排版 |
| `lib/features/private_space/*` | 文案 + 排版 |
| `lib/services/private_permission_helper.dart` | Photos |
| `test/*` | 4 个 test 文件断言同步 |

---

## 详细改动清单（供验收对照）

### 1. Timer 页

| 位置 | 改前 | 改后 | 文件 |
|------|------|------|------|
| 计时器显示 | `05：30`（全角冒号） | `05:30`（ASCII `:`） | `timer_screen.dart` |
| Stop 确认弹框标题 | Stop Timing? | **Stop Timer?** | `timer_dialogs.dart` |
| 系统返回（计时中） | Leave Timer? / This session won't be saved. | 不变 | `timer_dialogs.dart` |
| 问卷未完成返回 | You haven't finished logging. / Leave anyway? | 不变 | `timer_dialogs.dart` |
| Maybe Later 弹框 | 单行标题 + Got It (Back to Home) | 标题：**You can always log it later**<br>正文：**Find it in your Log Calendar or Logs.**<br>按钮：**Back to Home** | `timer_dialogs.dart` |
| Finish 确认 | Finish Logging? / Cancel / Finish | 不变 | `timer_dialogs.dart` |
| 多选未选 Next 警示 | Please Select an Option | 标题：**Selection Required**<br>正文：**Please select an option.** | `timer_dialogs.dart` + `app_glass_dialog.dart` |

### 2. Session Summary 面板

| 位置 | 改前 | 改后 | 文件 |
|------|------|------|------|
| 布局 | 多个 `Positioned` 绝对坐标 | 垂直 `Column` + `Spacer` + `SafeArea` 底部 | `timer_session_summary.dart` |
| 统计区 | `Text.rich` 内联 label/value | **两列对齐**（左 label / 右 value） | 同上 |
| Time since last log | `X hrs` | **`X hr`** | 同上 |
| 说明文 | 固定长段 recording these signals… | **默认折叠**一行；点击 ▼ 展开两行 | 同上 |
| 折叠文案（默认） | — | You can add log details to better understand your body. | 同上 |
| 折叠文案（展开） | — | Track how it went… / Smooth or not, these details help… | 同上 |
| Session Summary: 标题色 | 黑色 | **保持黑色**（未改） | 同上 |
| Log with me | GestureDetector | **Semantics(button) + InkWell** | 同上 |
| Maybe Later | 黑色下划线 Text | **TextButton** 半透明白色 + 下划线 | 同上 |
| Log with me / Maybe Later 文案 | 不变 | 不变 | 同上 |

### 3. Questionnaire（Log with me / Archive 补填）

| 位置 | 改前 | 改后 | 文件 |
|------|------|------|------|
| 题目前缀 | Q1 How did it go? | **How did it go?**（无 Q 编号） | `questionnaire_interactive_panel.dart` / `questionnaire_readonly_panel.dart` |
| 只读区标题 | 无 | 顶部 **Log Details** | `questionnaire_readonly_panel.dart` |
| Finish 按钮布局 | `Positioned` 右下角浮层 | **Column 底部 sticky footer**（~52pt） | `questionnaire_interactive_panel.dart` |
| Finish 文案/颜色 | >>Finish Logging / 灰色 | **不变** | 同上 |
| Archive compact 题面字号 | 18pt | **16pt**（width ≤ 300 时） | 同上 |
| 选项：用力程度 | Lot of effort / … | **A lot of effort / …** | `questionnaire_spec.dart` |
| 选项：质地题面 | What was the Consistency? | **What was the consistency?** | 同上 |
| 选项：漂浮 | Floating on the water | **Floating in the water** | 同上 |
| 选项：久蹲/久留 q9 & q257 | stay here / sit for a long time | **Needed to strain or stay for a long time**（两处统一） | 同上 |

### 4. Archive

| 位置 | 改前 | 改后 | 文件 |
|------|------|------|------|
| 删除确认 | Delete Record? | **Delete Log?** | `record_delete_ui.dart` |
| 日历空日 snackbar | No records | **No logs** | `new_archive_screen.dart` |
| Logs 页空状态 | No Logs Yet | **No logs yet.** | `logs_card.dart` |
| Log now 按钮 | Log now | **Log Now** | `log_now_button.dart` |
| Logs 列表行 | Wrap 单行混排 Log 1 + meta | **两行**：Log N 标题行 + meta 行 | `logs_card.dart` |
| Log Calendar 标题字距 | letterSpacing: 5 | **1.2** | `new_archive_screen.dart` |
| 日历日期数字字距 | letterSpacing: 5 | **0** | 同上 |
| 卡片尺寸 | 固定 326×620 | **maxWidth 326 + 高度比例**（620/852 × 屏高） | `logs_card.dart` / `new_archive_screen.dart` |
| 图表空数据 | No questionnaire data in this period. | **No log data in this period.** | `chart_analysis_card.dart` |
| 图表有限数据提示 | days with records | **days with logs** | 同上 |
| 热力格 drill-down | Record 1: / X record(s) | **Log 1: / X log(s)** | 同上 |
| 状态格 drill-down | Overall Status1: | **Overall Status 1:**（序号前加空格） | 同上 |
| Chart info 全文 | record / questionnaire / External/Lifestyle / Dry/Hard | **log / log details / External / Dry / Hard** + 缩写说明行 | `chart_info_tooltip.dart` |
| 缩写说明（Radar/Stacked/Line） | 无 | **Phys = Physiological, Psych = Psychological, Ext = External** | 同上 |

### 5. Private Space

| 位置 | 改前 | 改后 | 文件 |
|------|------|------|------|
| 历史页标题 | RECORDS | **Entries** | `private_space_screen.dart` |
| 多选标题 | N SELECTED | **N Selected** | 同上 |
| 删除确认（单/复） | Delete Record? / Delete Records? | **Delete Entry? / Delete Entries?** | `private_space_ui.dart` |
| 重命名语音 | Rename voice / Optional title | **Rename Voice / Optional Title** | `private_space_screen.dart` |
| 图片菜单 | Copy image / Cut image / Delete image | **Copy Image / Cut Image / Delete Image** | 同上 |
| 分享 snackbar | Copied. You can share it now. | **Copied to clipboard.** | 同上 |
| 自动标题 fallback | Voice note / Photo note | **Voice Note / Photo Note** | 同上 |
| 底栏多选 | Mark / All | **Category**（folder 图标）/ **Select All** | 同上 |
| 权限标签 | Photo library | **Photos** | `private_permission_helper.dart` |
| 权限弹窗标题 | Photos blocked | **Photos Access Blocked** | `private_space_ui.dart` |
| 记事本日期 | yyyy / MM / dd | **MMM d, yyyy**（如 Jun 18, 2026） | `private_space_notepad.dart` / `private_space_history.dart` |
| 记事本高度 | 固定 474px | **屏高 × 0.56** | `private_space_notepad.dart` |

### 6. 基础设施

| 位置 | 改动 | 文件 |
|------|------|------|
| AppGlassDialog.alert | 新增可选 `message`，title 下渲染灰色正文 | `app_glass_dialog.dart` |
| AppGlassDialog.single | 新增可选 `message`，Maybe Later 两段式 | 同上 |
| 内部函数名 | **未重命名**（showRecordDeleteConfirmDialog 等保持） | — |
| Home Flow with me | **未改** | — |
| Archive 结构标题（Past Month Activity 等） | **未改** | — |

### 7. 自动化测试已同步

| 测试文件 | 断言更新 |
|----------|----------|
| `test/record_delete_ui_test.dart` | Delete Log? |
| `test/private_space_delete_dialog_test.dart` | Delete Entry? / Delete Entries? |
| `test/private_permission_helper_test.dart` | Photos |
| 全量 | `flutter test` → **147/147 通过** |

---

## 手动测试清单（供你逐项勾选）

> 建议设备：至少一台 **小屏**（iPhone SE 类）+ 一台常规屏；可选开启 **系统大字号（Dynamic Type）** 复测 Session Summary。

### A. Timer 全流程

- [√] **A1** 首页进入 Timer，计时器显示为 `MM:SS`（ASCII 冒号，非全角）
- [√] **A2** Idle → Start → 计时中按 **Stop** → 弹框标题为 **Stop Timer?**，Cancel / Stop 正常
- [√] **A3** 计时中按系统返回 → **Leave Timer?** / Cancel / Leave 正常；Leave 后回 Home 且本次不写 log
- [√] **A4** Stop 完成进入 **Session Summary**：
  - [√] 暖心句正常显示（内容本身未改）
  - [√] **Session Summary:** 标题为黑色
  - [√] 统计四项两列对齐：Duration / Today's Log / Time since last log（**hr**）/ Total logs this week
  - [√] 说明文默认一行 + **▼**；点击展开两行 + **▲**；再点收回
  - [√] **Log with me** 可点；**Maybe Later** 为 TextButton 样式可点
- [√] **A5** 点 **Log with me** → 问卷题面**无 Q1/Q2 前缀**；滚动到底最后一题不被 Finish 完全遮挡
- [√] **A6** 问卷多选未选点 **Next** → **Selection Required** + Please select an option.（约 2s 自动消失）
- [√] **A7** 问卷中系统返回 → You haven't finished logging. / Leave anyway?；Leave 回 Summary
- [√] **A8** 点 **>>Finish Logging** → **Finish Logging?** → Finish 后回 Home
- [√] **A9** Summary 点 **Maybe Later** → 两段式弹框 + **Back to Home** → 回 Home
- [√] **A10** Summary 系统返回 ≡ Maybe Later 弹框（同上）

### B. Session Summary 排版（小屏 / 大字号）

- [√] **B1** 小屏：暖心句 + 统计 + 折叠说明 + 双 CTA **无重叠、无裁切**
- [v] **B2** 系统大字号：同上，底部 CTA 仍在 SafeArea 内可点
- [√] **B3** 长暖心句（多行）时，中间统计区仍可读、不与说明文重叠

### C. Archive — Log Calendar（第 1 页）

- [√] **C1** 标题 **Log Calendar** 字距正常（不过宽）
- [√] **C2** 日历日期数字字距正常、可读
- [√] **C3** 点击**无 log 的日期** → snackbar 含 **No logs**
- [√] **C4** 点击有 log 的日期 → 底部 sheet 列表正常；**Log Now** 按钮为 Title Case
- [√] **C5** 卡片高度随屏幕比例变化，无异常留白或溢出

### D. Archive — Chart Analysis（第 2 页）

- [√] **D1** 无数据周期 → **No log data in this period.**
- [×] **D2** 少于 3 天有数据 → 提示含 **days with logs**
- [√] **D3** 各图表 ⓘ 打开 info：文案用 **log / log details**，状态为 **Dry / Hard**（有空格），第三维为 **External**（非 External/Lifestyle）
- [√] **D4** Radar / Stacked Bar / Line 的 info 底部有缩写说明：**Phys = …, Psych = …, Ext = …**
- [×] **D5** 热力格 drill-down：**Log 1:**、**X log(s)**；**Overall Status 1:** 序号前有空格

### E. Archive — Logs（第 3 页）

- [√] **E1** 无 log 日 → 居中 **No logs yet.**（非固定高空白条）
- [√] **E2** 有 log 日 → **Log 1** 单独一行，时间 meta 在下一行
- [√] **E3** 长按删除 → **Delete Log?** / Cancel / Delete
- [×] **E4** 点 **Log Now** 打开问卷浮层（compact 16pt）；Finish sticky footer 不挡最后一题
- [] **E5** 已填问卷只读区顶部有 **Log Details**，题面无 Q 编号

### F. Private Space

- [√] **F1** 历史页标题 **Entries**（非 RECORDS 全大写）
- [√] **F2** 空状态：No entries yet. Tap the + button to start.
- [√] **F3** 长按多选 → 标题 **N Selected**；底栏 **Category**（文件夹图标）/ **Select All** / Share / Delete
- [√] **F4** 删除单条 → **Delete Entry?**；多选删除 → **Delete Entries?**
- [×] **F5** 分享后 snackbar：**Copied to clipboard.**
- [√] **F6** 语音重命名弹框：**Rename Voice** / **Optional Title**
- [√] **F7** 图片长按菜单：**Copy Image / Cut Image / Delete Image**
- [√] **F8** 记事本日期格式 **MMM d, yyyy**；记事本高度随屏高比例变化
- [√] **F9** 历史卡片日期同为 **MMM d, yyyy**
- [×] **F10**（可选）拒绝相册权限 → **Photos Access Blocked** + Open Settings

### G. 回归 / 未改项确认

- [√] **G1** Home **Flow with me** 文案未变
- [√] **G2** Archive **Past Month Activity** 等结构标题未变
- [√] **G3** >>Finish Logging 仍为灰色，前缀 **>>** 保留
- [√] **G4** 问卷逻辑未变：分支题、Finish 出现条件、提交后图表仍正常更新

---

## 测试记录（你可填）

| 日期 | 设备/系统 | 测试人 | 通过项 | 问题摘要 |
|------|-----------|--------|--------|----------|
|      |           |        |        |        |

