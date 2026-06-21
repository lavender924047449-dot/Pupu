# PLAN-SESSION-SUMMARY-001: Session Summary 垂直居中 + 滚动

**进度：90%**

## 需求

- 暖心引导语固定顶部（不随滚动）
- `Session Summary:` → `Maybe Later` 在引导语**以下空间**垂直居中
- 引导语与居中块之间保留 20px 间距
- 引导语以下区域可滚动（溢出兜底）
- 保留 `ctaGap`、`SafeArea`、文案/样式/动画

## 步骤

- [x] 🟩 **Step 1**: 重构 `_SessionSummaryBody` 布局（固定头 + Expanded 居中滚动区）
- [x] 🟩 **Step 2**: `flutter analyze` 验证（无 error）
- [ ] 🟨 **Step 3**: 手工验收清单（待真机/模拟器）

## 文件

| 文件 | 变更 |
|---|---|
| `lib/features/timer/widgets/timer_session_summary.dart` | 布局重构：`_buildSummarySection`、`_buildCtaSection`、`_buildCenteredScrollableSummary` |

## 实现摘要

```
Column
├── SizedBox(32) + everyMoment（固定，不滚）
├── SizedBox(20)
└── Expanded
    └── LayoutBuilder → SingleChildScrollView
        └── ConstrainedBox(minHeight: 剩余视口)
            └── Center
                └── Session Summary + ctaGap + CTA
```

## 验收

- [ ] 常规屏：Session Summary 块在引导语下方区域视觉居中
- [ ] 长引导语：居中区域随引导语高度收缩，中心点重算
- [ ] 说明文展开 / 大字号：下方区域可滚动，引导语不滚走
- [ ] CTA、`ctaGap`、SafeArea 行为不变
