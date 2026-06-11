# TIMER-001: 计时页音乐按钮 + 液体玻璃音频选择面板

**Type:** Feature | **Priority:** Normal | **Effort:** Medium

---

## TL;DR

计时页主操作区旁常驻 33×33 旋转音乐按钮；点击展开液体玻璃音频面板，选中某条后按钮匀速旋转，选「No Audio」或再次点击取消高亮则停止旋转。本期 UI + 占位播放，不接 `audio_provider`。

---

## Current vs Expected

| 维度 | 当前 | 预期 |
|------|------|------|
| 操作区 | 仅 `Start` / `Pause`+`Stop` / `Resume` | 各计时态主操作按钮旁常驻 🎵 按钮（`idle` 为 Start 右侧 +8px） |
| 音乐入口 | 无 | 点击 🎵 展开音频面板；点空白关闭 |
| 面板背景 | 无 | 复用问卷三层液体玻璃 |
| 音频列表 | 无 | `No Audio` + 11 条音频；选中高亮、点击播放（占位） |
| 按钮旋转 | 无 | 选中音频时匀速旋转；取消选中 / 选 No Audio 时停止 |

---

## UI 规格

### 1. 音乐按钮

- 尺寸：33×33，圆角 `1000` / `296`
- 底色：`#F7F7F7`
- 阴影：`Color(0x1E000000)`，`blurRadius: 40`，`offset: (0, 8)`
- 图标：🎵，`#0088FF`，`SF Pro`，`fontSize: 19`，`fontWeight: w590`，`height: 1.16`
- **位置**：`idle` 态在 `Start`（119px）正右侧 **+8px**；`running`/`paused` 态按钮**同样保留**，附着于 `_buildActionButtons()` 当前按钮组右侧 +8px
- **旋转**：仅当有选中音频（非 No Audio）时匀速旋转；转速实现默认 ~3s/圈（可调）

### 2. 展开面板（Figma 393×852）

| 属性 | 值 |
|------|-----|
| 顶部 | `height × 228/852` |
| 高度 | `height × 414/852` |
| 宽度 | `width × 289/393` |
| 水平 | 屏幕居中 |
| 展开动效 | `duration: 1s`，`Curves.easeInOut` |
| 关闭方式 | **点面板外空白区域** |

**液体玻璃背景** — 复用 `timer_screen.dart` L841–874 三层叠加。

### 3. 面板内容

- 文字区：距面板顶 26px，宽 255，水平居中
- 标题：`Choose an audio you like:\n\n` — `Josefin Sans` 16 w500 白
- 列表：`SF Pro` 14，每条 `· `（w700）+ 名称（w400）

**列表顺序（12 条）：**

0. **No Audio**（静音，选中后旋转停止）
1. Guided Belly Breathing - Female
2. Guided Belly Breathing - Male
3. Rain Sounds - Classical
4. Inner Peace - Relaxation
5. Brainwaves - Hz Music
6. Singing Bowl - Flowing Water
7. Binaural Beats - Rain
8. Hz Frequencies - Flowing Water
9. Singing Bowl - Ocean Waves
10. Nature - Hz - Flute
11. Healing - Tranquility

---

## Interaction Spec（已确认）

### 列表选中 / 播放

- **首次点击某条**：立即选中高亮 + 占位播放（本期不接 `audio_provider`，仅 UI 状态）
- **再次点击同一条**：取消高亮 + 停止占位播放
- **高亮样式**：与问卷选项一致（`timer_screen.dart` L744–766），缩放到列表字号 14：
  - 选中：背景 `#0088FF`，`borderRadius: 8`，文字白色 w600
  - 未选中：无背景，文字 `white @ 92%` w400
- **互斥选中**：同时仅一条高亮

### 旋转逻辑

| 操作 | 音乐按钮旋转 |
|------|-------------|
| 选中任意音频（非 No Audio） | 开始匀速旋转 |
| 再次点击同一条（取消高亮） | 停止 |
| 选中 **No Audio** | 停止（静音） |
| 从音频 A 切换到音频 B | 保持旋转（不中断） |

### 面板 / 按钮可见性

- 🎵 按钮：仅在**计时前 + 计时中**（idle / running / paused）显示；**进入 session 面板后隐藏**
- 面板：展开时 **scrim 锁屏**，面板外不可操作；**点空白关闭**；关闭后已选音频状态与旋转状态**保留**
- 进入 session 时：自动关闭音频面板 + **清空选中态** + 停止旋转（避免双层 blur）

---

## Relevant Files

- `lib/core/widgets/liquid_glass_background.dart` — 全局液体玻璃（新建）
- `lib/features/timer/widgets/audio_picker.dart` — 音乐按钮 + 面板 UI（新建）
- `lib/features/timer/timer_screen.dart` — 编排层、选中态、scrim
- ~~`lib/providers/audio_provider.dart`~~ — **本期不接入**；TIMER-002 播放引擎，选中态仍由父级保管

---

## Implementation Notes

- **方案 B**：widget 拆分，状态留 `TimerScreen` 父级
- `_selectedAudioIndex` 父级保管；TIMER-002 父级传索引给 `audio_provider` 播放
- scrim 锁屏 + 点空白关闭；session 出现时关面板并隐藏 🎵
- `FontWeight.w590` → 实现用 `w600` 近似

---

## Risks

- `BackdropFilter` 性能：音频面板与 session 面板不应同时双层 blur
- `running` 态三按钮（Pause + Stop + 🎵）布局需验证不溢出小屏

---

## Test Plan

- [ ] idle / running / paused：🎵 可见，idle 态距 Start 右侧 8px
- [ ] session 面板：🎵 不可见
- [ ] 点击 🎵 → 1s ease-in-out 展开面板；点空白关闭
- [ ] 面板尺寸、玻璃背景、标题、12 条列表文案正确
- [ ] 点击音频 → 高亮（问卷同款蓝底）+ 🎵 开始旋转
- [ ] 再次点击同条 → 高亮消失 + 旋转停止
- [ ] 点击 No Audio → 静音态 + 旋转停止
- [ ] 切换不同音频 → 高亮切换 + 旋转保持
- [ ] 关面板后选中态与旋转态保留（计时阶段内）
- [ ] 进入 session：选中清空、旋转停止、🎵 隐藏
