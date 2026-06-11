# TIMER-002: 音乐按钮与音频面板视觉微调

**Type:** Improvement | **Priority:** Normal | **Effort:** Small

---

## TL;DR

TIMER-001 音频功能已实现，需对音乐按钮位置/样式、面板列表排版、旋转速度做一轮视觉抛光。

---

## Current vs Expected

| # | 当前 | 预期 |
|---|------|------|
| 1 | 主按钮与 🎵 间距 `8px` | **再右移 8px** → 间距改为 `16px`（三态 Row 均适用） |
| 2 | 🎵 按钮：`#F7F7F7` 实心圆 + 蓝色 emoji | **保持 33×33 圆形**，背景样式对齐 `_actionButton` 容器（玻璃半透明，不含文字层）；🎵 改为**纯白色** |
| 3 | 标题 `Choose an audio you like:\n\n` + 顶距 `sy(26)` | 12 条列表（含 No Audio）**整体上移**；**缩小**标题与列表间距 |
| 4 | 旋转 `3s/圈` | **调慢至 `6s/圈`**（已确认） |

---

## 样式参考（对齐 Start/Resume/Stop 按钮容器）

来源：`timer_screen.dart` `_actionButton` L1474–1486

```dart
color: Colors.white.withOpacity(0.07)   // 或 withValues(alpha: 0.07)
borderRadius: BorderRadius.circular(24) // 音乐按钮改为 circular(1000) 保持正圆
shadows: BoxShadow(
  color: Color(0x33000000),
  blurRadius: 40,
  offset: Offset(0, 8),
)
```

音乐按钮尺寸**不变**：33×33。仅替换背景参数，emoji 样式：

```dart
color: Colors.white  // 原 #0088FF
```

---

## 面板排版建议（「适度」默认实现值，可热重载微调）

| 参数 | 当前 | 建议 |
|------|------|------|
| 内容区顶距 | `sy(26)` | `sy(18)` ~ `sy(20)` |
| 标题 trailing 换行 | `\n\n`（双空行） | `\n`（单空行）或去掉末尾 `\n` 改 `SizedBox(height: 4~8)` |
| 列表起始位置 | 偏下 | 视觉上标题与第一条间距约 **8–12px**（Figma 基准） |

---

## Relevant Files

- `lib/features/timer/timer_screen.dart` — `_buildActionRow` 间距 `8→16`；`_audioRotationController` duration
- `lib/features/timer/widgets/audio_picker.dart` — `TimerMusicButton` 样式；`AudioPickerLayer` 标题/列表排版

---

## Implementation Notes

- 间距改动：三处 `SizedBox(width: 8)`（idle / running / paused）→ `16`
- 可考虑从 `_actionButton` 抽共享 `ShapeDecoration` 常量，避免音乐按钮与主按钮样式再次漂移（可选，非必须）
- running 态总宽：119+22+119+16+33 = **309/393**，仍不溢出
- 旋转调慢：`_audioRotationController` `duration: Duration(seconds: 3)` → `seconds: 6`

---

## Test Plan

- [x] idle：Start 与 🎵 间距 16px
- [x] running / paused：🎵 与主按钮组间距 16px
- [x] 🎵 背景为玻璃半透明（与 Start 一致），非 `#F7F7F7` 实心
- [x] 🎵 符号为白色
- [x] 音频面板：标题与 No Audio 间距明显缩小，列表整体上移
- [x] 选中音频后旋转约 6s/圈

**验收日期：** 2026-06-06（真机通过）
