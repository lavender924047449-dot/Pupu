# ARCHIVE-001: 档案页新增第三页「Logs」

**Type:** Feature | **Priority:** Normal | **Effort:** Medium–Large

**探索状态：** ✅ 需求已闭环，可进入实现

---

## TL;DR

档案页 Page 2 新增 **Logs**：按天浏览 session；有问卷→只读展示；无问卷→「Log X」+ **Log now** → 在玻璃面板正中弹出 **284×406** 交互问卷浮层 → `>>Finish Logging` 落库并展开只读块。

---

## 已确认决策（完整）

| # | 决策 |
|---|------|
| 1 | 日导航：按天 ±1；独立 `_currentDay`；默认=全局最近有记录日 |
| 2 | Log 编号：`dateTime` 升序 |
| 3 | 内容区纵向滚动；首条 Log 标题 `left:21, top:122` |
| 4 | 有问卷：只读（题目+已选选项+蓝色高亮） |
| 5 | 无问卷（`questionnaireAnswers == null`）：Log X + **Log now**（首条 `left:21, top:162`，多条动态下移） |
| 6 | **No Logs Yet**：仅当日 **零条 BowelRecord**；正中；SF Pro white 16 w300 |
| 7 | 浮层：**284×406**，居于 **326×620 玻璃面板正中** |
| 8 | 浮层取消：点击浮层外任意位置 + 系统返回键；**不保存** |
| 9 | Finish → `saveRecord(copyWith(questionnaireAnswers))` + `bumpRecordsRefresh` |
| 10 | 浮层打开时阻塞外层 PageView 滑动 |
| 11 | **交互浮层**玻璃：timer 同款 `LiquidGlassBackground`（白透明三层，非蓝色面板） |
| 12 | **284×406 内排版**：字号/间距 **按比例缩小**适配浮层（相对 timer 基准约 0.72w × 0.64h） |
| 13 | **只读展开块**玻璃：同交互浮层，`LiquidGlassBackground`（与 timer 问卷视觉一致） |

---

## 代码库探索结论

### 集成点

| 区域 | 现状 | Logs 接入方式 |
|------|------|---------------|
| `new_archive_screen.dart` | PageView 2 页 + 2 指示器 | 加 Page 2、`_currentDay`、`_LogsCard` |
| `timer_screen.dart` (~2096行) | 问卷状态机、spec、分支、UI 全内嵌 | **必须抽取**共享模块 |
| `records_provider.dart` | `bumpRecordsRefresh` 已有 | Finish 后调用 |
| `local_storage.dart` | `saveRecord` 按 id upsert | 无需 schema 变更 |
| `status_scoring.dart` | 消费 `answers['q1']` 等 `List<int>` | 落库 key 须对齐 `q1`…`q102` |

### 问卷落库（当前缺口）

- timer `_finishQuestionnaire()` **仅 reset UI，不落库**（TIMER-004 明确问卷 merge 另开 ticket）
- ARCHIVE-001 的 Logs Finish 路径是**首个**实现 `questionnaireAnswers` 写入的场景
- 序列化建议：`Map<String, List<int>>`，key = `_QuestionId.name`（`q1`、`q52`…），value = 所选 logical index 列表

### 玻璃面板类型（已确认）

| 组件 | 实际用途 | Logs 用法 |
|------|----------|-----------|
| `LiquidGlassBackground` | timer **交互问卷**底层（白/透明三层） | ✅ 交互浮层 + 只读展开块 |
| `_TimerBlueGlassPanel` | Stop / MaybeLater **弹窗**（`#0088FF` 蓝渐变） | ❌ 本 ticket 不用 |

### 浮层 284×406 vs timer 响应式布局

- timer 问卷：`panelHeight = screenH * (636/852)`，字号/间距用 `sx()`/`sy()` 按屏宽 393 缩放
- Logs 浮层固定 284×406 → **按比例缩小**字号/间距（宽约 0.72×、高约 0.64× 相对 timer 393×636 基准）；不能照搬 timer 绝对坐标

### 抽取范围（建议新文件）

```
lib/features/timer/
  questionnaire_spec.dart      // QuestionId, QuestionSpec, nextQuestion, questionSpec
  questionnaire_controller.dart // 状态机（visible/selected/collapsed/finish 条件）
  questionnaire_interactive_panel.dart // 交互 UI（timer + Logs 浮层共用）
  questionnaire_readonly_view.dart     // Logs 只读
  questionnaire_answer_codec.dart      // Set<int> ↔ Map<String, List<int>>
```

`timer_screen.dart` 改为消费上述模块（TIMER-001 计划也提过拆分）。

### 边界行为（已从代码推断）

- 同日混合：有问卷→只读块；无问卷→Log now（Q4=A）
- 浮层取消：丢弃 `_selectedAnswers`，不 merge
- 全局无 record：`_currentDay = DateTime.now()`，显示 No Logs Yet
- 浮层外点击区域：玻璃面板内、284×406 以外的区域（应用 `Stack` + `GestureDetector` on barrier）
- 系统返回：`PopScope(canPop: false)` + 先关浮层再允许 pop

---

## UI 规格摘要

### Log now 按钮

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: ShapeDecoration(
    color: const Color(0xFF0088FF),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1000)),
  ),
  child: Text('Log now', style: TextStyle(
    color: Colors.white, fontSize: 17,
    fontFamily: 'SF Pro Rounded', fontWeight: FontWeight.w600,
  )),
)
```

### 浮层

- 尺寸：284 × 406，`Center` 于 `_LogsCard`（326×620）内
- 内容：交互问卷 + `>>Finish Logging`（同 timer 显示条件 `_shouldShowFinishButton`）
- 取消：浮层外 tap + 系统返回

### 只读块

- 仅已答题目 + 已选选项；未选不渲染
- 样式对齐 timer L784–844

---

## 相关文件

| 文件 | 改动 |
|------|------|
| `lib/features/archive/new_archive_screen.dart` | Page 3、`_LogsCard`、浮层 barrier |
| `lib/features/timer/timer_screen.dart` | 抽取问卷模块 |
| `lib/features/timer/questionnaire_*.dart` | 新建（见上） |
| `lib/providers/records_provider.dart` | Finish 后 bump |

---

## 风险

1. **Effort Medium–Large**：抽取 + 双端接入 + 首个落库路径
2. 284×406 固定尺寸 vs timer 响应式 — 需统一缩放策略
3. `timer_screen.dart` 回归面大 — 抽取时保持行为一致
4. Finish 后 `chart_analysis` / `status_scoring` 自动获益（有真实问卷数据）

---

## 测试计划

- [ ] 三页 + 3 指示器
- [ ] 按天切换 + 升序 Log 编号
- [ ] 零 session → No Logs Yet；有 session 无问卷 → Log X + Log now
- [ ] Log now → 284×406 浮层居中 → 填写 → Finish → Hive 有 `questionnaire_answers`
- [ ] 浮层外 tap / 返回键 → 关闭不落库
- [ ] 浮层开时 PageView 不滑动
- [ ] 只读块样式正确
- [ ] 长列表滚动

---

## 建议 Phase

- **Phase 1**：Logs 骨架 + 日导航 + 列表/滚动/空态/Log now
- **Phase 2**：抽取 questionnaire 共享模块 + timer 回归验证
- **Phase 3**：284×406 浮层 + 取消/PopScope + Finish 落库 + 只读展开
