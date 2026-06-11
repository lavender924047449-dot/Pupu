# Pupu 技术栈决策

> 为 UI-001 宇宙主题重构及后续开发提供统一技术选型参考。基于现有代码库与 UI-001 需求整理。

---

## 1. Flutter / Dart 版本

| 项 | 决策 | 说明 |
|----|------|------|
| Flutter | **3.24+**（stable） | 当前 pubspec 使用 `sdk: ^3.5.0`，与 Flutter 3.24 / Dart 3.5 兼容 |
| Dart | **3.5+** | 与 Flutter 3.24 捆绑 |
| 最低支持 | Android 21 / iOS 12 | 与现有 `minSdkVersion 21` 一致 |

**约束**：升级 Flutter 后执行 `flutter pub upgrade` 验证依赖兼容性。

---

## 2. 状态管理

| 项 | 决策 |
|----|------|
| 方案 | **flutter_riverpod** |
| 当前状态 | **已落地并收敛**：统一采用 `XWithRefreshProvider + bumpXRefresh` |

**适用场景**：
- 主页面 ↔ 计时页：计时结果、是否刚完成记录
- 档案页：记录列表、健康建议来源
- 私人空间：条目列表、附件上传状态

**依赖**：`flutter_riverpod ^2.6.0`

### 2.1 Provider 分层架构

```
lib/
├── providers/
│   ├── records_provider.dart   # recordsWithRefreshProvider + bumpRecordsRefresh
│   ├── entries_provider.dart   # entriesWithRefreshProvider + bumpEntriesRefresh
│   └── audio_provider.dart     # 计时音频服务 Provider（timer/home）
├── features/
│   ├── home/
│   ├── timer/
│   ├── archive/
│   └── private_space/
└── ...
```

| Provider | 职责 | 主要 State |
|----------|------|------------|
| `records_provider` | 对接 LocalStorage，提供记录统一读入口和刷新触发 | `recordsWithRefreshProvider` / `recordsRefreshProvider` |
| `entries_provider` | 对接 LocalStorage，提供条目统一读入口和刷新触发 | `entriesWithRefreshProvider` / `entriesRefreshProvider` |
| `audio_provider` | 计时页与首页音频服务注入（播放/停止/恢复） | `timerAudioServiceProvider` / `homeAudioServiceProvider` |

---

## 3. 动效实现方式

| 类型 | 方案 | 实现 |
|------|------|------|
| **页面过渡** | `PageRouteBuilder` + `AnimationController` | 1.5s 淡入淡出，曲线 `Curves.easeInOut`（禁止弹跳） |
| **呼吸动画** | `AnimationController` + `Tween` | Pupu scale 3–4s 周期，`Curves.easeInOut` |
| **透明闪烁** | `FadeTransition` / `AnimatedOpacity` | 「和我一起流动」「回返星空」等 |
| **缩放进入** | `ScaleTransition` + `FadeTransition` | 长按 Pupu 进入私人空间 |
| **曲线** | **禁止** `Curves.bounceIn/Out`、`Curves.elastic*` | 统一柔和缓动 |

**动效常量**（建议放入 `constants.dart`）：
- 呼吸周期：3.5s
- 页面过渡：1.5s
- 曲线：`Curves.easeInOut`

---

## 4. 粒子实现方式

| 场景 | 方案 | 技术选型 |
|------|------|----------|
| 星空微粒 | `CustomPainter` | 有限数量（约 80–120 点），`canvas.drawCircle`，`shouldRepaint` 精细控制 |
| 星点闪烁 | `AnimationController` + 随机相位 | 每颗星独立 opacity 变化，复用同一 controller 时间轴 |
| 流星 | 单独 `CustomPainter` 或叠加层 | 随机间隔（约 15–30s）触发，单条直线轨迹 + fade |
| 水面波纹 | `CustomPainter` + 正弦波 | 2–3 层波纹，相位差产生层次感 |
| 银河/星云 | `CustomPainter` + 渐变 + 低 opacity 点云 | 极慢位移（每帧 <0.5px） |

**性能策略**：
- 粒子数量控制在 150 以内
- `CustomPainter.shouldRepaint` 仅在时间/相位变化时返回 `true`
- 使用 `RepaintBoundary` 隔离粒子层与主 UI

### 4.1 首版简化动效策略（已确认）

| 策略 | 首版实现 |
|------|----------|
| 粒子数量 | 约 40–60 颗星，不实现流星 |
| 水面波纹 | 1–2 层简化波纹 |
| 银河/星云 | 仅渐变背景 + 极少量点，不做复杂星云 |
| 闪烁 | 仅关键文案（「和我一起流动」「回返星空」），星点闪烁可选关闭 |
| 目的 | 保证低端机流畅，后续版本可逐步增强 |

