# PS-003: Private Space — 去除 embed 间强制文本空隙 + 修正条件自动滚动

**Type:** Bug / Improvement | **Priority:** Normal | **Effort:** Medium

**Labels:** `private-space` `editor` `ux` `regression`

**Status:** Done ✅

**Progress:** `100%`

**Related:** Phase 2 收尾（P2-R4 自动滚动）、`PLAN-PRIVATE-SPACE.md`

---

## TL;DR

Private Space 编辑器仍存在「文字块 + 图片块」固定分板块感：连续插入两张图片时，中间会残留空的文字段落占位，破坏纸面一体流式体验。另：自动滚动应在**光标/内容离开可视区域时**才触发，而非每次打字/删除都滚。

---

## Current vs Expected

| # | 当前 | 预期 | 状态 |
|---|------|------|------|
| 1 | 插入 embed 后 `_insertOpAtCaret` / `_ensureTrailingTextOp` 总会追加空 `PrivateDocTextOp('')` | embed 可相邻排列，无强制空文本段 | 🟩 |
| 2 | 连续图片/录音之间仍渲染独立 `TextField` 占位 | 相邻 embed 直接衔接 | 🟩 |
| 3 | `onChanged` 每次调用 `_ensureTextFieldVisible` | 仅当 caret 离开可视区才滚动 | 🟩 |
| 4 | 打字滚动过于敏感/不稳定 | 可见时不滚，不可见时滚回（15px 边距） | 🟩 |

---

## 实现摘要

- [x] 🟩 `_normalizeOps`：合并相邻文本并 strip 空 text op；`buildDocument` 持久化前 normalize
- [x] 🟩 `_insertOpAtCaret`：不再强制插入空 text；空段 split 时省略零长 before/after
- [x] 🟩 连续 embed 插入：caret 落在 embed 上，不再 `_focusLastTextAfterFrame`
- [x] 🟩 `ensureTextOpAt` + embed 间 tap gap：按需 lazy 创建文本段
- [x] 🟩 `_needsScrollIntoView`：viewport + keyboard inset + 15px padding 检测后再 `ensureVisible`
- [x] 🟩 测试：`consecutive image inserts`、`text between images`、`remove merge`

---

## 验收标准

- [x] 🟩 连续插入 2+ 张图片，中间无可聚焦空文字行
- [x] 🟩 图片 → 打字 → 图片：仅有内容处出现文本
- [x] 🟩 光标在可视区内打字/退格不滚动
- [x] 🟩 光标离开可视区时自动滚回
- [x] 🟩 拖 embed 近边缘仍可滚入视区
- [x] 🟩 插入图/录音不触发自动滚
- [x] 🟩 `flutter test` 17/17 通过

---

## 改动文件

| 文件 | 动作 |
|------|------|
| `private_note_document_controller.dart` | normalize、insert caret、lazy text |
| `private_note_editor.dart` | 条件滚动、embed gap、virtual text |
| `private_note_document_controller_test.dart` | 新增 3 用例 |

---

## 风险 / 注意

- embed-only 笔记通过 invisible virtual text field 启动输入
- embed 间点 gap 可 spawn 文本段
- **未改** `resizeToAvoidBottomInset: false`

---

## 非目标

- 不重做 History / 存储 schema
- 不恢复外部贴图
- 不做 iOS 真机专项（可后续单列）
