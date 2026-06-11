# HOME-001: 首页星空星星音乐开关

**Type:** Feature | **Priority:** Normal | **Effort:** Medium

---

## TL;DR

在首页「Flow with me」下方选定一颗背景大星（中心锚点），叠加可点击热区：始终循环闪烁（idle 1s / 播放 2s ease-in-out）；点击播放当日 BGM（10 首，`day % 10` 轮换，loop），再点停止。仅播放中星星加大加亮。音乐仅在 Home 生效；跳转子页 / App 切后台 → pause 并记住状态，返回不自动续播；跨午夜播放中不打断，当前曲播完后暂停，再点切次日曲目。

---

## Current vs Expected

| 维度 | 当前 | 预期 |
|------|------|------|
| 背景 | 静态 `home_intro_bg.png`，星星为位图像素 | Stack 叠加热区 + 发光星层（设计稿比例定位） |
| 星星交互 | 无 | 始终循环闪（idle 1s / 播放 2s）；点击 toggle 播放/停止 |
| 播放态视觉 | 无 | **仅播放中** scale ↑ + 光晕 ↑；pause 回 Home 恢复 idle 闪 |
| 音乐 | 首页无音频 | 10 首全新 mp3，`localDay % 10` 选曲，单曲 loop |
| 页面生命周期 | — | 离开 Home → `pause` + 记 `wasPlaying`；回 Home → 不自动播，再点才 `resume` |
| 互斥 | Timer 与 Home 共用 `audioPlayerProvider` | Home 独立 `AudioPlayer`，与计时页音频互不影响 |

---

## 交互规格（已确认）

1. **闪烁**：始终 `Curves.easeInOut` 循环闪；**idle / pause 态 1s**；**播放中 2s**（更慢）。
2. **播放态视觉**：**仅 `PlayerState.playing` 时**加大加亮；idle / pause / 子页返回待续播 → 均为 idle 闪（不保持大亮）。
3. **Toggle**：
   - 未开启 → 点击 → `playToday()`（loop）
   - 播放中 → 点击 → `stop()`（清空意图）
   - pause 待续播（子页返回 / 后台返回）→ 点击 → `resume()` 同一曲目
   - pause 待续播 + **跨日 rollover 后** → 点击 → `playToday()` 次日曲目
4. **日轮换**：`DateTime.now().day % 10` → `kHomeMusicTracks[index]`。
5. **离开可见**（跳转子页 **或** App 切后台，同等处理）：
   - 播放中 → `pause()`，保留 `userWantsMusic = true`
   - 返回 Home / 回前台 → **不**自动 `resume`
6. **跨午夜**（播放中过了本地 0:00）：
   - **不打断**当前曲，继续播完本轮
   - 实现：检测到跨日后 `setReleaseMode(ReleaseMode.release)`，本轮结束自然 stop
   - 曲终 → 进入 pause 态，`userWantsMusic` 仍为 true，记 `pendingDayRollover = true`
   - 用户再点 → `playToday()` 用新 `day % 10`，清 rollover 标记
7. **互斥**：Home 独立 `AudioPlayer`；Timer 用现有 `audioPlayerProvider`。

---

## 实现要点

### 1. 星星定位（静态图叠层）

背景为 `assets/images/home_intro_bg.png`，不可改 painter。在 `home_screen.dart` 的 `Stack` 中：

- **设计稿坐标（已确认）**：393×852，**星星中心点**距左 **64**、距下 **228**
  - 缩放模型 **A**（与文案一致）：`centerX = 64/393 * screenWidth`，`centerY = 624/852 * screenHeight`
  - `Positioned` 用中心点减半径对齐
- 热区半径：首版建议 22–28 design px（≥ 44×44 dp 可点区域），真机微调
- `Positioned` + `GestureDetector(behavior: HitTestBehavior.opaque)`
- 视觉层：`AnimatedBuilder` 驱动 idle 闪烁；播放态叠加 scale/brightness

### 2. 音频服务

新建 `HomeAudioService`（或扩展现有 provider 文件）：

```dart
// 伪代码 — HomeAudioService（Provider 单例）
class HomeAudioService {
  bool userWantsMusic = false;
  bool pendingDayRollover = false;
  int? _playingDay; // 开始播放时的 day，用于跨日检测

  Future<void> onStarTap() async {
    if (!userWantsMusic) { userWantsMusic = true; await playToday(); }
    else if (playing) { userWantsMusic = false; await stop(); }
    else if (pendingDayRollover) { pendingDayRollover = false; await playToday(); }
    else { await resume(); }
  }

  Future<void> pauseForLeave() async { if (playing) await _player.pause(); }

  void _onMidnightWhilePlaying() {
    pendingDayRollover = true;
    _player.setReleaseMode(ReleaseMode.release); // 本轮结束 stop，不 loop
  }

  void _onTrackComplete() {
    if (pendingDayRollover) { /* 保持 userWantsMusic */ }
  }
}
```

- 资源路径：`assets/audio/home_music/`（**10/10 已就位**，见下表）
- `pubspec.yaml` 已注册 `assets/audio/`，子目录 `home_music/` 自动包含

**曲目映射（`day % 10` → 固定顺序，实现为 `kHomeMusicTracks` 常量）：**

