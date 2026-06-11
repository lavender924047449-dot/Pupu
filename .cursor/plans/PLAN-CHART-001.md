# CHART-001 Chart Analysis 统计修正 + 关联 Bug 修复

**Overall Progress:** `100%`

> **与 PLAN-ARCH-001 的关系：** ARCH P0/P1/P2/P4 已完成（2026-06-12）。本 Plan 承接 ARCH 问题 **A1/A3/A4**，新建 `chart_analysis_logic.dart`（L3），业务规则不进 Widget。ARCH P3（GlassPanel 抽取）**可选并行**，不阻塞 CHART。

---

## TLDR

修正 Chart Analysis 统计口径与时间窗口（session 占比、矛盾记录剔除、日历锚今天、雷达 record 加权、`includeInTrends` 接线），同步 Distribution 热力格与 **largest remainder** 展示。业务逻辑从 `chart_analysis_card.dart`（~3000 行）下沉到可单测的 `chart_analysis_logic.dart`。另修复 Log Calendar 日 sheet 只读问卷无法滚动、Timer 最后一首音乐不播放。P2 完成 Stacked Bar hasData、删 dead code、统一空态提示。**Chart 日历跳转小图已移出范围。**

---

## Critical Decisions

| # | 决策 | 理由 |
|---|------|------|
| 0 | **统计/窗口/取整进 L3 Logic，UI 只渲染 DTO** | 与 ARCH-001 四层模型一致；改规则不碰 Painter |
| 1 | **Distribution 按 session 计数** | 每条有效记录最多计 1 次 |
| 2 | **Dry+Soft 双高（`includeInTrends=false`）整条剔除** | 不进 Distribution / Trends |
| 3 | **多 primary 取 `_statusOrder` 最大者** | Unsuccessful(4)…Ideal(0) |
| 4 | **显示用 largest remainder** | 内部精确分数；整数 % 恒等于 100% |
| 5 | **热力格与 Distribution 共用 helper** | 柱状图与 status 热力弹窗口径一致 |
| 6 | **`includeInTrends` 下沉 `computeTrendBreakdown`** | 返回 null，Trends 单一入口 |
| 7 | **时间窗口锚今天** | `end = normalizeDay(now) - offset`；`maxOffset = span~/days×days`；去掉 `days×6` |
| 8 | **日期归一化统一 `logs_day_utils.normalizeDay`** | 修复 ARCH A3 日边界不一致 |
| 9 | **Issue 雷达用方案 A** | 窗口内 record 加权，非按天均权 |
| 10 | **Unsuccessful 三图差异保留** | 统计对象不同 |
| 11 | **三区块翻页 offset 独立** | 不联动 |
| 12 | **数据读入口：`recordsWithRefreshProvider`** | ARCH R6；Chart 三页统一 refresh |
| 13 | **Stacked Bar hasData** | 无数据日只保留日期标签 |
| 14 | **Chart 日历跳转小图** | **已移出本 Plan**（不做） |
| 15 | **`hasLimitedData` / 统一空态** | Distribution / Trends / Issue 共用提示组件 |

---

## 前置已完成（探索期 / 早期补丁）

| 项 | 状态 | 文件 |
|----|------|------|
| Chart Analysis 接 `recordsWithRefreshProvider` | 🟩 Done | `new_archive_screen.dart` |
| 删除 `recordsProvider` / mock 数据 | 🟩 Done | ARCH P0.3 + 历史 TIMER-004 |
| `status_scoring.dart` Domain 层 | 🟩 已有 | 扩展而非重写 |

---

## Target：`chart_analysis_logic.dart`（L3）

```
chart_analysis_logic.dart          # 新建，目标 <400 行
├── normalizeChartDay()            # 委托 logs_day_utils.normalizeDay
├── chartWindowEnd / chartWindowStart / maxChartOffsetDays
├── resolveDistributionLabel()     # session 标签（或放 status_scoring）
├── computeStatusDistribution()    # Map<StatusLabel, int> session counts
├── formatDistributionPercents()   # largest remainder → List<int> 显示 %
├── computeTrendSeries()           # 委托 status_scoring + 窗口过滤
├── computeIssueWindowRadar()      # 方案 A：跨天 record 加权
└── buildHeatmapCellsDto()         # status / generic 模式 DTO

chart_analysis_card.dart           # L4：watch records → 调 logic → Painter 渲染
status_scoring.dart                # L2：单条 record 语义（扩展 helper / includeInTrends）
```

**约束：** CustomPainter 留在 UI 文件；传入已算好的 DTO，Painter 不算业务规则。

---

## Phased Execution

