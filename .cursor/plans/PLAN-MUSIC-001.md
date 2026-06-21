# Home BGM 子页联动 — 实施计划

**Overall Progress:** `92%`

## TLDR

当前进入任何子页都会 pause Home BGM，用户需回 Home 再点星星恢复。改为：仅进 Timer 时 pause，Archive 和 Private Space 保持播放；两个子页各添加一个旋转 🎵 按钮，可直接 toggle Home BGM；Private Space 录音/播放录音期间自动 pause BGM，结束后自动 resume。

## Critical Decisions

- **toggle 方法：** 在 `HomeAudioService` 新增 `toggleFromSubPage(WidgetRef ref)` 方法，统一子页的 play/pause 入口。未播放且 `userWantsMusic == false` 时首次点击等同 `onStarTap` 的首次开启逻辑；已播放时调 `pauseByUser()`；已暂停时调 `resume()`。与星星的 `onStarTap` 区别在于：不处理跨日 rollover（子页无需关心），只做纯 toggle。
- **按钮组件复用：** `TimerMusicButton` 已是独立 StatelessWidget，直接复用，无需新建组件。子页各自持有 `AnimationController`，通过 `ref.watch(homeMusicPlayingProvider)` 驱动旋转同步。
- **录音/播放录音联动：** 不在 `PrivateVoiceRecordSheet` / `PrivateVoicePlayer` 内直接操作 `HomeAudioService`（它们无 `ref`）。改为在 `PrivateSpaceScreen` 的调用点处理：调 `_addVoiceBlock()` 前 pause，返回后 resume；`PrivateVoicePlayer.toggle()` 同理在 UI 层包装。
- **按钮位置：** Archive 右下角 `right:24, bottom:34`；PS idle/notepad 右下角同位置；PS history 标题栏右侧（替换 `SizedBox(width:48)` 占位）；PS history 选择模式下隐藏按钮。

## 架构概览

```
homeMusicPlayingProvider (StreamProvider<bool>)
        ↑ watch
        │
  ┌─────┴──────────────────────────────┐
  │  Archive / PrivateSpace 子页       │
  │  ┌──────────────────────┐          │
  │  │ AnimationController  │          │
  │  │ (本地，6s repeat)     │          │
  │  └──────┬───────────────┘          │
  │         │ isPlaying → repeat/stop  │
  │  ┌──────┴───────────────┐          │
  │  │ TimerMusicButton     │          │
  │  │ onTap → toggleFromSubPage()    │
  │  └─────────────────────┘          │
  └────────────────────────────────────┘
        │ read
        ↓
  homeAudioServiceProvider.toggleFromSubPage(ref)
```

## 执行顺序说明

Phase 1 先铺好底层 API，确保 toggle 方法可用且测试通过。
Phase 2 改 Home 导航逻辑（移除两个 pauseForLeave）。
Phase 3-4 分别为 Archive 和 Private Space 添加按钮（独立，无依赖）。
Phase 5 处理录音/播放录音的 pause/resume 联动。
Phase 6 最终集成验证。

## Tasks

- [x] 🟩 **Phase 1: HomeAudioService 新增 toggleFromSubPage**
  - [x] 🟩 `lib/providers/home_audio_provider.dart` 已新增 `toggleFromSubPage(WidgetRef ref)`，覆盖首次播放、暂停恢复、跨日重播分支
  - [x] 🟩 已完成编译级静态检查（`flutter analyze`）

- [x] 🟩 **Phase 2: Home 导航去掉 Archive/PS 的 pauseForLeave**
  - [x] 🟩 `lib/features/home/home_screen.dart` 已移除 `_openNewArchive()` 的 `pauseForLeave()`
  - [x] 🟩 `lib/features/home/home_screen.dart` 已移除 `_openPrivateSpace()` 的 `pauseForLeave()`
  - [x] 🟩 `_openTimer()` 的 `pauseForLeave()` 保持不变

- [x] 🟩 **Phase 3: Archive 页添加音乐按钮**
  - [x] 🟩 `lib/features/archive/new_archive_screen.dart` 已接入 `AnimationController`（6s）并完成生命周期管理
  - [x] 🟩 已基于 `homeMusicPlayingProvider` 同步旋转状态
  - [x] 🟩 已在右下角添加 `TimerMusicButton`（`right:24, bottom:34`）
  - [x] 🟩 点击按钮已调用 `toggleFromSubPage()`

- [x] 🟩 **Phase 4: Private Space 页添加音乐按钮**
  - [x] 🟩 `lib/features/private_space/private_space_screen.dart` 已接入音乐旋转控制器并按播放状态同步
  - [x] 🟩 idle / notepad 阶段右下角按钮已添加（`right:24, bottom:34`）
  - [x] 🟩 history 标题栏右侧已替换为音乐按钮（与返回箭头同一行）
  - [x] 🟩 history 选择模式下已隐藏音乐按钮（保留占位宽度）

- [x] 🟩 **Phase 5: 录音/播放录音时 pause/resume Home BGM**
  - [x] 🟩 `_addVoiceBlock()` 已实现：录音前 pause、录音结束后自动 resume
  - [x] 🟩 语音回放已实现联动：播放前 pause，暂停/播放结束后 resume
  - [x] 🟩 通过 `PrivateVoicePlayer` 监听处理播放完成自动恢复，未在 `dispose` 强制额外 resume
  - [x] 🟩 已完成跨组件回调串联（`PrivateSpaceScreen` → `PrivateSpaceNotepadStage` → `PrivateNoteEditor` → `InlineVoiceBubble`）

- [ ] 🟨 **Phase 6: 集成验证**
  - [ ] 🟥 验证：Home 播放 BGM → 进 Archive → 音乐继续 + 按钮旋转 → 点按钮暂停 → 按钮停转 → 再点恢复
  - [ ] 🟥 验证：Home 播放 BGM → 进 PS idle → 音乐继续 → 进 notepad → 按钮在右下角 → 进 history → 按钮在标题栏右侧
  - [ ] 🟥 验证：PS history 选择模式 → 按钮隐藏
  - [ ] 🟥 验证：PS notepad 录音 → BGM 自动 pause → 录完 → BGM 自动 resume
  - [ ] 🟥 验证：PS notepad 播放语音笔记 → BGM 暂停 → 播放完 → BGM 恢复
  - [ ] 🟥 验证：Home 未开启 BGM → 进 Archive → 按钮静止 → 点按钮 → BGM 首次开启 + 旋转
  - [ ] 🟥 验证：Timer 流程不受影响（pauseForLeave 保留，session 结束 resume 保留）
  - [ ] 🟥 验证：App 切后台不 pause BGM（原有行为不变）
