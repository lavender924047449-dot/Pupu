# HOME-002 星星坐标修正 + 真机无音乐修复计划

**Overall Progress:** `100%`

## TLDR

HOME-001 真机验收遗留：点击星星有播放态视觉但无声音。根因为 `pubspec.yaml` 未注册 `home_music/` 子目录。已修正坐标 (52, 670) 并注册资源，**真机测试通过**。

---

## 真机观察（已确认）

- 点击星星 → **星星变大变亮** ✅
- 点击星星 → **有音乐播放** ✅（修复后）
- 坐标与背景星对齐 ✅

---

## Critical Decisions

- **主因** — `assets/audio/` 不含子目录；需显式注册 `assets/audio/home_music/`
- **坐标** — 中心点 `(52, 670)`（距下 182）
- **最小改动** — 仅 `home_music.dart` + `pubspec.yaml`，未改状态机

---

## Tasks

- [x] 🟩 **Step 1: 修正星星坐标** — `lib/features/home/home_music.dart`
  - [x] 🟩 `kMusicStarCenterXDesign`：`64` → `52`
  - [x] 🟩 `kMusicStarCenterYDesign`：`624` → `670`（852 − 182）

- [x] 🟩 **Step 2: 注册 home_music 资源** — `pubspec.yaml`
  - [x] 🟩 在 `assets:` 下增加 `- assets/audio/home_music/`
  - [x] 🟩 执行 `flutter pub get`
  - [x] 🟩 `AssetManifest.bin` 已含 10 个 `assets/audio/home_music/*.mp3`

- [x] 🟩 **Step 3: 真机验证**
  - [x] 🟩 debug APK 构建成功
  - [x] 🟩 重装后点击星星 → 听到 `day % 10` 曲目，loop
  - [x] 🟩 再点 → 停止，星星恢复 idle 闪
  - [x] 🟩 星星叠加层与背景大星视觉对齐

- [x] 🟩 **Step 4: 收尾** — 无需执行（Step 3 已通过）

---

## 文件清单

| 操作 | 路径 |
|------|------|
| 修改 | `lib/features/home/home_music.dart` |
| 修改 | `pubspec.yaml` |

---

## 与 HOME-001 关系

- HOME-001 / HOME-002 均已 **100%** 完成