### Phase 0 — Logic 层脚手架 `CHART-001-P0`

| Step | 动作 | 文件 | 验证 |
|------|------|------|------|
| 0.1 | 新建 `chart_analysis_logic.dart`，迁出 `_resolveWindow` / `_maxOffsetForDays` / 日期锚点 | logic + card | 行为暂不变，card 调 logic |
| 0.2 | 窗口 end 改为 `normalizeDay(DateTime.now())`；`maxOffset` 去掉 `days×6` | logic | 单元测试边界 |
| 0.3 | 统一用 `logs_day_utils.normalizeDay`，删除 card 内联 `_latestRecordDay` 重复语义 | logic + card | analyze 通过 |

---

### Phase 1 — 统计规则 `CHART-001-P1`

| Step | 动作 | 文件 | 验证 |
|------|------|------|------|
| 1.1 | `resolveDistributionLabel(score)` — null=跳过；`!includeInTrends` 剔除；多 primary 取 max `_statusOrder` | `status_scoring.dart` 或 logic | `status_scoring_test` |
| 1.2 | `computeTrendBreakdown` 内：`scoreRecord` 后若 `!includeInTrends` → null | `status_scoring.dart` | 矛盾 record 无 trend 点 |
| 1.3 | `computeStatusDistribution` session 计数 + largest remainder 显示 | logic + card | 整数 % 和 = 100 |
| 1.4 | `_buildHeatmapCells` status 模式聚合同 `resolveDistributionLabel`；弹窗明细仍 primary+secondary | logic + card | 与柱状图一致 |
| 1.5 | Issue 雷达方案 A：窗口级 record 加权（复用 W_i）；7d Stacked / 30d Line **仍按日** | logic + `status_scoring.dart` | logic 单测 |
| 1.6 | 新建 `test/chart_analysis_logic_test.dart` — 窗口锚点 + distribution + trend 过滤 | test/ | CI 绿 |

---

### Phase 1 — Bug 修复 `CHART-001-P1-BUG`

| Step | 动作 | 文件 | 验证 |
|------|------|------|------|
| 7.1 | Log Calendar 日 sheet 只读问卷可滚动 | `day_records_sheet.dart`、`questionnaire_overlay.dart` 或 `questionnaire_readonly_panel.dart` | 内容超 406px 可滚到底 |
| 7.2 | Timer 最后一首（index 11）点击可播放 | `audio_picker.dart`、`audio_provider.dart`、`assets/audio/` | index 1 与 11 loop 播放 |

**根因假设（执行时验证）：**
- 7.1：`QuestionnaireOverlay` 固定 284×406，内层 `SingleChildScrollView` 约束/手势未生效
- 7.2：`timerAudioAssetPath` 边界、asset 文件名不一致、或列表末项 tap 被裁剪

---

### Phase 2 — 体验补全 `CHART-001-P2`

| Step | 动作 | 说明 |
|------|------|------|
| 9.1 | Stacked Bar：`!hasData` 不画柱体，保留日期标签 | `_IssueStackedBarPainter` |
| ~~10.1~~ | ~~Chart 日历跳转小图~~ | **已删除，不做** |
| 11.1 | 删 `computeIssueBreakdownSummary`（零引用） | 含 `IssueBreakdownSummary` 类 |
| 11.2 | 统一空态 / `hasLimitedData` 提示 | Distribution / Trends / Issue Breakdown |

---

## Tasks Checklist

- [x] 🟩 **Pre: Chart 数据 refresh 接线**
  - [x] 🟩 Chart 页使用 `recordsWithRefreshProvider`（`new_archive_screen.dart`）

- [x] 🟩 **Phase 0: Logic 层脚手架**
  - [x] 🟩 Step 0.1 新建 `chart_analysis_logic.dart` 并迁窗口函数
  - [x] 🟩 Step 0.2 日历锚今天 + maxOffset 新公式
  - [x] 🟩 Step 0.3 统一 `normalizeDay`

- [x] 🟩 **Phase 1: 统计规则**
  - [x] 🟩 Step 1.1 `resolveDistributionLabel`
  - [x] 🟩 Step 1.2 `includeInTrends` → `computeTrendBreakdown`
  - [x] 🟩 Step 1.3 Distribution session 计数 + largest remainder
  - [x] 🟩 Step 1.4 热力格同步
  - [x] 🟩 Step 1.5 Issue 雷达方案 A
  - [x] 🟩 Step 1.6 `chart_analysis_logic_test.dart`（已新增并通过 `flutter test`）

- [x] 🟩 **Phase 1-BUG: 关联修复**
  - [x] 🟩 Step 7.1 日 sheet 只读问卷滚动
  - [x] 🟩 Step 7.2 Timer 末曲播放（路径兼容 + 末项点击区增强）

