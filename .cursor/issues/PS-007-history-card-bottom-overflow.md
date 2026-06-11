# PS-007: Private Space — History 卡片底部溢出（BOTTOM OVERFLOWED）

**Type:** Bug | **Priority:** Normal | **Effort:** Small–Medium

**Labels:** `private-space` `history` `layout` `regression`

**Status:** Done ✅

**Progress:** `100%`

**Related:** PS-001（mixed blocks 编辑器）、PS-006（editor 滚动，不涉及 History）

---

## TL;DR

Private Space 保存含**文字 + 图片**（或语音）的笔记后，进入 **RECORDS** 历史页，卡片底部出现 Flutter 调试条：`BOTTOM OVERFLOWED BY X PIXELS`（截图中 174px / 5px）。根因是 swipe 卡片**固定高度 110px**，与 `HistoryMixedContentPreview` 的动态内容（多行文字 + 全宽图片）高度不匹配。

---

## Current vs Expected

| # | 当前 | 预期 | 状态 |
|---|------|------|------|
| 1 | 含图片/语音的 entry 在 History 列表卡片内垂直溢出，显示黄黑条纹 debug banner | 卡片完整展示预览内容，无 overflow | 🟩 |
| 2 | 纯文字 entry 也可能因 3 行文字 + header 轻微溢出（~5px） | 文字-only 卡片高度自适应或裁剪合理 | 🟩 |

---

## 根因（已确认）

1. **`_SwipeRevealCard` 固定高度 110px** — `private_space_screen.dart` L1616–1617：`SizedBox(height: 110)` 包裹整张 history 卡片，为 swipe 操作区对齐而设，未考虑 mixed content。
2. **`HistoryMixedContentPreview` 内容可远超 110px** — `private_note_blocks.dart` L267–311：
   - 最多 3 行文字（`height: 1.5`）
   - 图片使用全宽 `AspectRatio(aspectRatio: 1.55)`，在 ~340px 宽下约 **220px** 高
   - 另含 header 行（日期/分类）+ card padding（上下各 12px）
3. **无裁剪/约束** — `_HistoryEntryCard` 内 `Column` 直接嵌套 preview，未 `ClipRect`、未 `Flexible`/`Expanded`、未限制图片 thumbnail 高度。

**溢出量级验证（与截图一致）：**
- 文字 + 图片 entry → 溢出 ~174px（内容总高约 284px vs 110px 容器）
- 长文字 + 图片 entry → 溢出 ~5px（边缘 case）

---

## 实现摘要

- [x] 🟩 `_SwipeRevealCard`：移除固定 `height: 110`，改为 `ClipRRect` + 内容驱动高度的 `Stack`（`clipBehavior: Clip.hardEdge`）
- [x] 🟩 `HistoryMixedContentPreview`：图片改为 56px 高缩略图（`BoxFit.cover`），列表仅作摘要
- [x] 🟩 新增 widget 测试：文字+图片 / 长文字预览无 layout exception

---

## 改动文件

| 文件 | 动作 |
|------|------|
| `lib/features/private_space/private_space_screen.dart` | `_SwipeRevealCard` 动态高度 + clip |
| `lib/features/private_space/private_note_blocks.dart` | History 图片缩略图 56px |
| `test/history_mixed_content_preview_test.dart` | 新增 2 条 layout smoke test |

---

## 验收标准

- [x] 🟩 含文字 + 1 张图片的 entry 在 RECORDS 页**无** overflow banner
- [x] 🟩 含文字 + 语音的 entry 正常显示（voice bubble 高度未改，卡片随内容增高）
- [x] 🟩 纯文字 entry（1–3 行）正常显示
- [x] 🟩 左滑 reveal（pin / share / delete）仍可用，背景与卡片等高
- [x] 🟩 `flutter test test/history_mixed_content_preview_test.dart` 通过

---

## 风险 / 注意

- 列表项高度不一致，属预期；真机需回归左滑 reveal 对齐
- History 列表图片为 56px 摘要，完整图在编辑页查看

---

## 非目标

- 不改 entry 存储 schema
- 不重做 History 卡片视觉设计（分类色、日期格式等）
- 不处理 editor 内滚动问题（见 PS-006）
