# PS-002: Private Space — 移除笔画/手写，仅保留键盘 + 语音 + 图片

**Type:** Feature (scope reduction) | **Priority:** High | **Effort:** Medium

**Labels:** `private-space` `editor` `data-model` `breaking-change`

**Status:** Ready for execution ✅

**Supersedes:** [PS-001](PS-001-word-like-notepad-editor.md)（已作废）

---

## TL;DR

从 Private Space 记事能力中**彻底删除笔画/手写**（整页叠加层、画笔底栏、stroke 存储与预览）。输入方式仅保留：**键盘文字**、**语音录音 embed**、**图片 embed**。同步更新 `PLAN-PRIVATE-SPACE.md`，删除相关代码与数据字段；**接受清库**（与 PS-001 一致，不迁移含手写数据的旧笔记）。

---

## Current vs Expected

| # | 当前 | 预期 |
|---|------|------|
| 1 | 计划含 Phase 5「手写与整页叠加层」及多处手写约束 | 计划中无手写 phase/验收项；产品约束仅 keyboard / image / voice |
| 2 | `PrivateNoteDocument.handwritingStrokes`、`handwriting.strokes` JSON | 文档模型无 handwriting 字段 |
| 3 | 底栏含画笔键；画笔模式切换工具条 | 底栏仅：图片、录音（+ 键盘编辑态）；无画笔/手写模式 |
| 4 | `private_handwriting_editor.dart`、`private_fullpage_handwriting.dart` 等 | 文件删除或从构建路径移除 |
| 5 | History 预览显示 Handwriting / stroke 缩略图 | 预览仅 text / image / audio |
| 6 | 本地 Hive 可能存含 strokes 的 note | **一次性清空** Private Entry（或 bump schema 后拒绝旧数据并清 box） |

---

## 产品决策（已定稿）

| 议题 | 决策 |
|------|------|
| 输入方式 | 仅 **键盘**、**语音（录音块）**、**图片** |
| 手写/笔画 | **完全移除**，不保留只读回放 |
| 旧数据 | **清库**，不迁移 `handwriting.strokes` |
| PS-001 | **作废**；以本 issue + 更新后的 `PLAN-PRIVATE-SPACE.md` 为准 |

---

## Relevant Files

| 文件 | 改动 |
|------|------|
| `PLAN-PRIVATE-SPACE.md` | 删除 Phase 5、手写约束、验收项、文件索引中的手写行 |
| `lib/models/private_note_document.dart` | 移除 `handwritingStrokes` 与 JSON `handwriting` |
| `lib/models/private_entry.dart` | 移除 `PrivateStroke*` 类型（若无其他引用） |
| `lib/features/private_space/private_space_screen.dart` | 移除画笔底栏、全页画布、`setHandwritingStrokes` |
| `lib/features/private_space/private_note_document_controller.dart` | 移除 handwriting API |
| `lib/features/private_space/private_handwriting_editor.dart` | **删除** |
| `lib/features/private_space/private_fullpage_handwriting.dart` | **删除** |
| `lib/features/private_space/private_note_blocks.dart` | 移除手写 block / 预览 |
| `lib/features/private_space/private_space_block_widgets.dart` | 移除 `PrivateBlockType.handwriting` UI |
| `test/private_note_document_test.dart` | 更新/删除 stroke 相关用例 |

---

## Technical Notes / Risks

- **Breaking change**：发版说明需注明 Private Space 本地笔记将被清空。
- **清库实现**：复用 PS-001 思路 — `schema_version` bump 或启动时检测 legacy handwriting 字段 → `Hive.box` clear；避免半迁移状态。
- **底栏状态机简化**：删除「画笔模式 ↔ 键盘模式」互斥逻辑，降低 `private_space_screen.dart` 复杂度。
- **回归**：图片内联、录音插入、文本流式编辑、Phase 2.5 偏差修复项不得回退。
- **PS-001 文档**：在文件头标记 `Status: Superseded by PS-002`，避免执行冲突。

---

## Acceptance Criteria

- [ ] `PLAN-PRIVATE-SPACE.md` 无手写/笔画/Phase 5 残留引用
- [ ] 编辑器底栏无画笔入口；无法进入手写模式
- [ ] `PrivateNoteDocument` 序列化/反序列化不含 `handwriting`
- [ ] 手写相关 Dart 文件已删除且无 dead import
- [ ] 启动或升级后 Private Entry 清库策略生效（旧含 strokes 数据不可见）
- [ ] History 列表预览不出现 Handwriting 占位
- [ ] 键盘输入、图片插入/粘贴、录音插入仍可用
- [ ] 相关单元/ widget 测试通过

---

## Implementation Phases

| Phase | 内容 | 体量 |
|-------|------|------|
| **1** | 更新 `PLAN-PRIVATE-SPACE.md`；作废 PS-001 文首状态 | S |
| **2** | 模型层移除 handwriting；schema bump + 清库逻辑 | M |
| **3** | 删手写 UI/文件；收口 `private_space_screen` 底栏 | M |
| **4** | History/预览/测试清理 + 全量 QA | S |

---

## 下一步

从 Phase 1 更新计划文档开始，再 Phase 2 模型与清库（避免先删 UI 导致编译引用断裂）。
