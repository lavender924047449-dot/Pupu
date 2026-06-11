# UI-001 宇宙主题重构实施计划

**Overall Progress:** `90%`

## TLDR

将 Pupu 从 Tab 导航改为以星空主页面为核心入口，左下光点进入档案、长按 Pupu 进入私人空间、点击「和我一起流动」进入计时。采用 Riverpod、深夜宇宙主题、简化动效、玻璃质感、audioplayers 淡入淡出。

---

## Critical Decisions

- **Riverpod** — 本阶段引入，provider 分层初期设计
- **简化动效** — 40–60 星、无流星、1–2 层波纹
- **audioplayers** — 仅本地播放 + 淡入淡出
- **Pupu** — 首版占位图

---

## Tasks

- [x] 🟩 **Step 1: 基础设施**
  - [x] 🟩 添加 flutter_riverpod、audioplayers 依赖
  - [x] 🟩 main.dart 包裹 ProviderScope
  - [x] 🟩 新建 lib/providers/ 目录，创建 6 个 provider 骨架（app、records、entries、timer、health、audio）
  - [x] 🟩 core/constants.dart 新增宇宙色板、动效时长、静态健康建议文案
  - [x] 🟩 core/theme.dart 替换为宇宙主题

- [x] 🟩 **Step 2: 主页面（星空）**
  - [x] 🟩 新建 HomeScreen，深蓝渐变背景
  - [x] 🟩 星空微粒 CustomPainter（40–60 点，简化版）
  - [x] 🟩 Pupu 占位图 + 呼吸 scale 动画（3.5s 周期）
  - [x] 🟩 上方随机文案、下方闪烁「和我一起流动」
  - [x] 🟩 左下角隐蔽小光点，点击触发档案

- [x] 🟩 **Step 3: 导航与路由**
  - [x] 🟩 移除 app.dart 的 MainTabs、NavigationBar
  - [x] 🟩 主页面为根，计时/档案/私人空间通过 push/ overlay 进入
  - [x] 🟩 页面过渡 1.5s，Curves.easeInOut

- [x] 🟩 **Step 4: 计时页面**
  - [x] 🟩 新建 TimerScreen，深蓝渐变 + 半透明水面层
  - [x] 🟩 水面波纹 CustomPainter（1–2 层）
  - [x] 🟩 手动开始/结束计时，timer_provider 管理状态
  - [ ] 🟥 audioplayers 本地音频 + 进入淡入 1.5s、退出淡出
  - [ ] 🟥 计时中水面浮现温柔字句并消散
  - [x] 🟩 结束：结束语 → 嵌入式简化布里斯托表单 → 保存记录 → 「回返星空」闪烁 → 返回主页

- [x] 🟩 **Step 5: 记录档案（宇宙档案）**
  - [x] 🟩 新建 ArchiveScreen，光点点击后以 overlay/bottomSheet 形式浮现
  - [x] 🟩 半透明玻璃层（BackdropFilter + blur），背景仍为宇宙
  - [x] 🟩 关闭：按钮 + 下滑手势
  - [x] 🟩 四色书签（蓝/灰绿/烟紫/灰蓝）切换内容
  - [x] 🟩 整合 records 列表、健康建议、报告、心理问卷；health_provider 处理有无记录逻辑

- [x] 🟩 **Step 6: 私人空间（银河深处）**
  - [x] 🟩 主页面长按 Pupu 中心 → ScaleTransition + FadeTransition 进入 GalaxyScreen
  - [x] 🟩 深紫渐变、极少量星点
  - [x] 🟩 entries_provider 对接，列表 + 编辑；PrivateEntry 增加 attachmentUrls
  - [ ] 🟥 附件上传（Supabase Storage），未配置时降级提示

- [x] 🟩 **Step 7: 整合与收尾**
  - [x] 🟩 Supabase Storage 迁移文件（002_storage_attachments.sql）
  - [x] 🟩 图表沿用主题色（waterBlue 低饱和）
  - [x] 🟩 core/animations.dart 统一动效常量
