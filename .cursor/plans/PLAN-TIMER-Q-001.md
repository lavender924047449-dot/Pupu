# Feature Implementation Plan: Timer Warm Sentences Overlay

**Overall Progress:** `100%`

---

## TLDR

在计时页面（`timer_screen.dart`）云朵与计时器之间的空白区域中央，逐条随机展示来自 `Warm_Sentences_timer.md` 的暖心文案。动画：淡入3s → 停留15s → 淡出3s（共21s）；间隔依阶段调整；暂停冻结；session内不重复。

---

## Architecture（第一性原理）

### 文件结构（最小化新增）

```
lib/
├── core/
│   └── warm_sentences_timer.dart        ← NEW：76条文案数据（const）
└── features/timer/
    ├── timer_screen.dart                ← MODIFY：添加调度逻辑 + UI插槽
    └── widgets/
        └── warm_sentence_overlay.dart   ← NEW：纯展示 Widget，无状态
```

### 定位策略（为何放在外层 Stack）

云朵已在外层 `Stack`（屏幕坐标系），计时器显示在 `SafeArea` 内。
为避免 SafeArea offset 计算偏差，warm sentence overlay **同样放入外层 Stack**，
使用与云朵相同的屏幕坐标系，保证跨设备垂直居中准确：

```
外层Stack坐标系:
  cloudBottom  = screenSize.height * 0.066 + screenSize.width * 0.56
  timerTop     = screenSize.height - 286   (bottom:180 + height:106)
  → Positioned(top: cloudBottom, bottom: 286)  ← 覆盖全部空白区
  → Center(child: WarmSentenceOverlay(...))    ← 自动居中
```

### 动画方案（单 Controller，TweenSequence）

一个 21s AnimationController + TweenSequence，消灭额外 Timer 管理显示生命周期：

```dart
// weight比例 = 秒数（总weight=21，总时长=21s，故1weight=1s）
_warmSentenceOpacity = TweenSequence<double>([
  TweenSequenceItem(                                          // 0~3s：淡入
    tween: Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOut)),
    weight: 3,
  ),
  TweenSequenceItem(tween: ConstantTween(1.0), weight: 15),  // 3~18s：停留
  TweenSequenceItem(                                          // 18~21s：淡出
    tween: Tween(begin: 1.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeInOut)),
    weight: 3,
  ),
]).animate(_warmSentenceController);
```

动画完成（`AnimationStatus.completed`）时触发下一次间隔调度。

### 暂停/恢复机制（双路径）

暂停时有两种可能状态，分别处理：

| 暂停时处于 | 恢复操作 |
|-----------|---------|
| 正在显示（animation running） | `controller.stop()` → resume时 `controller.forward()`（从当前value续接） |
| 等待间隔（Timer running） | `timer.cancel()` + 记录 `_warmIntervalStartedAt`，计算剩余ms → resume时用剩余ms重建Timer |

### 调度状态机

```
[start] → _scheduleWarmSentence(25s) → Timer到期
        → _triggerWarmSentence()     → controller.forward(from:0)
        → [displaying 21s]           → AnimationStatus.completed
        → _scheduleNextWarmInterval()→ 按elapsed计算间隔
        → _scheduleWarmSentence(interval) → [循环]
```

---

## Critical Decisions

- **单Controller覆盖全程**：TweenSequence将淡入/停留/淡出合并为一个21s动画，完成事件即可触发下一轮调度，无需单独管理"已停留多久"的计时器。
- **Overlay放外层Stack**：避免SafeArea坐标系偏差，与云朵保持一致的屏幕坐标定位，跨设备准确居中。
- **`FadeTransition` 而非 `AnimatedOpacity`**：`FadeTransition` 直接绑定 `Animation<double>`，无需 setState 驱动，性能更优。
- **复用 `_random`**：`_TimerScreenState` 已有 `final math.Random _random`，直接复用，不新增实例。
- **数据格式（`\n\n`分隔行）**：Dart字符串中每行之间插入 `\n\n`，`Text` widget自然渲染为诗行效果。

---

## Tasks

### Step 1 🟩 Done: 创建文案数据文件 `warm_sentences_timer.dart`

