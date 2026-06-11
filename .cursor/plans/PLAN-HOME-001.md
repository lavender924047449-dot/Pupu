# HOME-001 首页星星音乐开关实施计划

**Overall Progress:** `100%`

## TLDR

在首页静态星空背景上，于设计稿中心点 (52, 670) 叠加可点击星星层：始终循环闪烁（idle 1s / 播放 2s），点击 toggle 当日 BGM（`day % 10`，10 首 `home_music/`）。独立 `AudioPlayer`，子页跳转与 App 后台同等 pause；跨午夜不打断，曲终暂停后次日再点切歌。**真机验收通过**（含 HOME-002 修复）。

---

## Critical Decisions

- **独立播放器** — `homeAudioPlayerProvider` 与 `audioPlayerProvider` 分离，避免与 TIMER-003 互斥
- **Provider 持状态** — `HomeAudioService` 放 Riverpod 单例（`userWantsMusic`、`pendingDayRollover`），`HomeScreen` 为根路由 push 不 dispose
- **不用 RouteObserver** — 三个 `_open*` 导航前 + `WidgetsBindingObserver` 各调 `pauseForLeave()`
- **缩放模型 A** — `centerX = 52/393·W`，`centerY = 670/852·H`，中心锚点对齐
- **跨日策略** — 播放中跨午夜 → `ReleaseMode.release` → 曲终 `pendingDayRollover = true` → 再点 `playToday()`
- **视觉** — 无新素材；`BoxDecoration` 圆点 + `BoxShadow`；仅 `PlayerState.playing` 时 scale 1.35 + 更亮
- **资源** — `pubspec.yaml` 注册 `assets/audio/home_music/`（HOME-002）

---

## Tasks

- [x] 🟩 **Step 1: 曲目与坐标常量** — `lib/features/home/home_music.dart`
  - [x] 🟩 定义 `kHomeMusicTracks`（10 首，顺序与 issue 表一致）
  - [x] 🟩 实现 `homeMusicAssetPath(int index)` → `audio/home_music/{name}.mp3`
  - [x] 🟩 设计常量：`centerX=52`、`centerY=670`、热区半径 24 design px

- [x] 🟩 **Step 2: 音频服务与状态机** — `lib/providers/home_audio_provider.dart`
  - [x] 🟩 新建 `homeAudioPlayerProvider`（独立 `AudioPlayer`，`ref.onDispose` 释放）
  - [x] 🟩 实现 `HomeAudioService`：`playToday()` / `stop()` / `resume()` / `pauseForLeave()`
  - [x] 🟩 实现 `onStarTap()` 四分支
  - [x] 🟩 跨日 rollover 逻辑
  - [x] 🟩 暴露 `homeMusicPlayingProvider` 供星星 widget 订阅

- [x] 🟩 **Step 3: 星星 UI 组件** — `lib/features/home/widgets/music_star_toggle.dart`
  - [x] 🟩 idle 1s / playing 2s 闪烁
  - [x] 🟩 播放中 scale 1.35 + 光晕
  - [x] 🟩 热区 ≥ 44dp

- [x] 🟩 **Step 4: 接入 HomeScreen** — `lib/features/home/home_screen.dart`
  - [x] 🟩 Stack 放置 `MusicStarToggle`
  - [x] 🟩 导航前 `pauseForLeave()`
  - [x] 🟩 `WidgetsBindingObserver` 后台 pause

- [x] 🟩 **Step 5: 验收**
  - [x] 🟩 点击播/停、`day%10` 曲目 loop
  - [x] 🟩 播放态 2s 闪 + 加大加亮；pause 回 idle 闪
  - [x] 🟩 坐标与背景星对齐（52 / 182↓）
  - [x] 🟩 真机音频播放正常（HOME-002 修复后）

---

## 文件清单

| 操作 | 路径 |
|------|------|
| 新建 | `lib/features/home/home_music.dart` |
| 新建 | `lib/providers/home_audio_provider.dart` |
| 新建 | `lib/features/home/widgets/music_star_toggle.dart` |
| 修改 | `lib/features/home/home_screen.dart` |
| 修改 | `pubspec.yaml` |

---

## Rollback

删除 3 个新建文件；`home_screen.dart` 移除星星层；`pubspec.yaml` 移除 `home_music/` 注册。
