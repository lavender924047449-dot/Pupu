# TIMER-003 真实音频播放实施计划

**Overall Progress:** `100%`

## TLDR

将计时页音频 UI 占位接入 `audioplayers` 本地播放。3 文件、1 个薄 `TimerAudioService`、父级编排。播放**仅限计时前/计时中**（`!_showSessionPanel`）；进 session 立即停止。11 首 `assets/audio/*.mp3`，单曲 loop，直接播放无 fade。

---

## 资源核查（2026-06-06）

`assets/audio/` 下 **11/11** `.mp3` 齐全，与 `kTimerAudioTracks[1..11]` 一一对应。`pubspec.yaml` 已注册 `assets/audio/`，无需改 manifest。

---

## Critical Decisions

| # | 决策 | 理由 |
|---|------|------|
| 1 | 路径 `assets/audio/` + `.mp3` | 用户确认；资源已就位 |
| 2 | 选中态留 `TimerScreen._selectedAudioIndex` | TIMER-001 父级保管，provider 不持 UI 态 |
| 3 | `TimerAudioService` + `Provider`（**非 Notifier**） | play/stop 两方法够用，避免过度抽象 |
| 4 | 路径函数 `timerAudioAssetPath` 放 `audio_picker.dart` | 与 `kTimerAudioTracks` 同源，不新建文件 |
| 5 | `TimerScreen` → `ConsumerStatefulWidget` | 最小 Riverpod 接入 |
| 6 | `ReleaseMode.loop` | 单曲循环直到切换/停止 |
| 7 | 直接 `play()`，无 fade | 用户确认 |
| 8 | **播放生命周期** | 仅 `!_showSessionPanel`（idle/running/paused）；进 session 强制 `stop()`，不自动恢复 |
| 9 | **本期跳过** `isPlayingProvider` 更新 | UI 不展示播放态，省代码 |

**AssetSource 路径（实现时首项真机验证）：**

```dart
AssetSource('audio/Guided Belly Breathing - Female.mp3')
```

---

## 架构（3 文件、~40 行新增）

```
audio_picker.dart
└── kTimerAudioTracks (已有)
└── timerAudioAssetPath(int index) → String?   // index 0 → null

audio_provider.dart
└── TimerAudioService                          // 哑引擎：playTrack / stop
└── timerAudioServiceProvider                  // Provider，非 Notifier

timer_screen.dart (ConsumerStatefulWidget)
├── _selectedAudioIndex                        // 选中态（已有）
├── _syncTimerAudio()                          // 唯一编排：index → play/stop
├── _onAudioItemTap → setState + _syncTimerAudio()
├── _resetAudioOnSessionEnter → stop + 清空（已有 UI 清理）
└── dispose → stop
```

**职责边界：**

| 层 | 做 | 不做 |
|----|-----|------|
| `timerAudioAssetPath` | index → asset 路径 | 播放 |
| `TimerAudioService` | `playTrack` / `stop` / loop | 不知 session、UI |
| `TimerScreen` | 决定何时 play/stop | 不直接操作 `AudioPlayer` |

---

## 播放生命周期

```mermaid
stateDiagram-v2
    [*] --> TimerPhase
    state TimerPhase {
        [*] --> idle
        idle --> running: Start
        running --> paused: Pause
        paused --> running: Resume
        note right of TimerPhase: 可选曲、可播放、可 loop
    }
    TimerPhase --> Session: Stop 确认
    state Session {
        note right of Session: stop()、无播放、无选中
    }
    TimerPhase --> [*]: 离开页面 dispose → stop()
```

| 事件 | UI | 音频 |
|------|-----|------|
| 选中 1–11 | 高亮 + 旋转 | `play` + `loop` |
| 再点同条 | 取消 + 停转 | `stop` |
| 选 No Audio | 高亮 + 停转 | `stop` |
| A→B | 高亮切换 + 旋转保持 | `stop` → `play` 新歌 |
| 关面板（仍在计时阶段） | 选中保留 | **继续播放** |
| Stop → session | 清空 + 停转 + 隐藏 🎵 | **`stop()`** |
| dispose（离开计时页） | — | `stop()` |

---

## 公开 API 契约

### `audio_picker.dart`

```dart
/// index 0 (No Audio) 或越界 → null
String? timerAudioAssetPath(int index) {
  if (index <= 0 || index >= kTimerAudioTracks.length) return null;
  return 'audio/${kTimerAudioTracks[index]}.mp3';
}
```

