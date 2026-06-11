# ARCH-001 全库架构梳理与分层重构

**Overall Progress:** `90%`

> **与 PLAN-CHART-001 的关系：** ARCH P0/P1/P2/P4 已完成（2026-06-12）。**CHART-001 已解除阻塞**，见 [PLAN-CHART-001.md](./PLAN-CHART-001.md)。Chart 统计与 `chart_analysis_logic.dart` 由 CHART-001 负责，不重复 ARCH A1/A3/A4。

---

## TLDR

当前 Pupu（54 个 `lib/` 文件、~15.5k 行）处于 **「目录结构像 feature-first，实际写法像 MVP 堆叠」** 阶段：Riverpod 只接了一半、3 个 God Screen 占全库 ~40% 行数、6 个 Provider/Service 从未被引用。目标是用 **四层模型（UI → Feature Logic → Domain → Data）** 统一约束，**不引入 Repository/UseCase 过度抽象**，通过 **死代码清理 → Provider 接线 → God Screen 拆分 → 共享组件提取** 四阶段，把「改规则必动 UI、改一处漏一处」的风险压到最低。

---

## Critical Decisions

| # | 决策 | 理由 |
|---|------|------|
| 1 | **四层模型，禁止 UI 层写业务规则** | Chart 窗口/Distribution/取整、Session 统计、问卷分支等必须在纯 Dart 层 |
| 2 | **不建 Repository / UseCase 层** | 54 文件规模；`LocalStorage` + Riverpod Provider 足够；YAGNI |
| 3 | **Provider 模式统一：`XWithRefreshProvider` + `bumpXRefresh`** | Archive 已验证；Private Space 必须对齐，消除 UI 直连 Hive |
| 4 | **删死代码优先于接线** | `timer_provider`、`heatmap_data_provider`、`entries*` 零引用；先删/合并再写新逻辑 |
| 5 | **God Screen 按「抽 Logic → 抽 Widget → 留 Screen 编排」拆分** | 不 big-bang 重写；每 PR <500 行 diff |
| 6 | **CustomPainter 无业务规则时可留 UI 文件** | Painter 纯渲染；规则在 Logic 层算好 DTO 再传入 |
| 7 | **内部精确分数，UI 展示 largest remainder** | 与 CHART-001 Decision #4 一致，推广为全库百分比展示原则 |
| 8 | **`SupabaseService` 本期不接线 UI** | 全 lib 零 import；标注 TODO，等功能 ticket 再动 |
| 9 | **pubspec 僵尸依赖单独 PR** | `fl_chart` 等零引用；删依赖便于 CI/analyze 干净 |
| 10 | **测试跟 Logic 走，不跟 Widget 走** | 新/迁业务规则必须附带 `*_test.dart` |

---

## 现状快照（Explore 2026-06-11）

| 指标 | 数值 | 说明 |
|------|------|------|
| 总 Dart 文件 | 54 | `lib/` |
| 总代码行 | ~15,500 | 含注释 |
| God 文件（>500 行） | 7 | 见下表 |
| Riverpod 实际接线 | ~40% | 仅 records + audio 活跃 |
| UI 直连 `LocalStorage` | 2 处 | `private_space_screen`、`timer_screen`（+ `session_record_utils`） |
| 死 Provider | 5+ | 见 Phase 0 |
| 测试文件 | 9 | 覆盖 PS + scoring；Chart/Timer/Archive UI 无测 |
| TECH-STACK 漂移 | 有 | `galaxy/`、`health_provider` 未实现；命名 `private_space/` |

### God 文件排行

