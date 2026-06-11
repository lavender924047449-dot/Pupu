# TIMER-003: 计时页接入真实音频播放

**Type:** Feature | **Priority:** Normal | **Effort:** Medium

---

## TL;DR

将 TIMER-001/002 音频选择 UI 的占位播放替换为真实本地音频。文件存于 `assets/audio/`，文件名与 UI 列表文案一致；选中即播放，No Audio / 取消选中 / 进 session 即停止。

---

## Current vs Expected

| 维度 | 当前 | 预期 |
|------|------|------|
| 播放 | `_onAudioItemTap` 仅 `setState` + TODO 注释 | 选中曲目后 `audioplayers` 真实播放 |
| 资源 | 占位无真实播放 | `assets/audio/` 下 11 个 `.mp3` 已就位（与 UI 一致） |
| Provider | `audio_provider.dart` 骨架（player + isPlaying） | 扩展 play/stop/switch，供 TimerScreen 调用 |
| No Audio | UI 停转 | UI 停转 + **停止播放** |
| 进 session | 清空选中 + 停转 | 同上 + **停止播放** |
| A→B 切换 | 高亮切换、旋转不中断 | 切换曲目、**无缝切歌** |

---

## 音频文件映射（index → 文件名）

`kTimerAudioTracks`（`audio_picker.dart`）索引 1–11 对应：

| Index | UI 文案 | Asset 文件 |
|-------|---------|------------|
| 0 | No Audio | 不播放 |
| 1–11 | 同 `kTimerAudioTracks` | `assets/audio/{文案}.mp3`（**11/11 已核查存在**） |

**已确认：** 路径 `assets/audio/`、后缀 `.mp3`、单曲 loop、直接播放无 fade。

---

## 架构（PLAN-TIMER-003 精简版）

- **选中态**：父级 `_selectedAudioIndex` 保管
- **播放引擎**：`TimerAudioService` + `Provider`（非 Notifier）；`playTrack` / `stop`
- **路径映射**：`timerAudioAssetPath(index)` 在 `audio_picker.dart`
- **编排**：`TimerScreen._syncTimerAudio()` 统一 play/stop
- **生命周期**：仅计时前/计时中（`!_showSessionPanel`）；进 session 强制 `stop()`，不自动恢复
- **TimerScreen**：`ConsumerStatefulWidget`

---

## Relevant Files

- `lib/providers/audio_provider.dart` — `TimerAudioService` + `timerAudioServiceProvider`
- `lib/features/timer/timer_screen.dart` — `ConsumerStatefulWidget`、`_syncTimerAudio()`、session/dispose 停播
- `lib/features/timer/widgets/audio_picker.dart` — `kTimerAudioTracks` + `timerAudioAssetPath()`
- `pubspec.yaml` — 已注册 `assets/audio/`，无需改动
- `assets/audio/` — 11 个 `.mp3` 已就位

---

## Implementation Notes

- `AssetSource('audio/{name}.mp3')`（不含 `assets/` 前缀，真机首条验证）
- `_syncTimerAudio()` 唯一编排：`index null/0 → stop`，否则 `playTrack(index)`
- 切换曲目：`stop()` → `play()`；loop：`ReleaseMode.loop`
- 播放生命周期：仅 `!_showSessionPanel`；进 session 强制 `stop()`，不自动恢复
- 本期跳过：`isPlayingProvider`、Notifier、淡入淡出

---

## Risks

- 文件名含空格/特殊字符，Android/iOS asset 路径需验证
- `TimerScreen` 改 Consumer 涉及 `home_screen` 推送方式（通常无影响）
- 用户未放入音频文件时，需 graceful 降级（静默失败或 toast）

---

## Test Plan

- [ ] idle / running / paused：选 1–11 → 听到对应 mp3
- [ ] 单曲 loop（播完自动重复）
- [ ] 选 No Audio / 再点同条取消 → 停止
- [ ] A→B 切换 → 切歌正确，旋转不中断
- [ ] 关面板（计时阶段内）→ 音乐继续
- [ ] Stop 进 session → 立即停止，选中清空，🎵 隐藏
- [ ] 退出计时页 dispose → 停止
- [ ] session 期间无音频播放
