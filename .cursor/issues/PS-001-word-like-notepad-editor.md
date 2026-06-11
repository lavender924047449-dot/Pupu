# PS-001: Private Space 记事本 — Word 式统一编辑区 + 画笔工具栏

> **Status: Superseded / 已作废** — 手写能力已由产品移除，请以 [PS-002](PS-002-remove-handwriting-from-private-space.md) 与更新后的 `PLAN-PRIVATE-SPACE.md` 为准。下文仅作历史参考。

**Type:** Feature + Bug | **Priority:** High | **Effort:** Large

**Labels:** `private-space` `editor` `ux` `data-migration`

**Status:** ~~Product decisions locked~~ **Cancelled (superseded by PS-002)**

---

## TL;DR

将 Private Space 记事页改为 **单一连续编辑区**（类 Word），并采用 **新文档模型（方案 B）** 存储；**旧笔记不迁移，全部删除**。图片/语音在 **光标处内联**；手写为 **整页任意位置**；画笔模式时底栏切换为工具条（含「键盘」退出）。

**执行计划：** `PLAN-PS-001.md`

---

## 产品决策（已定稿）

| 议题 | 决策 |
|------|------|
| 图片 / 语音 | **当前光标位置内联插入** |
| 手写 | **整页任意位置可画**（画笔模式全页画布层） |
| 存储 | **方案 B：新文档模型**；旧数据 **一次性清空**，无迁移 |
| History | **功能保留**；仅 legacy 数据清空；新保存 note 仍进 History 列表 |
| 编辑区 | 单一大区域；无 hint、无 TextField 独立背景；进入即聚焦 |
| 底栏 | 默认：图 / 画笔 / 录音 → 画笔模式：同色位置展开工具条，最左 **键盘** 退出 |

---

## Current vs Expected

| # | 当前 | 预期 |
|---|------|------|
| 1 | 进入无光标 | 自动聚焦，可立即输入 |
| 2 | hint + 输入框视觉分离 | 与媒体共享同一纸张背景 |
| 3 | 块列表 `_EditorBlockItem` | 连续文档 + 光标定位 + 光标处内联 embed |
| 4 | 画笔工具在内容区，底栏不变 | 底栏三键 ↔ 画笔工具条状态机 |

---

## 新文档模型（方案 B 概要）

**存储字段（`PrivateEntry`）：**

- 新增 `document`（或 `document_ops`）— 主存储
- 保留 `blocks` / `content` 仅作迁移来源；**新写入只写 document**
- `schema_version: 2`（建议）

**Document 结构（建议 Quill-like ops，实现可简化）：**

```json
{
  "schema_version": 2,
  "document": {
    "ops": [
      { "insert": "今天有点累\n" },
      { "insert": { "image": { "id": "...", "path": "..." } } },
      { "insert": "明天再说" },
      { "insert": { "voice": { "id": "...", "path": "...", "duration_ms": 12000 } } }
    ],
    "handwriting": {
      "strokes": [ /* 整页笔画，归一化坐标 0–1 */ ]
    }
  }
}
```

- **文本 + 内联 embed**：顺序由 `ops` 数组表达，光标 = op 内偏移
- **手写**：独立层 `handwriting.strokes`（整页），与文本层叠加显示；不占用「预留块区域」
- **图片上限**：仍按 note 维度最多 30 张（遍历 ops 统计）

**旧数据处理：**

- 检测到 `schema_version < 2` 或仅有 legacy `blocks`/`content` → **清空全部 Private Entry**（Hive box），不尝试转换

---

## Relevant Files

| 文件 | 改动 |
|------|------|
| `lib/models/private_entry.dart` | `PrivateNoteDocument`、schema_version、toJson/fromJson |
| `lib/services/private_document_migrator.dart` | **新建** blocks → document |
| `lib/features/private_space/private_note_document_controller.dart` | **新建** 光标、ops 编辑、内联插入 |
| `lib/features/private_space/private_space_screen.dart` | 替换块列表编辑器；底栏状态机；自动 focus |
| `lib/features/private_space/private_handwriting_editor.dart` | 全页层 + 底部工具条 |
| `lib/features/private_space/private_note_blocks.dart` | 历史预览改为从 document 渲染 |
| `lib/services/local_storage.dart` | 保存 document 字段 |

---

## Technical Notes / Risks

- **Effort 上调**：B 方案含迁移 + 新 controller，整体 **Large+**
- **Flutter**：真·内联 embed 可能需要 `TextSpan` + `WidgetSpan` 或第三方（`flutter_quill` 等）— 选型在 Phase 1 spike
- **触摸**：文本光标 vs 全页手写层 — 画笔模式禁文本 hit-test，键盘模式禁画布
- **回归**：Galaxy/其他引用 `PrivateEntry` 处需读 `document` 或 `plainTextPreview`
- **回滚**：保留 migrator 单元测试；旧字段不删除直至 v2 稳定

---

## Acceptance Criteria

- [ ] 空白页进入 ≤300ms 光标可见，键盘可输入
- [ ] 无 hint / 无独立输入背景
- [ ] 图片、语音在光标处内联出现
- [ ] 画笔模式：整页可画；底栏为工具条；键盘图标恢复三键
- [ ] 旧 `blocks[]` note 打开后内容完整，保存后带 `schema_version: 2`
- [ ] 图片 ≤30、语音单实例播放、权限流不变

---

## Implementation Phases

| Phase | 内容 | 体量 |
|-------|------|------|
| **1** | `PrivateNoteDocument` 模型 + migrator + 存储；历史只读渲染 | M |
| **2** | 连续编辑区 + 自动 focus + 去 hint/背景；底栏三键 ↔ 画笔条 | M |
| **3** | 光标定位 + 光标处插入 image/voice | L |
| **4** | 全页手写层 + 与键盘模式互斥 | M |
| **5** | 删除旧 `_EditorBlockItem` 路径；迁移测试 + QA | S |

---

## 下一步

按 Phase 1 起执行；Phase 1 结束前完成 embed 技术 spike（自研 WidgetSpan vs `flutter_quill`）。