| 文件 | 行数 | 内含 | 主要风险 |
|------|------|------|----------|
| `chart_analysis_card.dart` | ~2800 | 6 Painter + 窗口/计数/取整业务 | **CHART-001 覆盖** |
| `private_space_screen.dart` | ~2175 | CRUD + 15 嵌套 Widget + 动画 + 分类 | 改 CRUD 不刷新 Provider；难测 |
| `private_note_document_controller.dart` | ~1448 | 自定义编辑器 | 复杂度合理，已有测试；**不拆** |
| `timer_screen.dart` | ~1239 | 计时 + 问卷 + 音频 + Dialog + Painter | 状态全在 State；`timer_provider` 死代码 |
| `status_scoring.dart` | ~822 | Domain 层 | **良好范例**，Chart 应下沉到此模式 |
| `private_note_editor.dart` | ~741 | 编辑器 UI | 可接受 |
| `new_archive_screen.dart` | ~647 | 日历 + PageView | 可接受 |

---

## 架构问题清单

### P0 — 业务规则与 UI 耦合（高 bug 率）

| # | 问题 | 位置 | 风险 | 修改方案 |
|---|------|------|------|----------|
| A1 | 统计/窗口/取整堆在 Widget | `chart_analysis_card.dart` | 改规则必动 UI；无法单测 | **CHART-001**：`chart_analysis_logic.dart` |
| A2 | Session 统计在 Screen 内联 | `timer_screen.dart` L994 直连 `LocalStorage` | 与 Provider 数据不同步 | 迁到 `session_record_utils`（已有），经 `recordsWithRefreshProvider` 取数 |
| A3 | 日期归一化不一致 | Chart 内联 vs `logs_day_utils.normalizeDay` | 日边界错位 | CHART-001 Step 0 统一 |
| A4 | 百分比 `toStringAsFixed(0)` 独立四舍五入 | Chart Distribution / 热力格 | 整数和 ≠ 100% | `largest remainder` helper（CHART-001 + 推广原则 #7） |

### P1 — 状态与数据层分裂（中 bug 率）

| # | 问题 | 位置 | 修改方案 |
|---|------|------|----------|
| B1 | **死 Provider 链** | 见 Phase 0 表 | 删除或接线，不可并存 |
| B2 | Private Space 绕过 Provider | `private_space_screen.dart` 6 处 `LocalStorage.*` | 接入 `entriesWithRefreshProvider` + `bumpEntriesRefresh` |
| B3 | Timer 状态双轨 | `timer_provider.dart`（零引用）vs `timer_screen` 本地 `_elapsed` | **删 `timer_provider.dart`**（PLAN-TIMER-004 已决策不接） |
| B4 | `recordsProvider` 与 `recordsWithRefreshProvider` 重复 | `records_provider.dart` | 保留 `*WithRefresh` 为唯一读入口；`recordsProvider` 改内部实现或删 |
| B5 | 刷新后 Private Space 不更新 | 无 `bumpEntriesRefresh` 调用方 | Phase 1 接线时一并添加 |

### P2 — God Screen / 重复代码（可维护性）

| # | 问题 | 位置 | 修改方案 |
|---|------|------|----------|
| C1 | PS Screen 上帝对象 | `private_space_screen.dart` | 抽 `private_space_history.dart`（列表+swipe）、`private_space_notepad.dart`（编辑态）、`private_space_categories.dart`；Screen 只做 stage 编排 |
| C2 | Timer Screen 上帝对象 | `timer_screen.dart` | 抽 `timer_session_summary.dart`、`timer_questionnaire_host.dart`；Dialog 已有独立 class，移到 `widgets/` |
| C3 | 图片组件三份 | `private_note_blocks` / `private_note_editor` / `private_space_block_widgets` | 合并为 `core/widgets/note_image.dart` |
| C4 | 星空 Painter 重复 | `starfield_painter.dart`（孤儿）+ PS 内 `_StarFieldPainter` | 统一 `core/widgets/starfield_background.dart`；Home 可选接入 |
| C5 | 玻璃面板样式分散 | `liquid_glass_background`、`timer_blue_glass_panel`、Chart/Logs 内联 `BackdropFilter` | 提取 `GlassPanel` 参数化 widget（sigma、radius、opacity） |
| C6 | `QuestionnaireFlow` 多处 `new` | timer / logs / day_records_sheet | **可接受**（无共享状态）；不抽 singleton |

### P3 — 边界债务（低优先级）

