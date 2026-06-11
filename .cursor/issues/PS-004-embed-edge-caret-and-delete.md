# PS-004: Private Space — 图片左右边缘光标 + 删除行为



**Type:** Bug | **Priority:** Normal | **Effort:** Small–Medium



**Labels:** `private-space` `editor` `ux` `regression`



**Status:** Done ✅



**Progress:** `100%`



**Related:** PS-001（Word 式 embed 光标）、PS-003（embed 布局）



---



## TL;DR



点击图片左右边缘时，inline caret 仍不出现；修复后，键盘删除图片目前**仅当光标在图片右侧**（`textOffset == 1` + Backspace）才生效，需调整为两侧均可删除（尤其移动端无 Delete 键）。



---



## Current vs Expected



| # | 当前 | 预期 | 状态 |

|---|------|------|------|

| 1 | 点击图片左/右边缘，无 inline caret 显示 | 左缘 → caret 在 embed 前（`textOffset: 0`）；右缘 → caret 在 embed 后（`textOffset: 1`），可见闪烁光标 | 🟩 |

| 2 | Backspace 仅当光标在图片**右侧**时可删图 | 光标在**左侧**时 Backspace 也应删除该 embed；右侧 Backspace 行为保持不变 | 🟩 |

| 3 | Delete 键仅当光标在图片**左侧**时可删图 | 保持对称：左侧 Delete / 右侧 Backspace 均可删（桌面端） | 🟩 |



---



## 实现摘要



- [x] 🟩 `_wrapEmbedInteractive`：Stack 全幅 overlay + 中心 `IgnorePointer`，左右 52px tap zone 可靠接收手势，不阻断图片 double-tap / long-press

- [x] 🟩 `_embedEdgeTapZone`：caret 微偏移出图缘，提升可见性

- [x] 🟩 `handleDeleteBackwardOnEmbed` / `handleDeleteForwardOnEmbed`：移除 `textOffset` 限制

- [x] 🟩 `_deleteBackwardFromCaret` / `_deleteForwardFromCaret`：embed 任意侧均 `_removeEmbedAt`

- [x] 🟩 测试：edge caret 定位、左/右 Backspace 删图、voice Delete 对称



---



## 验收标准



- [x] 🟩 点击图片左/右边缘，对应位置出现 inline caret

- [x] 🟩 光标在图片左侧，按 Backspace 删除图片

- [x] 🟩 光标在图片右侧，按 Backspace 删除图片（回归）

- [x] 🟩 光标在图片左侧，按 Delete 删除图片（桌面/软键盘若有）

- [x] 🟩 Voice embed 边缘光标与删除行为与图片一致

- [x] 🟩 `flutter test` 通过



---



## 改动文件



| 文件 | 动作 |

|------|------|

| `private_note_editor.dart` | edge overlay hit-test 修复、caret 可见性 |

| `private_note_document_controller.dart` | embed 双侧删除逻辑 |

| `private_note_document_controller_test.dart` | +5 用例 |



---



## 风险 / 注意



- 勿与图片 double-tap（裁剪）/ long-press / drag handle 手势冲突 — 中心区域仍透传至 embed

- 连续 embed 相邻时，左缘 caret 与「embed 间 gap」tap 区域边界需清晰

- 删除后 caret 应落在合理位置（前一 text 末尾或下一 text 开头）



---



## 非目标



- 不改 History / 存储 schema

- 不改 PopupMenu「Delete image」菜单路径

- 不做 iOS 真机专项（除非 edge hit test 仍有问题）

