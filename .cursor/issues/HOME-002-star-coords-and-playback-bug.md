# HOME-002: 星星坐标修正 + 真机点击无音乐

**Type:** Bug | **Priority:** High | **Effort:** Small

---

## TL;DR

真机验收 HOME-001 时发现：点击音乐星星无声音。同时将星星中心点坐标从 (64, 228↓) 调整为 **距左 52、距下 182**（393×852 设计稿）。

---

## Current vs Expected

| 维度 | 当前 | 预期 |
|------|------|------|
| 星星坐标 | 中心距左 64、距下 228（`top=624`） | 中心距左 **52**、距下 **182**（`top=670`） |
| 点击星星 | 真机无音乐播放 | 播放 `day % 10` 对应 `home_music/` 曲目，loop |
| 播放态视觉 | 点击后**有**变大变亮（交互 OK） | 星星 2s 闪 + 加大加亮，且**有声音** |

---

## 疑似根因（按优先级）

1. **`pubspec.yaml` 未注册子目录** — 仅声明 `assets/audio/`，Flutter **不会**自动打包 `assets/audio/home_music/` 下文件；`AssetSource` 真机加载失败，`playToday()` 仅 `debugPrint` 静默吞错
2. ~~**点击未触发**~~ — **已排除**：真机点击后星星变大变亮，热区与 `onStarTap` 正常
3. **播放器状态** — `audioplayers` 在 Android 需确认 asset 路径格式 `audio/home_music/{name}.mp3`（无 `assets/` 前缀）；`isPlaying` 可能短暂 true 但无有效音频流

---

## Fix Plan

### A. 坐标（1 行常量）

`lib/features/home/home_music.dart`：

```dart
const double kMusicStarCenterXDesign = 52;
const double kMusicStarCenterYDesign = 670; // 852 - 182
```

### B. 播放修复

- [x] `pubspec.yaml` 增加 `- assets/audio/home_music/`
- [x] `AssetManifest.bin` 已含 10 个 `home_music/*.mp3`
- [x] 卸载旧包 + 重装真机包验证（2026-06-06 通过）
- [ ] `HomeAudioService.playToday()` 失败时加 `debugPrint` 含完整 asset 路径（已有）+ 可选 dev toast
- [ ] 真机 logcat 搜 `HomeAudioService.playToday failed`

---

## Relevant Files

- `lib/features/home/home_music.dart` — 坐标常量
- `lib/providers/home_audio_provider.dart` — `playToday()` / `AssetSource`
- `pubspec.yaml` — **最可能需改**：注册 `assets/audio/home_music/`

---

## Test Plan

- [x] 星星热区与背景大星视觉对齐（52 / 182↓）
- [x] 真机点击 → 听到当日曲目
- [x] 再点 → 停止
- [x] `flutter pub get` 后 APK 内包含 `home_music/*.mp3`（AssetManifest 已验证）

---

## Notes

- 归属 HOME-001 验收遗留，非新功能
- Timer 音频走 `assets/audio/` 根目录，不受影响