- [x] 🟩 新建 `lib/core/warm_sentences_timer.dart`
- [x] 🟩 声明 `const List<String> kWarmSentencesTimer = [...]`，共76条
- [x] 🟩 每条文案的多行用 `\n\n` 连接（去掉编号前缀 `N.`，保留正文）；单行条目直接为字符串

  示例（条目9）：
  ```dart
  'Take a slow, deep breath.\n\nAs you exhale, let the noise of the world remain outside.\n\nFor this moment, it\'s just you and your body.',
  ```
  示例（单行条目3）：
  ```dart
  'For this moment, simply take care of yourself.',
  ```

---

### Step 2 🟩 Done: 创建 `WarmSentenceOverlay` Widget

- [x] 🟩 新建 `lib/features/timer/widgets/warm_sentence_overlay.dart`
- [x] 🟩 声明为 `StatelessWidget`，参数：`animation` (`Animation<double>`) 和 `text` (`String`)
- [x] 🟩 使用 `FadeTransition(opacity: animation, ...)` 包裹内容
- [x] 🟩 内部结构：`Padding(horizontal: 32)` → `IntrinsicWidth` → `Text`

  文字样式精确定义：
  ```dart
  TextStyle(
    color: Colors.white.withValues(alpha: 0.90),
    fontSize: 18,
    fontFamily: 'Josefin Sans',
    fontWeight: FontWeight.w300,
    height: 1.5,  // 行高，与正文行间距协调
  )
  ```
  文本对齐：`textAlign: TextAlign.left`

- [x] 🟩 最外层包 `IgnorePointer()`，确保文案层不拦截用户手势（背景点击切换图片）

---

### Step 3 🟩 Done: 在 `timer_screen.dart` 添加调度逻辑

#### 3a. 新增状态变量（在现有变量声明区追加）

```dart
late final AnimationController _warmSentenceController;
late final Animation<double> _warmSentenceOpacity;
Timer? _warmIntervalTimer;
int _warmIntervalRemainingMs = 0;
DateTime? _warmIntervalStartedAt;
bool _warmIsDisplaying = false;
String _currentWarmSentence = '';
final Set<int> _usedWarmIndices = {};
```

#### 3b. `initState()` 追加

```dart
_warmSentenceController = AnimationController(
  vsync: this,
  duration: const Duration(seconds: 21),
);
_warmSentenceOpacity = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOut)),
    weight: 3,
  ),
  TweenSequenceItem(tween: ConstantTween(1.0), weight: 15),
  TweenSequenceItem(
    tween: Tween(begin: 1.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeInOut)),
    weight: 3,
  ),
]).animate(_warmSentenceController);
_warmSentenceController.addStatusListener(_onWarmAnimationStatus);
```

#### 3c. `dispose()` 追加

```dart
_warmIntervalTimer?.cancel();
_warmSentenceController.removeStatusListener(_onWarmAnimationStatus);
_warmSentenceController.dispose();
```

#### 3d. 新增方法