| # | 问题 | 修改方案 |
|---|------|----------|
| D1 | Service 层含 UI | `private_permission_helper.dart` 内 Dialog → 返回 enum/intent，Dialog 放 feature widget |
| D2 | ~~`ThemeMode` 命名冲突~~ | **已取消**（`app_provider.dart` 整文件删除） |
| D3 | pubspec 僵尸依赖 | `fl_chart`（零 import）；`pdf`/`csv`/`excel`/`share_plus` 零 import → 删或移 dev_dependencies |
| D4 | `SupabaseService` 孤立 | 保留文件 + `// TODO: ARCH-004`；不在本 Plan 接线 |
| D5 | `constants.dart` 遗留 MVP 文案 | 布里斯托/8 色/GAD-2 常量可能已废弃 → 审计后删 |
| D6 | TECH-STACK.md 过时 | Phase 4 同步：`private_space/` 替代 `galaxy/`，删 `health_provider` 规划 |
| D7 | 无集中路由 | MVP 可接受；`go_router` 留 UI-001 后 |

---

## Target Architecture

### 分层原则

```
┌─────────────────────────────────────────────────────────┐
│  L4 UI — Widget / CustomPainter（纯渲染 + 本地 UI 状态）   │
│  Screen 只做：布局、动画、导航、调用 Logic、watch Provider │
│  禁止：统计规则、窗口计算、Hive CRUD、百分比取整           │
└──────────────────────────┬──────────────────────────────┘
                           │ 调用
┌──────────────────────────▼──────────────────────────────┐
│  L3 Feature Logic — 纯 Dart，可单测                       │
│  chart_analysis_logic / session_record_utils /             │
│  logs_day_utils / questionnaire_flow                     │
└──────────────────────────┬──────────────────────────────┘
                           │ 调用
┌──────────────────────────▼──────────────────────────────┐
│  L2 Domain — 单条记录语义                                 │
│  status_scoring / questionnaire_codec / questionnaire_spec│
└──────────────────────────┬──────────────────────────────┘
                           │ 调用
┌──────────────────────────▼──────────────────────────────┐
│  L1 Data — Models + LocalStorage +（未来）SupabaseService │
│  BowelRecord / PrivateEntry / Hive CRUD                  │
└─────────────────────────────────────────────────────────┘
```

### Provider 层（横切 L1↔UI）

```
providers/
├── records_provider.dart       # 唯一读入口：recordsWithRefreshProvider + bumpRecordsRefresh
├── entries_provider.dart       # 唯一读入口：entriesWithRefreshProvider + bumpEntriesRefresh（P1）
├── audio_provider.dart         # Timer 音频
├── home_audio_provider.dart    # Home 音频
└── （P0 删除）app_provider / timer_provider / heatmap_data_provider
```

**写操作约定：**

```dart
// 标准模式 — Archive 已用，PS 必须对齐
await LocalStorage.saveX(...);  // 或在 Provider Notifier 内封装
bumpXRefresh(ref);              // UI 通过 *WithRefreshProvider 自动重建
```

### 目标目录结构（增量，非 big-bang 迁移）

```
lib/
├── core/
│   ├── constants.dart
│   ├── theme.dart
│   ├── animations.dart
│   └── widgets/                    # 跨 feature 共享
│       ├── glass_panel.dart        # 统一 BackdropFilter
│       ├── starfield_background.dart
│       └── note_image.dart
├── models/
├── services/
│   ├── local_storage.dart
│   ├── supabase_service.dart       # TODO，暂不接线
│   └── private_media_storage.dart
├── providers/                      # 见上表，精简后 4–5 文件
├── features/
│   ├── home/
│   ├── timer/
│   │   ├── timer_screen.dart       # 目标 <400 行（编排）
│   │   ├── session_record_utils.dart
│   │   └── widgets/
│   ├── archive/
│   │   ├── chart_analysis_logic.dart   # CHART-001 新建
│   │   ├── chart_analysis_card.dart    # 目标 <800 行（UI+Painter）
│   │   ├── status_scoring.dart
│   │   └── ...
│   ├── private_space/
│   │   ├── private_space_screen.dart   # 目标 <400 行（stage 编排）
│   │   ├── private_space_history.dart  # Phase 2 新建
│   │   ├── private_space_notepad.dart  # Phase 2 新建
│   │   └── ...（已有 controller/editor/blocks 保持）
│   └── questionnaire/
└── app.dart / main.dart
```

