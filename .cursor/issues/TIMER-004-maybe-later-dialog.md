# TIMER-004: Session 面板「Maybe Later」+ Session 落库 + Summary 真实统计

**Type:** Feature | **Priority:** Normal | **Effort:** Medium

**探索状态：** ✅ 需求已闭环，可进入实现

---

## TL;DR

1. Stop 确认后进入 session 面板 → **立即写入 Log Calendar**（`durationSeconds` 总秒数，UI 拆 min+sec；`dateTime` = Start 时刻；问卷 `null`）
2. 「Maybe Later」弹窗 + `Got it(Back to Home)` 回星空页
3. Session 面板内系统返回 ≡ Got it（保留 record）；计时前/中返回 ≡ 废弃本次计时
4. 回 Home resume 星空 BGM；Log Calendar 去掉 mock；Session Summary 接真实统计
5. **问卷落库另开 ticket**

---

## 已确认决策（完整）

| # | 决策 |
|---|------|
| 1 | 本 ticket 只做 duration 落库 + 问卷 `null`；问卷 merge **另开 ticket** |
| 2 | 新增 `durationSeconds`（总秒数）；UI 显示 `X min Y sec` |
| 3 | `dateTime` = 用户点 **Start** 的时刻 |
| 4 | 仅 session 面板内返回保留 record；计时前/中返回废弃、不写 record |
| 5 | 回 Home → `homeAudioServiceProvider.resume()`（用户曾开启音乐时） |
| 6 | 移除 `recordsWithRefreshProvider` / `recordsInRangeProvider` 的 mock 回退 |
| 7 | Session Summary 三项接真实统计（口径见下） |
| 8 | **周边界**：`Total logs this week` 以 **手机系统 locale 的一周首日** 为准（`MaterialLocalizations.firstDayOfWeekIndex` / 系统 locale） |
| 9 | **零时长**（0 min 0 sec）：仍进入 session 并写入 record；用户可在 Log Calendar **自行删除**（删除 UI 不在本 ticket，但 `LocalStorage.deleteRecord` 已存在） |

---

## Current vs Expected

| # | 当前 | 预期 |
|---|------|------|
| 1 | `Maybe Later` 无点击 | 弹窗 + `Got it(Back to Home)` |
| 2 | `_doStopTimer` 仅改 UI | 进入 session 时幂等 `saveRecord` |
| 3 | 无 `durationSeconds` | Schema 扩展 + 迁移缺省值 |
| 4 | 无 `_sessionStartedAt` | `_startTimer` 记录开始时刻 |
| 5 | 无 `PopScope` | 按 session 状态分流返回 |
| 6 | Mock 掩盖空数据 | 仅真实 records + 空态 UI |
| 7 | Summary `#x` 占位 | 真实统计 |

---

## 弹窗规格（Maybe Later）

| 元素 | 规格 |
|------|------|
| 容器 | 293×173，玻璃风格同 `_StopConfirmDialog` |
| 主文案 | `Missed it? You can always log it later in your Log Calendar or Logs.` SF Pro 16 w400 white，268×43，顶 34 居中 |
| 按钮 | `Got it(Back to Home)` SF Pro 16 w500 white，底 40 居中，宽度自适应 |
| 点外关闭 | `barrierDismissible: true`，留 session 面板 |
| Got it | 关弹窗 + pop Timer → Home + resume BGM |

---

## Schema（`BowelRecord`）

```dart
final int durationSeconds; // 总秒数；UI: inMinutes + remainder(60)
```

- JSON 字段：`duration_seconds`
- 旧记录缺省：`durationMinutes * 60`
- `durationMinutes` 可保留只读/派生，或写入时同步 `~/ 60` 兼容旧消费者

---

## Session Summary 统计口径

| 字段 | 算法 |
|------|------|
| Duration | `_lastSessionDuration` → min + sec |
| Today's Log | 本地「今日」record 数，**含本条** |
| Time since last log | 距**上一条** record 的小时数（不含本条；无历史 → `0` 或 `—`，实现时统一） |
| Total logs this week | 系统 locale 周界内 record 数，**含本条** |

---

## Relevant Files

- `lib/features/timer/timer_screen.dart`
- `lib/models/bowel_record.dart`
- `lib/services/local_storage.dart`
- `lib/providers/records_provider.dart`
- `lib/providers/home_audio_provider.dart`
- `lib/features/archive/new_archive_screen.dart`（空态）

---

## 实现分期建议

| Phase | 内容 |
|-------|------|
| **1** | Schema + `_doStopTimer` 落库 + `_sessionStartedAt` + 移除 mock |
| **2** | Session Summary 真实统计 + `recordsRefreshProvider` 刷新 |
| **3** | `PopScope` 返回分流 + Home BGM resume |
| **4** | `_MaybeLaterDialog` + `Maybe Later` 点击 |

---

## Test Plan

- [ ] Start → Stop(Yes) → session → Hive 1 条（`dateTime`=Start，`durationSeconds` 正确，问卷 null）
- [ ] 0:00 时长仍写入并可于 Calendar 删除（删除 UI 若未实现则仅验 save）
- [ ] Maybe Later 弹窗 / 点外 / Got it 回 Home + BGM resume
- [ ] Session 系统返回 ≡ Got it；计时中返回无 record
- [ ] Log Calendar 无 mock；Summary 统计正确（含 locale 周界）
- [ ] 同 session 不重复写入