---

## 5. 玻璃质感（Glassmorphism）

| 组件 | 实现 |
|------|------|
| 档案页玻璃层 | `ClipRRect` + `BackdropFilter` + `ImageFilter.blur(sigmaX: 8, sigmaY: 8)` |
| 半透明填充 | `Colors.white.withOpacity(0.08)` 配合宇宙背景 |
| 边框 | `Border.all(color: Colors.white24, width: 0.5)` |

**性能**：
- `sigma` 建议 6–10，避免全屏大范围模糊
- 用 `ClipRRect` 限制模糊区域
- 避免多层 `BackdropFilter` 嵌套

---

## 6. Supabase 数据结构

### 6.1 现有

| 表 | 用途 |
|----|------|
| `user_backups` | 用户数据 JSON 备份（records + entries） |

### 6.2 需新增（UI-001）

| 资源 | 用途 | 结构 |
|------|------|------|
| **Storage Bucket** | 私人空间附件 | `private-attachments` |
| **RLS** | 用户仅能读写自己的文件 | `storage.foldername(name)[1] = auth.uid()` |

**附件路径约定**：`{user_id}/{entry_id}/{filename}`

**Migration 示例**：

```sql
-- Storage bucket（在 Supabase Dashboard 创建或通过 API）
INSERT INTO storage.buckets (id, name, public)
VALUES ('private-attachments', 'private-attachments', false);

-- RLS：用户只能访问自己路径下的文件
CREATE POLICY "Users can manage own attachments"
ON storage.objects FOR ALL
USING ( (storage.foldername(name))[1] = auth.uid()::text )
WITH CHECK ( (storage.foldername(name))[1] = auth.uid()::text );
```

### 6.3 PrivateEntry 附件字段

```dart
// 新增
List<String> attachmentUrls;  // Supabase Storage 公开 URL 或 signed URL
```

`user_backups` 的 `data.entries` 中对应条目的 `attachment_urls` 存 URL 列表。

---

## 7. 本地存储（保持不变）

| 项 | 方案 |
|----|------|
| 引擎 | Hive |
| Box | `bowel_records`、`private_entries` |
| 序列化 | JSON string，手动 `toJson`/`fromJson` |

---

## 8. 音频

| 项 | 决策 |
|----|------|
| 依赖 | **audioplayers** |
| 功能范围 | **仅本地音频播放 + 淡入淡出**，不做复杂控制（均衡器、循环模式等） |
| 资源 | 内置 `assets/audio/`（白噪音、轻音乐） |
| 计时页 | 进入时音量淡入 1.5s，退出时淡出 |
| 未配置 | 无音频资源时静默，不阻塞流程 |

---

## 9. 性能优化策略

| 层级 | 策略 |
|------|------|
| **粒子/背景** | `RepaintBoundary` 包裹，`shouldRepaint` 严格控制，粒子数量可配置 |
| **列表** | 档案页用 `ListView.builder` 懒加载 |
| **图表** | 当前主要使用 `CustomPainter`；保留轻量绘制策略，避免不必要依赖 |
| **图片** | 附件缩略图用 `cached_network_image`，占位图优先 |
| **导航** | 避免重复 push 同一页面，必要时 `popUntil` 或 `pushReplacement` |
| **首版** | 采用简化动效策略（见 4.1），减少粒子、无流星 |

---

## 10. 依赖汇总（新增/变更）

| 包 | 用途 | 版本建议 |
|----|------|----------|
| `flutter_riverpod` | 状态管理 | ^2.6 |
| `audioplayers` | 计时页音频（本地 + 淡入淡出） | 最新 stable |
| 无新增 | 粒子/波纹 | 自实现 `CustomPainter` |

**已移除依赖（ARCH-001）**：
- `fl_chart`
- `pdf`
- `csv`
- `excel`
- `share_plus`
- `device_preview`

---

## 11. 文件结构建议

```
lib/
├── core/
│   ├── constants.dart      # 常量（已清理未引用 MVP 遗留项）
│   └── widgets/            # 公共 UI（如 liquid glass）
├── providers/
│   ├── records_provider.dart
│   ├── entries_provider.dart
│   ├── audio_provider.dart
│   └── home_audio_provider.dart
├── features/
│   ├── home/               # 主页面
│   ├── timer/              # 计时流程
│   ├── archive/            # 记录档案
│   └── private_space/      # 私人空间
├── models/
├── services/
└── ...
```

---

## 12. 已确认项

- [x] 本阶段引入 Riverpod
- [x] 音频：audioplayers，仅本地播放 + 淡入淡出
- [x] 首版采用简化动效策略