### 文件体量硬约束（防回归）

| 类型 | 行数上限 | 超出时动作 |
|------|----------|------------|
| Screen | 500 | 抽 Widget 子文件 |
| Logic（纯 Dart） | 400 | 按职责拆文件（如 chart 窗口 vs distribution） |
| Controller（复杂域） | 1500 | 仅 PS 编辑器例外；其他必须 justification |
| Provider 文件 | 80 | 一 domain 一文件 |
| CustomPainter 集合 | 留 UI 文件或 `*_painters.dart` | 无业务规则 |

---

## Phased Execution

### Phase 0 — 死代码清理（零行为变更） `ARCH-001-P0`

| Step | 动作 | 文件 | 验证 |
|------|------|------|------|
| 0.1 | 删 `timer_provider.dart` | providers/ | `flutter analyze` + Timer 手动冒烟 |
| 0.2 | 删 `heatmap_data_provider.dart` | providers/ | 无引用 |
| 0.3 | 删 `recordsProvider` 或标记 `@Deprecated` 仅内部用 | records_provider.dart | Archive 只用 `*WithRefresh` |
| 0.4 | 删 `recordsInRangeProvider`（零引用） | records_provider.dart | analyze 通过 |
| 0.5 | 删 `isPlayingProvider`（零引用，TIMER-003 已 skip） | audio_provider.dart | analyze 通过 |
| 0.6 | **删除** `app_provider.dart` 整文件 | providers/ | lib 零 import；P0.9 重命名取消 |
| 0.7 | 删 pubspec 僵尸依赖 | pubspec.yaml | `fl_chart`、`pdf`、`csv`、`excel`、`share_plus`、**`device_preview`（待确认 #R3）** |
| 0.8 | 删孤儿 `starfield_painter.dart` | home/ | R5 确认 |
| ~~0.9~~ | ~~重命名 ThemeMode~~ | — | **已取消**（app_provider 整文件删除） |

**执行记录（2026-06-11）：**
- 已删除：`timer_provider.dart`、`heatmap_data_provider.dart`、`app_provider.dart`、`starfield_painter.dart`
- 已精简：`records_provider.dart`（移除 `recordsProvider` / `recordsInRangeProvider`）、`entries_provider.dart`（移除 `entriesProvider`）、`audio_provider.dart`（移除 `isPlayingProvider`）
- 已清理依赖：`pubspec.yaml` 移除 `fl_chart`、`pdf`、`csv`、`excel`、`share_plus`、`device_preview`
- 已同步文档：`TECH-STACK.md` 移除 `app_provider` / `timer_provider` / `health_provider` 规划条目

**Rollback：** 单步 revert；无 DB migration。

---

### Phase 1 — Provider 一致性 `ARCH-001-P1`

| Step | 动作 | 文件 |
|------|------|------|
| 1.1 | 新增 `bumpEntriesRefresh(ref)` | entries_provider.dart |
| 1.2 | PS Screen 读 `entriesWithRefreshProvider` | private_space_screen.dart |
| 1.3 | PS 所有写操作后 `bumpEntriesRefresh` | 同上 |
| 1.4 | Timer `computeSummaryStats` 改从 `recordsWithRefreshProvider` 取数 | timer_screen.dart |
| 1.5 | `session_record_utils` 写操作由调用方 bump（已有 bumpRecordsRefresh） | 确认无遗漏 |

**测试：** 可选 widget test — PS 保存条目后列表刷新。