```dart
// 动画完成监听（只响应 completed）
void _onWarmAnimationStatus(AnimationStatus status) {
  if (status != AnimationStatus.completed) return;
  if (!mounted) return;
  _warmIsDisplaying = false;
  _scheduleNextWarmInterval();
}

// 计算下一次间隔并调度
void _scheduleNextWarmInterval() {
  final s = _elapsed.inSeconds;
  final ms = s < 180 ? 50000 : s < 600 ? 120000 : 240000;
  _scheduleWarmSentence(Duration(milliseconds: ms));
}

// 创建间隔 Timer
void _scheduleWarmSentence(Duration delay) {
  _warmIntervalTimer?.cancel();
  _warmIntervalRemainingMs = delay.inMilliseconds;
  _warmIntervalStartedAt = DateTime.now();
  _warmIntervalTimer = Timer(delay, _triggerWarmSentence);
}

// 触发显示下一条文案
void _triggerWarmSentence() {
  if (!mounted) return;
  setState(() {
    _currentWarmSentence = _pickWarmSentence();
    _warmIsDisplaying = true;
  });
  _warmSentenceController.forward(from: 0.0);
}

// 随机抽取，不重复；耗尽后重置
String _pickWarmSentence() {
  if (_usedWarmIndices.length >= kWarmSentencesTimer.length) {
    _usedWarmIndices.clear();
  }
  int index;
  do {
    index = _random.nextInt(kWarmSentencesTimer.length);
  } while (_usedWarmIndices.contains(index));
  _usedWarmIndices.add(index);
  return kWarmSentencesTimer[index];
}

// 暂停文案系统
void _pauseWarm() {
  if (_warmIsDisplaying) {
    _warmSentenceController.stop();
  } else {
    _warmIntervalTimer?.cancel();
    _warmIntervalTimer = null;
    if (_warmIntervalStartedAt != null) {
      final elapsed = DateTime.now()
          .difference(_warmIntervalStartedAt!)
          .inMilliseconds;
      _warmIntervalRemainingMs =
          (_warmIntervalRemainingMs - elapsed).clamp(0, _warmIntervalRemainingMs);
      _warmIntervalStartedAt = null;
    }
  }
}

// 恢复文案系统
void _resumeWarm() {
  if (_warmIsDisplaying) {
    _warmSentenceController.forward();
  } else if (_warmIntervalRemainingMs > 0) {
    _warmIntervalStartedAt = DateTime.now();
    _warmIntervalTimer = Timer(
      Duration(milliseconds: _warmIntervalRemainingMs),
      _triggerWarmSentence,
    );
  }
}

// 停止并完全重置文案系统
void _stopWarm() {
  _warmIntervalTimer?.cancel();
  _warmIntervalTimer = null;
  _warmSentenceController.stop();
  _warmSentenceController.reset();
  _warmIsDisplaying = false;
  _warmIntervalRemainingMs = 0;
  _warmIntervalStartedAt = null;
  _usedWarmIndices.clear();
  _currentWarmSentence = '';
}
```

#### 3e. 修改现有方法（最小 diff）

- **`_startTimer()`**：在 `setState` 结束后追加：
  ```dart
  _stopWarm();  // 重置旧状态
  _scheduleWarmSentence(const Duration(seconds: 25));  // 25s后显示第一条
  ```

- **`_pauseTimer()`**：在方法末尾追加：
  ```dart
  _pauseWarm();
  ```

- **`_resumeTimer()`**：在方法末尾追加：
  ```dart
  _resumeWarm();
  ```

- **`_doStopTimer()`**：在 `setState` 内追加 `_currentWarmSentence = ''`，在 `setState` 外追加：
  ```dart
  _stopWarm();
  ```

---

### Step 4 🟩 Done: 在外层 Stack 中插入 Overlay（`build()` 方法）

在现有 `if (!_showSessionPanel) ...[...]` 代码块内，`SafeArea(child: _buildTimerLayout(screenSize))` 之后插入：

```dart
Positioned(
  top: screenSize.height * 0.066 + screenSize.width * 0.56,
  bottom: 286,
  left: 0,
  right: 0,
  child: IgnorePointer(
    child: Center(
      child: WarmSentenceOverlay(
        animation: _warmSentenceOpacity,
        text: _currentWarmSentence,
      ),
    ),
  ),
),
```

并在文件顶部添加 import：
```dart
import 'package:pupu/core/warm_sentences_timer.dart';
import 'package:pupu/features/timer/widgets/warm_sentence_overlay.dart';
```

---

### Step 5 🟩 Done: 验证边缘情况

- [x] 🟩 idle状态下opacity=0（controller未启动），overlay不可见，无需额外门控
- [x] 🟩 `_showSessionPanel=true` 时整个 `!_showSessionPanel` 块不渲染，overlay自然隐藏
- [x] 🟩 暂停再恢复：`controller.forward()` 从 `controller.value` 续接，不归零
- [x] 🟩 跨阶段（2:55→3:18消失）：`_scheduleNextWarmInterval()` 在消失时读 `_elapsed`（已是3:18），正确返回120s
- [x] 🟩 76条耗尽：`_usedWarmIndices.clear()` 重置后重新随机，继续循环
- [x] 🟩 Stop后重新Start：`_stopWarm()` + `_scheduleWarmSentence(25s)` 确保干净重置

---

## 执行顺序

```
Step 1 → Step 2 → Step 3（3a→3b→3c→3d→3e）→ Step 4 → Step 5
```

每步独立，Step 1-2 可并行执行（无依赖），Step 3-4 依赖前两步。