- [x] 🟩 **Phase 2: 体验补全**
  - [x] 🟩 Step 9.1 Stacked Bar hasData
  - [x] 🟩 Step 11.1 删 `computeIssueBreakdownSummary`
  - [x] 🟩 Step 11.2 统一空态 / `hasLimitedData` 提示

---

## 关键文件

| 文件 | 变更 |
|------|------|
| `lib/features/archive/chart_analysis_logic.dart` | **新建** — 窗口、Distribution、雷达、热力 DTO |
| `lib/features/archive/chart_analysis_card.dart` | 瘦身 — 调 logic + Painter + 空态提示 |
| `lib/features/archive/status_scoring.dart` | `computeTrendBreakdown` + distribution helper；删 dead summary |
| `lib/features/archive/logs_day_utils.dart` | 只读引用 `normalizeDay` |
| `lib/features/archive/new_archive_screen.dart` | 无变更（refresh 已完成） |
| `lib/features/archive/day_records_sheet.dart` | 只读滚动 |
| `lib/features/questionnaire/widgets/questionnaire_*.dart` | overlay 滚动约束 |
| `lib/features/timer/widgets/audio_picker.dart` | 末项 tap / padding |
| `lib/providers/audio_provider.dart` | `playTrack` |
| `test/status_scoring_test.dart` | 扩展 |
| `test/chart_analysis_logic_test.dart` | **新建** |

---

## 测试计划

| # | 场景 | 层 |
|---|------|-----|
| T1 | 3 session 混合标签 → 整数 % 和 = 100 | logic |
| T2 | Dry+Soft 矛盾 → 不进 Distribution / Trends | domain + logic |
| T3 | 窗口 end = 今天；maxOffset 不无限空翻 | logic |
| T4 | 雷达方案 A vs 旧按天均权可预期差异 | logic |
| T5 | DayRecordsSheet 只读问卷可滚到底 | 手动 / widget |
| T6 | Timer index 1 与 11 可 loop | 手动 |

**回归：** 每 Phase 跑 `flutter test`（当前基线 100/100）。

---

## 与其他 Plan 的边界

| Plan | 关系 |
|------|------|
| **PLAN-ARCH-001** | ARCH 已完成 P0/P1/P2/P4；本 Plan 实现 A1/A3/A4；不重复 Provider 清理 |
| **PLAN-ARCH-001 P3** | GlassPanel 可选并行，不改 Chart 统计 |
| **TIMER-004/005** | Session 落库/问卷已完成；本 Plan 不改 timer 写路径 |

---

## 不在范围

- Timer Session Summary 统计改动
- 删除 record UI
- Supabase 数据流
- 三区块翻页联动
- Chart 日历跳转 UI（已明确不做）

---

## Rollback

- **P0**：revert logic 提取，card 恢复内联（无数据变更）
- **P1**：revert 统计规则 + 测试；Hive 无 migration
- **P1-BUG**：逐步 revert 7.1 / 7.2
- **P2**：revert Stacked Bar / 空态 / summary 删除（独立小 diff）
- PR 建议：`CHART-001-P0` → `CHART-001-P1` → `CHART-001-P1-BUG` → `CHART-001-P2`

---

## 已确认决策（探索 2026-06-10 ~ 2026-06-12）

| # | 问题 | 决策 |
|---|------|------|
| 1 | Distribution 矛盾记录 | Dry+Soft 双高整条剔除 |
| 2 | 多 primary（非矛盾） | `_statusOrder` 最大者 |
| 3 | 百分比显示 | largest remainder |
| 4 | 热力格 | 与 Distribution 同步 |
| 5 | 窗口锚点 | 今天（日历滚动） |
| 6 | 雷达 | 方案 A |
| 7 | Stacked Bar hasData | 无数据日只保留标签 |
| 8 | 小日历跳转 | **不做** |
| 9 | Unsuccessful 三图 | 保留差异 |
| 10 | ARCH 先行 | 已完成，CHART 全部完成 |

**探索阶段：已关闭。** CHART-001 **100% 完成。**

---

## 执行默认（无需再确认）

| 项 | 默认 |
|----|------|
| Phase 顺序 | Pre → P0 → P1 → P1-BUG → P2 |
| `resolveDistributionLabel` 位置 | 优先 `status_scoring.dart`（与 `scoreRecord` 同层）；窗口/聚合放 logic |
| PR 粒度 | 每 Phase 独立 PR，单 PR diff 目标 <500 行 |
| Painter | 不迁出 `chart_analysis_card.dart` |