### `audio_provider.dart`

```dart
class TimerAudioService {
  TimerAudioService(this._player);
  final AudioPlayer _player;

  Future<void> playTrack(int index) async { /* set ReleaseMode.loop, play AssetSource */ }
  Future<void> stop() async { /* stop + reset */ }
}

final timerAudioServiceProvider = Provider<TimerAudioService>((ref) {
  final service = TimerAudioService(ref.watch(audioPlayerProvider));
  return service;
});
```

### `timer_screen.dart`

```dart
void _syncTimerAudio() {
  final index = _selectedAudioIndex;
  final audio = ref.read(timerAudioServiceProvider);
  if (index == null || index == 0) {
    audio.stop();
  } else {
    audio.playTrack(index);
  }
}
```

**调用点（4 处）：**

1. `_onAudioItemTap` — `setState` 后 `_syncTimerAudio()`
2. `_resetAudioOnSessionEnter` — `ref.read(...).stop()`（`_syncTimerAudio` 亦可，因 index 已 null）
3. `dispose` — `stop()`
4. 不在 provider 内判断 `_showSessionPanel`（门控由父级保证）

---

## Tasks

- [x] 🟩 **Phase 1: 路径映射**
  - [x] 🟩 `audio_picker.dart` 新增 `timerAudioAssetPath(int index)`
  - [x] 🟩 规则：`0 → null`；`1..11 → 'audio/{name}.mp3'`

- [x] 🟩 **Phase 2: TimerAudioService**
  - [x] 🟩 `audio_provider.dart` 新增 `TimerAudioService` + `timerAudioServiceProvider`
  - [x] 🟩 `playTrack`：`setReleaseMode(ReleaseMode.loop)` + `play(AssetSource(path))`
  - [x] 🟩 `stop`：`stop()`；切换曲目时 `stop` → `play`
  - [x] 🟩 `try/catch` + `debugPrint` 播放失败（本期不 toast）
  - [x] 🟩 **不**改 `isPlayingProvider`

- [x] 🟩 **Phase 3: TimerScreen 编排**
  - [x] 🟩 改 `ConsumerStatefulWidget` + `ConsumerState`（`TickerProviderStateMixin` 保留）
  - [x] 🟩 新增 `_syncTimerAudio()`，接入 `_onAudioItemTap`
  - [x] 🟩 `_resetAudioOnSessionEnter` 追加 `stop()`
  - [x] 🟩 `dispose` 追加 `stop()`
  - [x] 🟩 移除 `TODO(TIMER-002)` 注释

- [x] 🟩 **Phase 4: 验证**
  - [x] 🟩 `flutter analyze` 三文件无新增 error
  - [x] 🟩 真机 Test Plan 8 条
  - [x] 🟩 更新本 plan 进度至 100%

---

## Test Plan

- [x] idle / running / paused：选 1–11 → 听到对应 mp3
- [x] 单曲 loop（播完自动重复）
- [x] 选 No Audio / 再点同条取消 → 停止
- [x] A→B 切换 → 切歌正确，旋转不中断
- [x] 关面板（计时阶段内）→ 音乐继续
- [x] Stop 进 session → **立即停止**，选中清空，🎵 隐藏
- [x] 退出计时页 dispose → 停止
- [x] session 期间无音频播放（即使未来误调 play，父级不应触发）

---

## 不在本期范围

- `isPlayingProvider` / 播放态 UI
- Notifier / 独立 `timer_audio_paths.dart`
- 淡入淡出、音量 UI、后台播放
- session 结束后自动恢复上次曲目

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| AssetSource 路径格式 | 真机首条验证，单行修正 |
| 大文件加载延迟（~46MB） | 直接 play；本期不加 loading |
| 播放失败 | `debugPrint`，不阻断 UI |

---

## 回滚

还原 `audio_provider.dart`、`timer_screen.dart`、`audio_picker.dart` 三文件即可。

---

## 变更文件清单

| 文件 | 操作 |
|------|------|
| `lib/features/timer/widgets/audio_picker.dart` | +`timerAudioAssetPath` |
| `lib/providers/audio_provider.dart` | +`TimerAudioService` |
| `lib/features/timer/timer_screen.dart` | Consumer + 编排 |
| `pubspec.yaml` | 不改 |
| `assets/audio/*.mp3` | 已就绪 |
