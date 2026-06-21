# Chart Info Tooltips Implementation Plan

**Overall Progress:** `100%`

## TLDR

为 Log Calendar 和 Chart Analysis 中的每个图表标题旁添加 ⓘ 按钮，点击后弹出玻璃面板 overlay 展示数据规则和健康科普说明。文本内容已定稿于 `.cursor/docs/CHART-INFO-TOOLTIPS.md`，chart analysis 顶级标题的文本内容待后续补充。

## Critical Decisions

- **架构：复用 overlay widget** — 创建一个通用的 `_ChartInfoOverlay` 私有 widget，接收结构化文本数据，避免每个图表重复编写面板逻辑
- **overlay 实现方式：OverlayEntry** — 使用 Flutter 的 `Overlay` 机制（非 showDialog），使其浮于图表上方，点击外部或再次点击 ⓘ 关闭
- **文本数据结构** — 用简单的 data class 存储 Part 列表，每个 Part 包含一级标题 + 若干段落（段落中标记二级标题与正文），保持与 md 文档一致
- **执行顺序** — 先建通用组件 → 接入 chart_analysis_card.dart（含 5 个 ⓘ）→ 接入 new_archive_screen.dart（Log Calendar 1 个 ⓘ）→ 最后补充 chart analysis 顶级标题

## Architecture

```
_ChartInfoButton (ⓘ 按钮 widget)
  ├── onTap → 管理 OverlayEntry 的插入/移除
  └── _ChartInfoPanel (玻璃面板 widget)
        ├── 玻璃样式：radius 16, blur 25, white 20%, border white24 0.6
        ├── padding: EdgeInsets.fromLTRB(14, 14, 14, 16)
        └── 文本布局：ChartInfoContent data → RichText widgets
```

**文本数据模型：**
```dart
class ChartInfoContent {
  final List<ChartInfoPart> parts;
}

class ChartInfoPart {
  final String title;           // 一级标题
  final List<ChartInfoSpan> body; // 正文段落（含二级标题标记）
}

class ChartInfoSpan {
  final String text;
  final bool isSubHeading; // true = 二级标题样式
}
```

## Tasks

- [x] 🟩 **Step 1: 创建通用 info tooltip 组件**
  - [x] 🟩 在独立文件中定义 `ChartInfoContent` / `ChartInfoPart` / `ChartInfoSpan` 数据类
  - [x] 🟩 实现 `ChartInfoButton` widget：ⓘ 文字按钮，管理 OverlayEntry 生命周期
  - [x] 🟩 实现 `_ChartInfoPanel` widget：玻璃面板 + 文本渲染逻辑
  - [x] 🟩 实现点击外部关闭（点击遮罩）与再次点击 ⓘ 关闭

- [x] 🟩 **Step 2: 定义所有图表的文本内容常量**
  - [x] 🟩 根据 `CHART-INFO-TOOLTIPS.md` 定义 6 个 `ChartInfoContent` 常量：logCalendar / overallStatusDistribution / statusTrends / radarView / stackedBarView / lineView
  - [x] 🟩 chart analysis 顶级标题使用占位说明常量，后续可直接替换

- [x] 🟩 **Step 3: 接入 Chart Analysis 卡片（5+1 个 ⓘ）**
  - [x] 🟩 "Chart Analysis" 标题行改为 Row，右侧加 ⓘ（右距约 7px）
  - [x] 🟩 "Overall Status Distribution" 标题行改为统一标题行组件 + ⓘ
  - [x] 🟩 "Status Trends" 标题行改为统一标题行组件 + ⓘ
  - [x] 🟩 "Radar View" 标题行改为统一标题行组件 + ⓘ
  - [x] 🟩 "Stacked Bar View" / "Line View" 动态标题行改为统一标题行组件 + ⓘ
  - [x] 🟩 确保 ⓘ 字号与同行标题一致（Chart Analysis=25, 其余=16/15）

- [x] 🟩 **Step 4: 接入 Log Calendar 卡片（1 个 ⓘ）**
  - [x] 🟩 `new_archive_screen.dart` 中 "Log Calendar" 标题改为 Row 布局并接入 ⓘ
  - [x] 🟩 ⓘ 字号=25（与 Log Calendar 标题一致）

- [x] 🟩 **Step 5: 验证与调整**
  - [x] 🟩 overlay 定位添加边界约束（屏幕留白保护）
  - [x] 🟩 多个 ⓘ 互斥（打开新的自动关闭旧的）
  - [x] 🟩 长文本面板支持滚动（`SingleChildScrollView`）
  - [x] 🟩 linter 检查通过（无报错）

## Style Reference

| 元素 | 字号 | 字重 | 颜色 | 字体 |
|------|------|------|------|------|
| ⓘ 按钮 | 与同行标题一致 | w274 | white alpha 0.5 | SF Pro |
| 一级标题 | 13 | w590 | 0xFF0088FF | SF Pro |
| 二级标题 | 11 | w500 | 0xFF0088FF | SF Pro |
| 正文 | 11 | w300 | white | SF Pro |

## File Impact

| 文件 | 变更类型 |
|------|---------|
| `lib/features/archive/chart_analysis_card.dart` | 新增组件 + 修改 5 处标题行 |
| `lib/features/archive/new_archive_screen.dart` | 修改 1 处标题行 |
| `.cursor/docs/CHART-INFO-TOOLTIPS.md` | 仅参考，不修改 |