**执行记录（2026-06-11）：**
- `entries_provider.dart` 新增 `bumpEntriesRefresh(ref)`。
- `private_space_screen.dart` 从 `StatefulWidget` 迁移到 `ConsumerStatefulWidget`，读取 `entriesWithRefreshProvider` 作为唯一条目读入口。
- Private Space 的写操作（save/pin/delete/batch delete/apply category）保留 `LocalStorage` 直写，但统一追加 `bumpEntriesRefresh(ref)` 触发 UI 数据刷新。
- `timer_screen.dart` 的 summary 统计数据改为 `await ref.read(recordsWithRefreshProvider.future)`，移除 `LocalStorage.getAllRecords()` 直读。

---

### Phase 2 — God Screen 拆分 `ARCH-001-P2`

> **与 CHART-001 并行时注意：** Chart 拆分由 CHART-001 负责；本 Phase 只做 PS + Timer。

#### 2A — Private Space（建议优先：改动面独立）

| Step | 抽出文件 | 从 screen 迁出 |
|------|----------|----------------|
| 2A.1 | `private_space_history.dart` | `_HistoryEntryCard`, `_SwipeRevealCard`, history 列表逻辑 |
| 2A.2 | `private_space_notepad.dart` | notepad stage UI + mark board |
| 2A.3 | `private_space_categories.dart` | 分类 CRUD UI |
| 2A.4 | `private_space_background.dart` | `_StarFieldPainter`, `_ParticleOverlay`, `_PrivateSpaceBackground` |

Screen 保留：`_Stage` 状态机、`_loadEntries` 委托 Provider、导航。

**执行记录（2026-06-12）：**
- ✅ **2A.1 已完成**：新建 `private_space_history.dart`，迁出 `_HistoryEntryCard` / `_SwipeRevealCard` 相关历史卡片与滑动动作逻辑；`private_space_screen.dart` 改为调用 `PrivateSpaceHistoryEntryCard`。
- ✅ **2A.4 已完成**：新建 `private_space_background.dart`，迁出 `_PrivateSpaceBackground` / `_ParticleOverlay` / `_StarFieldPainter` 与粒子绘制逻辑；`private_space_screen.dart` 改为调用 `PrivateSpaceBackground` 和 `PrivateSpaceParticleOverlay`。
- ✅ **2A.2 已完成**：新建 `private_space_notepad.dart`，迁出 notepad 主体 UI（纸面容器、编辑器承载、工具按钮与背景 painter）；`private_space_screen.dart` 改为调用 `PrivateSpaceNotepadStage`。
- ✅ **2A.3 已完成**：新建 `private_space_categories.dart`，迁出分类选择浮层 UI（列表、添加、删除、应用分类）；`private_space_screen.dart` 改为调用 `PrivateSpaceCategoriesOverlay`。
- ✅ 回归验证：`flutter test` 全量通过（92/92）。

#### 2B — Timer

| Step | 抽出文件 | 从 screen 迁出 |
|------|----------|----------------|
| 2B.1 | `widgets/timer_session_summary.dart` | Session Summary 区块 |
| 2B.2 | `widgets/timer_questionnaire_host.dart` | 问卷切换 + `AnimatedSwitcher` |
| 2B.3 | `widgets/timer_dialogs.dart` | `_MaybeLaterDialog`, `_StopConfirmDialog` |
| 2B.4 | `widgets/timer_wave_painter.dart` | `_WavePainter` |

**执行记录（2026-06-12）：**
- ✅ **2B.1 已完成**：新建 `widgets/timer_session_summary.dart`，迁出 Session Summary 视图（含文案布局、Log with me CTA、Maybe Later 入口、问卷面板切换）。
- ✅ **2B.2 已完成**：新建 `widgets/timer_questionnaire_host.dart`，将问卷切换 `AnimatedSwitcher` + `QuestionnaireInteractivePanel` 宿主从 `timer_session_summary.dart` 独立迁出。
- ✅ **2B.3 已完成**：新建 `widgets/timer_dialogs.dart`，迁出 `_MaybeLaterDialog`、`_StopConfirmDialog` 为 `TimerMaybeLaterDialog`、`TimerStopConfirmDialog`。
- ✅ **2B.4 已完成**：新建 `widgets/timer_wave_painter.dart`，迁出 `_WavePainter` 为 `TimerWavePainter`。
- ✅ 回归验证：`flutter test` 全量通过（92/92），且本次改动文件 `ReadLints` 无新增告警。

