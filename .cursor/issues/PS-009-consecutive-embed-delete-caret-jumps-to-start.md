# PS-009: Private Space — 连续 embed 删除后光标弹回第一行最左侧

**Type:** Bug | **Priority:** Normal | **Effort:** Small–Medium

**Labels:** `private-space` `editor` `caret` `embed` `regression`

**Status:** Open

**Related:** PS-003（连续 embed 布局）、PS-008（单 embed 删除 caret 修复，Done）

---

## TL;DR

连续插入多张图片/语音（embed 相邻、中间无 text op）后，删除其中一个 embed，光标仍会跳到**文档第一行最左侧**。PS-008 已修复「单 embed + 前后 text」场景，但 **embed 簇（cluster）** 的 caret 落点逻辑仍只检查 **紧邻** 邻居，导致 fallback 到 stream offset 0。

---

## Current vs Expected

| #   | 当前                                                       | 预期                                            |
| --- | ---------------------------------------------------------- | ----------------------------------------------- |
| 1   | `[text, img, img, img]` 删除中间 img → 光标跳到文首        | 光标留在 embed 前最近 text 的合理行（如 line3） |
| 2   | `[img, img, img]` 删除中间 img → 光标跳到文首 / 空文档起点 | 光标落在**相邻 embed** 左/右缘（gutter caret）  |
| 3   | 光标在 embed 上 + 菜单/Backspace 删除中间项                | 与键盘删除、单 embed 行为一致，不回弹           |

---

## 根因（已确认）

### 1. `hadTextBefore` / `hadTextAfter` 仅看紧邻 op

`_caretAfterEmbedRemoval` / `_tryPreserveCaretAfterEmbedRemoval`（`private_note_document_controller.dart` L1152–1153、L1193–1196）：

```dart
hadTextAfter = ops[removedIndex + 1] is PrivateDocTextOp;
hadTextBefore = ops[removedIndex - 1] is PrivateDocTextOp;
```

连续 embed 时，删除中间项的 **immediate 前后均为 embed**，两者皆为 `false`。

### 2. `_caretOnLineBeforeEmbed` 遇 embed 邻居直接回文首

L1245–1248：若 `ops[removedIndex - 1]` 不是 text（而是 embed），直接 `return _caretForTextStreamOffset(0)`，**不会**向前扫描找到 `[TextOp 'line1\nline2\nline3']`。

### 3. 最终 fallback 恒为 offset 0

当 `hadTextBefore == false && hadTextAfter == false` 时，`_caretAfterEmbedRemoval` L1237：

```dart
return _caretForTextStreamOffset(0);
```

与截图/报告「第一行最左侧」完全一致。

### 4. PS-008 未覆盖的测试缺口

现有 `consecutive image inserts` 测试（L14）只验证 **插入后 ops 结构**，**无**连续 embed 删除 + caret 断言。

---

## 复现结构（最小）

```
[PrivateDocTextOp('line1\nline2\nline3')]
[PrivateDocImageOp]   // index 1
[PrivateDocImageOp]   // index 2 ← 删除，caret 在 embed 上
[PrivateDocImageOp]   // index 3
```

删除 index 2 → 当前 caret `(0, 0)`；预期 `(0, 12)`（line3 行首）或相邻 embed gutter。

纯 embed：

```
[ImageOp] [ImageOp] [ImageOp]  → 删中间 → 预期 caret 落在剩余 ImageOp 的 textOffset 0/1
```

---

## 改动文件（建议）

| 文件                                                               | 动作                                                                                                                                  |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/private_space/private_note_document_controller.dart` | 新增 `_nearestTextOpBefore` / `_nearestTextOpAfter`（跳过 embed 簇）；`_caretOnLineBeforeEmbed` 向前扫描；embed 间删除 → 落相邻 embed |
| `test/private_note_document_controller_test.dart`                  | +2～3 条：text+连续 img 删中间、纯连续 img 删中间                                                                                     |

---

## 建议修复方向

1. **`_nearestTextOpIndexBefore(removedIndex)`**：从 `removedIndex - 1` 向左跳过 embed，找到最近 text op。
2. **`_nearestTextOpIndexAfter(removedIndex)`**：向右同理。
3. **`_caretOnLineBeforeEmbed`**：用 nearest text index 替代 `removedIndex - 1`；若无 text 再考虑相邻 embed。
4. **Embed 簇内删除**：若前后均为 embed → `PrivateDocCaret(opIndex: neighborIndex, textOffset: 0|1)`（删中间偏左落前 embed 右侧，偏右落后 embed 左侧，或与 `preferAdjacentAfter` 对齐）。
5. **勿回归 PS-008**：单 embed + text 用例保持通过。

---

## 验收标准

- [ ] `[text, img×3]` 删中间 img，caret 不在 stream offset 0
- [ ] `[img×3]` 删中间 img，caret 落在剩余 embed gutter
- [ ] 菜单 Delete / Backspace / Cut 路径一致
- [ ] `flutter test test/private_note_document_controller_test.dart` 全通过

---

## 风险 / 注意

- 删除后 opIndex 会重排，相邻 embed 索引需基于 **removal 后** 的 `_document.ops` 计算
- 与 PS-005 两步 Backspace、PS-004 edge caret 勿冲突
- 连续 embed 后的 `_wrapEmbedWithTrailingTextSlot` gap 行为需手动回归

---

## 非目标

- 不改 History / schema
- 不恢复 embed 拖拽排序
