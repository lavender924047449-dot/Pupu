# HOME-003 Home BGM 播放 / 暂停 / 记忆逻辑修订

**Overall Progress:** `85%`

## TLDR

修订首页星星音乐的状态机：**播放中点星星 = pause（非 stop）**，进度**无限期记忆**；**App 切后台继续播**（星星大亮）；**进子页仍 pause**，返回不自动 resume；**paused 跨日瞬间**内部清进度，再点播新 day 曲；播放中跨日逻辑不变。

---

## 最终规格（探索已确认）

| 场景 | 行为 |
|------|------|
| 星星大亮 | ⟺ `PlayerState.playing` |
| 首次点星星（未开过） | `playToday()`，loop |
| 播放中点星星 | `pause()`，保留进度（无 10min 限时） |
| paused 点星星（同日） | `resume()` 原进度 |
| paused 点星星（已跨日） | `playToday()` 新 day 曲（Q5B） |
| App 切后台（播放中） | **不 pause**，音乐继续 |
| App 切后台（paused） | 无声、星星 idle（Q9 OK） |
| 进 Timer / 档案 / 私人空间 | `pauseForLeave()`，保留进度 |
| 子页返回 | 不自动 resume，点星星 `resume()` |
| 播放中跨午夜 | **不变**：本轮播完停 → `pendingDayRollover` → 再点 `playToday()` |
| paused 跨午夜（Q8） | **跨日瞬间** `stop()` 清进度、更新 day；再点 `playToday()` |
| 彻底关闭音乐 | **不需要**（Q7A），pause 即可 |

---

## Critical Decisions

- **单文件状态机** — 逻辑集中在 `HomeAudioService`，UI 仍只读 `homeMusicPlayingProvider`
- **pause 记忆** — `audioplayers` pause/resume + `_pauseMemoryValid` 守卫
- **跨日清 memory** — `evaluateDayRollover()` 统一处理 playing + paused
- **后台 vs 子页分流** — 生命周期不 pause；三个 `_open*` 保留 `pauseForLeave()`
- **无 stop 路径** — `onStarTap` playing → `pauseByUser()`

---

## Tasks

- [x] 🟩 **Step 1: 重构 `HomeAudioService` 状态机** — `lib/providers/home_audio_provider.dart`
  - [x] 🟩 新增 `_pauseMemoryValid`；`pauseByUser()` / `pauseForLeave()` 设 true
  - [x] 🟩 `onStarTap()`：playing → `pauseByUser()`（移除 stop 分支）
  - [x] 🟩 paused 分支：同日 + memory → `resume()`；否则 → `playToday()`
  - [x] 🟩 `userWantsMusic` pause 后保持 true（Q7A）

- [x] 🟩 **Step 2: 区分后台 vs 子页** — `lib/features/home/home_screen.dart`
  - [x] 🟩 删除 `didChangeAppLifecycleState` 中 `paused/inactive` → `pauseForLeave()`
  - [x] 🟩 保留 `resumed` → `evaluateDayRollover()`
  - [x] 🟩 保留三个 `_open*` → `pauseForLeave()`

- [x] 🟩 **Step 3: paused 跨日瞬间清 memory** — `home_audio_provider.dart`
  - [x] 🟩 `_clearPausedMemoryForNewDay()`：paused 跨日 stop + 清 memory
  - [x] 🟩 playing 跨日逻辑保持不动

- [ ] 🟨 **Step 4: 后台播放（按需）**
  - [ ] 🟨 真机：播放中切后台 → 音乐继续、回前台星星大亮
  - [ ] 🟨 若失败：补 Android / iOS 后台音频配置
  - [x] 🟩 Step 1–3 完成后再测（未提前加原生配置）

- [ ] 🟨 **Step 5: 回归验收**（待真机）
  - [x] 🟩 代码路径：播放中点星星 pause / 再点 resume
  - [x] 🟩 代码路径：子页 pause / 返回再点 resume
  - [x] 🟩 代码路径：后台不 pause
  - [ ] 🟨 真机全量回归（含跨午夜、Timer 互斥）

---

## 文件清单

| 操作 | 路径 |
|------|------|
| 修改 | `lib/providers/home_audio_provider.dart` |
| 修改 | `lib/features/home/home_screen.dart` |
| 按需 | `android/app/src/main/AndroidManifest.xml` |
| 按需 | `ios/Runner/Info.plist` |

---

## Rollback

还原 `home_audio_provider.dart` 的 `onStarTap`（playing → stop）；恢复 `didChangeAppLifecycleState` 的 `pauseForLeave()`。