---

### Phase 3 — 共享 Core 组件 `ARCH-001-P3`

| Step | 动作 |
|------|------|
| 3.1 | `core/widgets/glass_panel.dart` — 参数：sigma, radius, fillOpacity |
| 3.2 | `core/widgets/note_image.dart` — 合并三处图片 widget |
| 3.3 | `core/widgets/starfield_background.dart` — Home + PS 共用（可选 Home 接入） |
| 3.4 | Chart/Logs/Archive 逐步替换内联 `BackdropFilter` |

---

### Phase 4 — 文档与常量审计 `ARCH-001-P4`

| Step | 动作 |
|------|------|
| 4.1 | 更新 `TECH-STACK.md` — Provider 表、目录结构、删 health_provider |
| 4.2 | 审计 `constants.dart` — 删 MVP 遗留（布里斯托/8 色若未引用） |
| 4.3 | README 补充分层约定 + 文件体量约束 |

**阶段内提前执行（2026-06-11）：**
- Step 4.2 已先行落地：`constants.dart` 移除未引用的 `staticHealthAdvice`、`stoolColors`、`bristolTypes`、`PainLevel` 与 `StoolColorOption`。

**执行记录（2026-06-12）：**
- ✅ **4.1 已完成**：更新 `TECH-STACK.md` 的 Provider 架构与目录现状（`private_space/`、`XWithRefreshProvider + bumpXRefresh`），并同步移除依赖清单（`fl_chart` / `pdf` / `csv` / `excel` / `share_plus` / `device_preview`）。
- ✅ **4.3 已完成**：更新 `README.md` 的技术栈与架构约定，补充分层规则、文件体量软约束、P2A/P2B 拆分结果与 Supabase 当前接线状态说明。

---

## 与其他 Plan 的边界

| Plan | 本 Plan 关系 |
|------|-------------|
| **PLAN-CHART-001** | 负责 A1/A3/A4 + `chart_analysis_logic.dart`；**不重复** |
| **PLAN-TIMER-00x** | Timer 功能迭代；P2B 只做结构拆分，不改行为 |
| **PLAN-PS-00x** | PS 语义/编辑器；P1/P2A 只做数据层+Screen 拆分 |
| **PLAN-NAV-001** | 已完成；路由仍分散在 Home，D7 后续 |
| **PLAN-UI001** | 宇宙主题；P3 玻璃/星空与其对齐 |

---

## 测试策略

| 层 | 要求 |
|----|------|
| L2 Domain | 已有 `status_scoring_test`；扩展 coverage |
| L3 Logic | CHART-001 新增 `chart_analysis_logic_test`；`session_record_utils` 补测 |
| L1 Data | `LocalStorage` 集成测可选（Hive 内存 box） |
| L4 UI | 仅关键交互 widget test（PS 刷新、问卷 overlay 滚动） |

---

## Rollback 总则

- 每 Phase 独立 PR，可单独 revert
- Phase 0 无用户可见变更，风险最低，**建议最先合并**
- Phase 1 若 PS 列表异常，回退 Provider 接线、恢复直连 LocalStorage
- 无 Hive schema 变更

---

## 已确认决策（2026-06-11）