| Index | 文件名 |
|-------|--------|
| 0 | `bach-prelude-c-major.mp3` |
| 1 | `canon-in-d.mp3` |
| 2 | `chopin-nocturne-20-in-c-sharp-minor.mp3` |
| 3 | `chopin-nocturne-op-9-no-2.mp3` |
| 4 | `claire-de-lune-debussy.mp3` |
| 5 | `gymnopedie-n1.mp3` |
| 6 | `saint-saens-le-carnaval-des-animaux-1886-piano-9290.mp3` |
| 7 | `schumann-kinderszenen.mp3` |
| 8 | `tunetank-classical-piano-music-1.mp3` |
| 9 | `tunetank-classical-piano-waltz.mp3` |

`AssetSource` 路径：`audio/home_music/{filename}.mp3`（不含 `assets/` 前缀）

### 3. 生命周期挂钩

在 `HomeScreen`（**不用 RouteObserver**）：

- 三个 `_open*` 导航前显式 `pauseForLeave()`
- `WidgetsBindingObserver`：`AppLifecycleState.paused/inactive` → `pauseForLeave()`；`resumed` 不自动播
- 午夜检测：`Timer.periodic` 或 `resumed` 时比对 `_playingDay` vs `DateTime.now().day`
- Provider `ref.onDispose` 释放 `AudioPlayer`

### 4. 与 TIMER-003 边界

- `timerAudioServiceProvider` 与 `homeAudioServiceProvider` 各用独立 `AudioPlayer`
- 用户 Home 开 BGM → 进 Timer 选曲：Home 已 pause；Timer 正常播；回 Home 仍须再点星才续播 Home BGM

### 5. 推荐文件结构（最简）

| 文件 | 职责 |
|------|------|
| `lib/features/home/home_music.dart` | `kHomeMusicTracks`、asset 路径、设计坐标常量 |
| `lib/providers/home_audio_provider.dart` | 独立 `AudioPlayer` + `HomeAudioService` + `onStarTap` 状态机 |
| `lib/features/home/widgets/music_star_toggle.dart` | 闪烁（1s/2s 切换）、热区、播放态视觉 |
| `lib/features/home/home_screen.dart` | 定位、`WidgetsBindingObserver`、导航前 pause |

---

## Relevant Files

- `lib/features/home/home_screen.dart` — 星星热区、闪烁/播放态动画、导航生命周期
- `lib/providers/home_audio_provider.dart` — **新建**，不改 Timer 的 `audio_provider.dart`
- `lib/features/home/home_music.dart`、`widgets/music_star_toggle.dart` — **新建**
- `assets/audio/home_music/` — 10 首 mp3（**已就位**）
- `pubspec.yaml` — `assets/audio/` 已注册，无需改动
- `lib/features/home/home_screen.dart` 内 `_openTimer` / `_openNewArchive` / `_openPrivateSpace` — 离开前 pause

---

## 待产品补充

- [x] 目标星星坐标：距左 64、距下 228（393×852）
- [x] 10 首 mp3：`assets/audio/home_music/` 已就位
- [x] 坐标锚点：中心点；缩放模型 A
- [x] 闪烁：idle 1s / 播放 2s；仅播放中加大加亮
- [x] 后台与子页 pause 同等；跨日曲终切换
- [ ] 播放态 scale/亮度具体数值（首版 scale 1.35，后续微调）

---

## Risks

| 风险 | 缓解 |
|------|------|
| 星星坐标在不同屏幕比例下偏移 | 与云朵/文案同一套 `_designWidth/Height` 比例；真机多尺寸验收 |
| 与 Timer 共用 `audioPlayerProvider` 互相抢播 | **必须**独立 `AudioPlayer` |
| `day % 10` 每月 1–9 日与 10–31 日分布不均 | 可接受；若以后要均匀可改 `dayOfYear % 10` |
| 用户不知可点 | 持续闪烁已缓解；仍无文字提示（符合设计） |
| 离开 pause、回来需再点 — 状态机略复杂 | 覆盖 toggle / resume / rollover 单测 |
| 跨日 `ReleaseMode.release` 依赖 `onPlayerComplete` | 真机验证；fallback：`Duration` 监听 |
| App 后台需 `WidgetsBindingObserver` | `HomeScreen` mixin，与导航 pause 共用 `pauseForLeave()` |
| 同名文件在 `assets/audio/` 根目录也有副本 | Home 仅用 `home_music/` 路径；避免混用 |

---

## Test Plan

- [x] 首页星星持续 1s 闪烁（未播放态）
- [x] 点击 → 播放 `day % 10` 对应曲目，loop
- [x] 再点 → 停止，恢复 idle 视觉
- [x] 播放中星星明显更大、更亮
- [ ] 进 Timer / 档案 / 私人空间 → 音乐 pause，回 Home 无声
- [ ] 回 Home 后再点星星 → 从 pause 位置 resume
- [ ] resume 后再点 → stop
- [ ] Timer 页独立选曲播放，与 Home 不冲突
- [ ] 退出 App / dispose Home → 播放器释放
- [x] 多机型热区可点（当前机型通过）
- [x] 播放中闪烁周期 2s（非 1s）
- [x] pause 回 Home 星星为 idle 闪（非大亮）
- [ ] App 切后台 → pause；回前台不自动播，再点 resume
- [ ] 跨午夜播放：当前曲播完暂停，再点播次日曲

---

## Rollback

移除 `Stack` 星星层与 `HomeAudioService`；`home_screen.dart` 恢复仅背景图 + 现有入口。