| # | 问题 | 决策 |
|---|------|------|
| 1 | Phase 顺序 | **CHART-001 搁置**；按 `P0 → P1 → P2 → P3 → P4` 执行 |
| 2 | `timer_provider` | **确认死代码**（全 lib 零 import）；**P0.1 删除** |
| 3 | Export 依赖 | **pubspec 全删**（pdf/csv/excel/share_plus/fl_chart） |
| 4 | Supabase | 见下方说明；**本 Plan 不接线** |
| 5 | `simplifiedAnimationProvider` | **无 UI，P0.6 删除** |
| 6 | PS Screen 目标 | **<400 行足够** |
| 7 | GlassPanel / sigma | 见下方说明；P3 **参数化抽组件，不改各页视觉** |
| 8 | health_provider | **删规划**；`staticHealthAdvice` 纳入 P4 常量审计 |
| R1 | `themeModeProvider` | **P0 删除** |
| R2 | MVP 遗留常量 | **P4 删除**（bristolTypes 等） |
| R3 | `device_preview` | **P0 从 pubspec 删除** |
| R5 | `starfield_painter.dart` | **P0 删除** |
| R8 | `private_permission_helper` Dialog | **单独 issue**，不纳入 ARCH |
| σ | 各页 sigma 不同 | **有意为之**；P3 抽组件时保留参数 |
| Supabase | 文件保留 | **不接线**，stub 留待未来 ticket |
| **R4** | PS 分类 `_categories` | **A 已知限制**，ARCH 不持久化 |
| **R6** | Provider 精简 | **是** — 仅 `recordsWithRefreshProvider` + `entriesWithRefreshProvider` |
| **R7** | P3 优先级 | **是，P3 可选**（P0→P1→P2 必做） |
| **R8** | permission Dialog | **单独 issue**（不进 ARCH） |
| 小问 | `app_provider.dart` | **整文件删除**（lib 零 import）；P0.9 重命名 ThemeMode **取消** |

**探索阶段：已关闭（2026-06-11）。** 无阻塞性待确认项；可启动 Phase 0 执行。

**Supabase「接线」：** 指把已写好的 `SupabaseService`（upload/download/sync）和 `main.dart` 里的 Supabase 初始化，**接到 UI 上**——例如设置页「登录 / 备份 / 恢复」按钮，并填入真实 Project URL / anon key。当前全 lib 无 UI 调用，本地 Hive 独立可用。**ARCH 不碰；文件保留作未来 ticket  stub。**

**sigma（σ）：** 玻璃模糊强度参数，用于 `ImageFilter.blur(sigmaX: σ, sigmaY: σ)`。σ 越大背景越糊（Chart/Logs 常用 50；轻面板约 8–16）。P3 只是抽 `GlassPanel(sigma: …)` 公共 widget，**各页面传入原值，视觉效果不变**。

---

## 待澄清问题

**无。** 第三轮已全部关闭（R4=A，R6/R7/小问已确认）。

### 执行默认（无需再确认）

| 项 | 默认 |
|----|------|
| Phase 顺序 | P0 → P1 → P2A(PS) → P2B(Timer) → P3(可选) → P4 |
| PR 粒度 | 每 Phase 独立 PR，便于回滚 |
| P0.9 | **取消**（`app_provider.dart` 整文件删除，无 ThemeMode 冲突） |
| R8 issue | 执行 ARCH 同时或之后新建 `.cursor/issues/PS-010-permission-dialog-layer.md`（标题可调整） |

---

## Tasks Checklist

- [x] 🟩 **Phase 0: 死代码清理**
  - [x] 🟩 P0.1–P0.8（P0.9 已取消，执行完成）
- [x] 🟩 **Phase 1: Provider 一致性**
  - [x] 🟩 P1.1–P1.5
- [x] 🟩 **Phase 2A: Private Space 拆分**
  - [x] 🟩 P2A.1–P2A.4（全部完成）
- [x] 🟩 **Phase 2B: Timer 拆分**
  - [x] 🟩 P2B.1（已完成）
  - [x] 🟩 P2B.2（已完成）
  - [x] 🟩 P2B.3（已完成）
  - [x] 🟩 P2B.4（已完成）
- [ ] 🟥 **Phase 3: 共享 Core 组件**
  - [ ] 🟥 P3.1–P3.4
- [x] 🟩 **Phase 4: 文档与常量审计**
  - [x] 🟩 P4.1（已完成）
  - [x] 🟩 P4.2（已提前完成）
  - [x] 🟩 P4.3（已完成）
