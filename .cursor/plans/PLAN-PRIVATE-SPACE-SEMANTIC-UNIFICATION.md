# Private Space 语义统一与光标稳定性重构计划

**目标状态：** Stage 9（笔记撤销/重做 + 选区菜单）已完成

---

## Stage 9：笔记编辑撤销/重做 + 选区菜单（2026-05-31）

**整体进度：100%**

| 任务 | 状态 |
|------|------|
| Controller 撤销栈（≥20 步）+ `_HistoryEntry` | 🟩 Done |
| 覆盖全部编辑动作（输入/删/贴/切/图/音/移动/重排） | 🟩 Done |
| 右上角 undo / redo / check 同一行布局 | 🟩 Done |
| TextField 系统默认选区菜单 + 语义 copy/cut/paste | 🟩 Done |
| Controller 撤销/重做回归测试 | 🟩 Done |

---

## 当前执行进度（交接给下一个 agent）

> 更新时间：2026-05-30（本轮执行后，Stage 6 已完成低风险收口，Stage 7 controller 回归已补强，Stage 8 已开始第一轮历史兼容与冗余分支清理）

### 已完成（可视为 Done）

1. **Stage 1（统一语义描述层）已基本落地（controller/model 侧）**
   - 已基于 `semanticLength` / `isEmbed` / `isText` 建立统一 segment 语义使用方式。
   - embed 语义长度按 `1` 参与线性定位。

2. **Stage 2（定位与删除主路径）核心能力已落地**
   - 已存在并使用线性映射：`_linearOffsetForCaret` / `_caretForLinearOffset`。
   - 删除后恢复已统一到通用恢复路径（不再完全依赖旧特判兜底）。
   - 已具备跨 segment 的语义删除能力：`deleteSelectionBySemanticRange()`。

3. **Stage 3（焦点竞态隔离）已完成关键防护**
   - editor 侧已有 generation 防 stale 回调机制。
   - `onTextSelectionChanged` 已保留 focused field 保护，避免旧节点迟到回调污染 caret。

4. **Stage 4（复制/粘贴/剪切统一）已完成第一轮主路径收口（Next-1/2）**
   - controller 已新增跨 segment cut 主路径：先提取语义区间内容，再执行 `deleteSelectionBySemanticRange()`。
   - 已具备“按语义区间提取可复制内容”（MVP 纯文本降级，embed 占位输出）。
   - 已新增统一 copy 入口：`copySelectionBySemanticRangeToClipboard()`。
   - `PrivateSpaceTextSelectionControls.handleCopy/handleCut` 已支持优先走 controller 语义 copy/cut 回调（成功则短路）。
   - paste 在 selection replace 场景下已统一：text/image payload 均遵循“先删选区再插入”。
   - internal clipboard 优先级已明确：image payload > text payload。

5. **Stage 5（selection 桥接）已完成主要 controller/editor 桥接闭环**
   - 引入 `PrivateDocSelectionState(anchorOffset, focusOffset)`。
   - 增加 `startOffset/endOffset` 规范化区间能力，且保留 anchor/focus 方向语义。
   - Backspace/Delete 在 selection 非折叠时已接入语义删除。
   - `pasteTextAtCaret` 已升级为：有语义选区时“先删后贴”（replace selection）。
   - controller 已新增 `setSelectionBySemanticOffsets(...)`，便于测试与后续统一入口接线。
   - editor 已接入 `TextField.onSelectionChanged -> controller.onTextSelectionChanged(...)`，纯拖选/移动光标也会同步语义 selection。
   - editor 已具备 segment 级 selection 高亮占位，用于跨 segment 视觉桥接与回归确认。

6. **测试补齐（Next-3）已完成（controller 侧）**
   - 已新增跨段 cut / paste / selection-replace 回归用例。
   - 已覆盖 external plain text 与 internal payload（image/text）在 selection replace 下的一致性。
   - 已覆盖“image payload 优先于 text payload”的优先级规则。
   - 已补充 embed 边界 / spacer 删除安全性用例，验证删除时不会回退到首位或产生错误空洞。

7. **Stage 6（清理 spacer / 特判）已完成低风险收口**
   - `moveCaretLeft/Right`、text-field 边界移动已切到统一线性 offset。
   - 已删除未使用的 `_previousCaretPosition` / `_nextCaretPosition`。
   - 已删除过渡入口 `ensureTextOpAfterEmbed(...)`，统一保留 `ensureTextOpAt(...)`。
   - embed 邻接空槽位判断已集中为 `_isEmbedBoundaryTextSlot(...)`。
   - 删除恢复主路径已收敛到 `_resolveCaretAfterSegmentRemoval(...)` + 线性 offset 映射。

8. **Stage 7（回归测试与真机验证）controller 自动化回归已补强**
   - 已覆盖连续 embed 反复删除不跳首位。
   - 已覆盖 embed 邻接 newline / 空槽位边界行为。
   - 已覆盖 text-end + Delete 的两步 embed 删除流程。
   - 已覆盖正向/反向 semantic selection 删除、cut、paste replace。
   - 真机软键盘与焦点稳定性仍需人工设备验收。

9. **Stage 8（历史兼容与冗余分支清理）已开始**
   - 已完成第一轮 controller 冗余 helper / 历史兼容路径审计。
   - `_isEmbedOp(...)` 当前仍保留为集中语义入口，避免一次性大面积机械替换带来回归。

### 未完成 / 待继续（In Progress）

1. **Stage 8（历史兼容与冗余分支清理）进行中**
   - 继续清理已经无调用或语义重复的 helper、过时注释和旧兼容描述。
   - 对 `_normalizeOps(...)`、embed boundary slot 等保留兼容层补充清晰注释，明确其是 UI/持久化兼容而非核心 caret 语义依赖。

2. **Stage 7 真机验收仍需人工执行**
   - controller 自动化回归已补强，但软键盘开启状态下的 focus/caret 稳定性仍需真机验证。

---

## 下一步必须执行的计划（给下一个 agent）

### Next-1（最高优先级）
**Stage 8 收尾：继续清理历史兼容与冗余分支**

建议按以下最小闭环推进：
1. 清理仍残留的阶段性/过渡性注释，避免与当前统一语义模型冲突。
2. 继续给必要的兼容层补充明确注释：例如 `_normalizeOps(...)` 中的空 text slot 只是 UI/持久化兼容，不再承担核心 caret 语义。
3. 小步评估是否继续收缩 `_isEmbedOp(...)` 的调用面；若替换为 `op.isEmbed`，必须分批执行并跑 controller 回归。
4. 每删除一个 helper 或分支后，优先检查 controller 级回归用例。

### Next-2
**执行 Stage 7 真机验收**
至少验证：
1. 连续 2~3 个 embed 连续退格删除，光标不跳首位。
2. text-end + Delete 删除右侧 embed 的两步行为稳定。
3. embed 两侧回车不重复插入空槽位。
4. 跨 text+embed 选区 cut/paste 替换正确。
5. 软键盘开启状态下删除/重建后 focus 不被旧节点抢回。

### Next-3
**Stage 8 收尾标准**
- 清理无效注释、废弃 helper、旧兼容路径。
- 将核心规则继续收敛到更少的函数。
- 保持每一轮清理都有对应测试或已有回归覆盖。

---

**计划类型：** 编辑模型统一 + 特殊机制清理 + 焦点竞态收敛

**问题背景：**
当前 `private space` 中 `text` 与 `embed` 并不共享同一套编辑语义，导致删除、选择、粘贴、复制、焦点恢复、重建后的 caret 回填等路径高度分裂。尤其在连续 embed（图片 / 录音）场景中，删除后一条 embed 后，光标在真机上仍可能被 post-frame focus / rebuild / stale callback 竞争抢回到文档首位。现有局部补丁（caret fallback、generation 防护）仍不能从根本上消除问题，因此需要提升为“统一语义 + 统一删除/选择/粘贴模型”的重构方案。

---

## 1. 重构目标

### 1.1 核心目标
1. 让 `text` 与 `embed` 享有统一的编辑语义，成为同一条线性文档流中的两种 segment 表现形式。
2. 将删除、插入、选择、复制、粘贴、左右移动、上下移动等行为统一到一条主路径上。
3. 清除为连续 embed、embed 边界、spacer 文本、embed keyboard proxy、post-frame focus 设计的冗余特殊机制。
4. 从根源上解决删除连续 embed 后，光标被抢回首位的问题。

### 1.2 非目标
1. 不在第一阶段直接全面重写 UI 结构。
2. 不在第一阶段移除所有 `TextField`，而是先让 controller 逻辑先统一，再逐步收敛 editor 层。
3. 不在第一阶段改变 `PrivateEntry` 持久化格式的兼容目标，保持可回滚和可验证。

---

## 2. 关键语义设计

### 2.1 统一 segment 模型
将文档抽象为线性 segment 流：
- `TextSegment`：具有字符长度，支持文本插入、删除、selection。
- `EmbedSegment`：具有固定占位长度（建议逻辑长度 = 1），代表图片或录音等富媒体。

统一规则：
- caret 只存在于 segment 内部或 segment 边界。
- selection 本质上是 caret 的区间化表达。
- 删除/移动/粘贴只围绕 segment 边界进行，不再依赖“embed 专属”分支推断。

### 2.2 推荐 caret 语义
caret 统一为以下几类位置：
1. 文本 segment 内部的字符 offset。
2. embed segment 左边界。
3. embed segment 右边界。

建议尽量避免“空 text spacer 代表光标位”的语义，因为它会把结构补丁伪装成真实文档内容。

### 2.3 删除统一规则
无论是删除 text 还是 embed，都遵循同一套路：
1. 先删除当前 segment 或选区。
2. 如果当前 caret 被删掉，则移动到最近的可编辑边界。
3. 若左侧无可编辑边界，则尝试右侧。
4. 若仍无可编辑边界，再回退到文档起点。

---

## 3. 当前代码的相关影响面

### 3.1 高相关文件
1. `lib/features/private_space/private_note_document_controller.dart`
   - caret 计算、删除、插入、focus、buildDocument、normalize、spacer 处理都集中在此。
2. `lib/features/private_space/private_note_editor.dart`
   - TextField / embed proxy / post-frame focus / onTextFocus / rebuild 触发。
3. `lib/features/private_space/private_space_clipboard.dart`
   - 剪贴板 payload 与富媒体复制/粘贴定义。
4. `lib/features/private_space/private_space_text_selection.dart`
   - 选区行为是否包含 embed 的边界语义。
5. `lib/features/private_space/private_note_blocks.dart`
   - 文档块渲染与结构表达，未来可能承接统一 segment 的 UI 适配。
6. `lib/features/private_space/private_space_ui.dart`
   - 菜单、拖拽、长按、复制/剪切/删除动作入口。

### 3.2 间接相关文件
1. `lib/features/private_space/private_space_screen.dart`
   - 保存、加载、编辑入口的状态流转。
2. `lib/features/private_space/entry_edit_screen.dart`
   - 编辑器生命周期、页面焦点、离开页面保存与恢复。
3. `lib/models/private_note_document.dart`
   - document schema、anchor、ops 兼容。
4. `lib/models/private_entry.dart`
   - 富媒体数据与 document 持久化。

---

## 4. 风险评估

### 4.1 语义统一带来的收益
1. 连续 embed 删除光标跳首位问题可从根上减少。
2. 删除、移动、复制、粘贴的规则更一致。
3. 不再依赖 spacer 文本、embed 右侧假 caret、复杂 fallback。
4. 更容易做跨段选择、混合内容复制、混合内容粘贴。
5. 真机与模拟器在 focus 时序上的差异影响会下降。

### 4.2 主要风险
1. **Selection 语义变化风险**：
   - 当前 selection 与 `TextField` 深度绑定，统一语义后需要桥接层。
2. **IME/软键盘兼容风险**：
   - 直接改为 segment 逻辑后，文本输入法 composition 行为需要验证。
3. **历史兼容风险**：
   - 旧 document 的 anchor、旧 ops、旧空文本 spacer 可能需要兼容读取。
4. **焦点回调竞态风险**：
   - 若只改模型不改 editor 层，旧回调仍可能覆盖 caret。
5. **渲染与交互回归风险**：
   - embed 仍需保留拖拽、长按、全屏、播放等既有交互。

### 4.3 风险控制原则
1. 先统一 controller 逻辑，再逐步收敛 editor 交互。
2. 先保留兼容层，后删冗余特殊机制。
3. 每一步都保留回滚点，不做“一步到位大爆炸重构”。
4. 每次移除一个特殊机制，都必须确认有统一语义替代。

---

## 5. 推荐执行顺序（最高优先级在前）

> 这是本次重构的关键部分。建议严格按顺序推进，不建议跳步。

### Phase A：建立统一语义骨架
**目标：** 先让 controller 有统一的 segment/caret 认知，但暂不大改 UI。

#### A1. 明确 segment 语义
- 将 `PrivateDocTextOp` / `PrivateDocImageOp` / `PrivateDocVoiceOp` 统一看作 segment。
- 引入统一的“逻辑长度”概念。
- 统一 caret 边界定义。

#### A2. 统一 caret 映射入口
- 所有 caret 计算收敛到统一映射函数。
- 不再让 embed 删除、文本删除、上下移动各自独立定义“最近位置”。

#### A3. 统一删除恢复策略
- 删除后 caret 恢复只保留一套规则。
- 连续 embed 删除时优先落到最近左侧 embed 右边界，而不是默认回退到 0。

#### A4. 保留兼容
- 先保留 `TextField` 架构，不立刻移除。
- 允许旧逻辑与新语义并存一段时间，以便逐步验证。

---

### Phase B：收敛 editor / focus 行为
**目标：** 解决真机上的焦点竞争，阻断旧 callback 抢回首位。

#### B1. 收敛 post-frame focus
- 审核所有 `addPostFrameCallback`。
- 仅保留与统一语义直接相关的焦点恢复。
- 尽量避免 widget 层主动“纠正”caret。

#### B2. 引入 generation / version 约束
- 每次结构编辑递增 generation。
- 延迟回调执行前校验 generation。
- 避免旧 TextField、旧 FocusNode、旧 frame callback 写回 caret。

#### B3. 统一 onTextFocus 的职责
- `onTextFocus` 只负责报告真实聚焦，不负责抢救性重置状态。
- 必须避免 stale field 的迟到回调覆盖新 caret。

#### B4. 让 embed focus 成为被动行为
- embed 不应通过抢占式 focus 影响文档第一位。
- 若保留 keyboard proxy，只保留“保活键盘”的职责，不承担 caret 语义。

---

### Phase C：清除 spacer / 特判 / 假位置
**目标：** 删除冗余特殊机制，减少未来复发点。

#### C1. 移除 spacer 文本作为结构补丁的依赖
- 现有 `''` / `\n` spacer 不再承担“定位 caret”的职责。
- 若需要视觉空隙，交给渲染层。

#### C2. 清理 embed 专属 caret 特判
- 删除“embed 右侧假 caret”“连续 embed 特判”“删除后猜最近 embed”这类逻辑。
- 统一由 segment boundary 处理。

#### C3. 清理多层 fallback
- `_resolveCaretAfterEmbedRemoval`
- `_caretAfterEmbedRemoval`
- `_caretOnLineBeforeEmbed`
- `_tryPreserveCaretAfterEmbedRemoval`

这些函数在新模型下应尽量合并或简化为少量通用边界计算。

#### C4. 清理 embed keyboard proxy 的重责任
- 若统一语义成熟，可减少或移除“透明 TextField 保活键盘”的主导地位。
- 让键盘状态由当前 caret 和交互态决定，而非 proxy 主动抢占。

---

### Phase D：统一复制 / 粘贴 / 选择
**目标：** 让富内容编辑行为与统一语义对齐。

#### D1. 复制
- 复制输出应基于 segment 片段，而非仅文本或仅 embed。
- 对外纯文本复制时允许 embed 降级为占位文本。
- 对内复制保留 embed 完整结构。

#### D2. 粘贴
- 纯文本粘贴：插入 text segment。
- 内部 image 粘贴：插入 embed segment。
- 混合内容粘贴：按 segment 序列恢复。

#### D3. 选择
- selection 应能跨 segment 工作。
- 现有“文本选区不含 embed”的策略应重新评估：
  - 如果继续保留，需明确边界规则；
  - 如果统一跨 segment，需补齐 UI 与剪贴板逻辑。

#### D4. 删除与复制剪切的协同
- 剪切本质上是“复制 + 删除”，删除规则应和统一语义共用。

---

## 6. 具体实施步骤建议

### Step 1：建立语义说明与映射表
先在代码注释或计划中明确：
- segment 类型
- caret 类型
- selection 类型
- 删除恢复规则
- 复制 / 粘贴行为

这一步是为了避免后续实现中再次引入含糊语义。

### Step 2：先改 controller，不动 UI 大结构
优先收敛：
- caret 计算
- 删除恢复
- 文档 normalization
- buildDocument / anchor
- 统一 op/segment 映射

### Step 3：再收敛 editor 的焦点触发
处理：
- `onTextFocus`
- `Focus(onKeyEvent)`
- `addPostFrameCallback`
- `requestFocus` / `unfocus`
- embed keyboard proxy

### Step 4：迁移复制 / 粘贴 / 剪切到统一 segment 模型
处理：
- `private_space_clipboard.dart`
- `pasteTextAtCaret`
- `tryPasteImageFromClipboardText`
- 图片 copy/cut/paste

### Step 5：清理 spacer 和特殊分支
当统一模型稳定后，再逐步删除：
- 空文本 spacer 的结构职责
- 连续 embed 特判
- 复杂 fallback
- 旧兼容路径

### Step 6：补测试与真机回归
至少验证：
1. 连续 embed 删除。
2. embed + text 相邻删除。
3. 删除后连续 backspace。
4. 复制 / 粘贴图片与纯文本。
5. selection 跨段行为。
6. 真机软键盘开启状态下的 focus 稳定性。

---

## 7. 验收标准

### 7.1 功能正确性
- 删除连续 embed 不再跳回首位。
- 光标始终落在最近合理位置。
- 复制 / 粘贴行为符合统一语义。
- selection / deletion / keyboard 行为一致。

### 7.2 稳定性
- 真机与模拟器表现一致。
- 不再依赖脆弱的 post-frame focus 竞争。
- rebuild 后不出现旧 callback 覆盖新 caret。

### 7.3 可维护性
- embed 特判显著减少。
- spacer 结构补丁减少或消失。
- caret 逻辑集中于少数函数，而不是散落在 editor 各处。

---

## 8. 回滚策略

如果某阶段改动导致回归，建议按以下顺序回滚：
1. 先回滚 editor 层焦点调整。
2. 保留 controller 统一语义。
3. 再回滚复制 / 粘贴路径的统一。
4. 最后再回滚 segment 抽象层。

这样可以保证核心文档数据不被破坏，同时保留排查空间。

---

## 9. 最终建议

**推荐策略：渐进式统一语义，而不是一次性全面重构。**

最佳顺序是：
1. 先统一 controller 的 segment/caret 语义；
2. 再收敛 editor 的 focus 和 post-frame 行为；
3. 再统一 copy / paste / selection；
4. 最后删除 spacer 与 embed 特判。

这是在当前代码基础上风险最低、可验证性最高、也最有可能彻底解决连续 embed 光标跳首位问题的方案。

---

## 10. 更细的开发任务拆分（建议执行清单）

> 下面按“最佳编译 / 逻辑依赖顺序”拆分为可执行任务。建议一次只推进一个小阶段，完成后再进入下一阶段。

### Stage 0：冻结语义并建立基线
1. 梳理当前所有与 private space 相关的删除、复制、粘贴、选择、focus、caret 入口。
2. 明确当前行为基线：连续 embed 删除、embed 与 text 相邻删除、复制 embed、粘贴 embed、文本选区删除等。
3. 将这些基线行为记录为回归测试目标，避免重构过程中“看起来修好了但引入别的问题”。

### Stage 1：引入统一语义描述层
1. 为文档 segment 建立统一术语：text segment、embed segment、caret boundary、selection range。
2. 明确 embed 的逻辑长度 = 1，text 的逻辑长度 = 字符长度。
3. 明确 caret 只允许落在 segment 内部或边界，不再依赖 spacer 文本表达位置。
4. 在 controller 代码中统一注释与命名，减少“文本逻辑”和“embed 逻辑”两套世界观并存。
5. 在 model 层补齐 `semanticLength` / `isEmbed` / `isText` 等基础语义接口，作为后续统一删除、复制、粘贴、选择的前提。

### Stage 2：统一 controller 的定位与删除主路径
1. 收敛 caret 计算入口，减少散落在多个函数中的近似定位逻辑。
2. 将删除后 caret 恢复规则统一为：当前位 → 左侧最近可编辑边界 → 右侧最近可编辑边界 → 文档起点。
3. 删除连续 embed 时，不再通过空文本 spacer 兜底，而是直接按 segment 边界恢复。
4. 保留兼容实现，但将旧分支标注为“待删除的过渡逻辑”。

### Stage 3：梳理并隔离 editor 的焦点行为
1. 梳理 `private_note_editor.dart` 中所有 `requestFocus`、`unfocus`、`postFrameCallback`、`setState` 的触发链。
2. 将“展示层重建”和“caret 语义更新”分离，防止 rebuild 顺带重置光标。
3. 对旧 callback 增加版本或 generation 保护，确保延迟回调不覆盖新 caret。
4. 约束 embed keyboard proxy 的职责，仅保留必要保活功能，不允许其主导 caret 位置。

### Stage 4：统一复制 / 粘贴 / 剪切的数据流
1. 把复制视为“复制 segment 片段”，而不是仅复制纯文本或仅复制 embed。
2. 定义纯文本降级规则：embed 在文本输出中如何表示（例如 `[Image]`、`[Voice 12s]`）。
3. 定义富内容复制规则：内部 copy/paste 是否保留 embed 原始 payload。
4. 将文本粘贴、图片粘贴、内部剪贴板粘贴收敛到统一插入入口。
5. 检查剪切是否可直接复用“复制 + 删除”的统一语义。

### Stage 5：处理 selection 语义统一
1. 明确当前 selection 是否继续保留文本字段内的原生 selection，还是升级为跨 segment range。
2. 如果保留原生 TextField selection，则建立 text ↔ segment selection 的桥接层。
3. 如果升级为统一 selection，则补齐跨 embed 的拖拽、键盘选区、复制剪切行为。
4. 先保证简单边界正确，再逐步处理复杂跨段选择。
5. 当前已完成 controller selection state、跨段复制/剪切/删除/替换的主路径，下一步优先做可视化桥接与交互补齐。

### Stage 6：清理 spacer 与 embed 特判
1. 删除或弱化空文本 spacer 作为结构补丁的职责。
2. 逐步移除 `_caretOnLineBeforeEmbed`、`_resolveCaretAfterEmbedRemoval` 这类“猜最近位置”的辅助兜底，改为统一 boundary 计算。
3. 删除 embed 专属的假 caret 分支和连续 embed 特判。
4. 让视觉间距由渲染层承担，而不是由文档结构承担。
5. 当前已开始收敛边界相关路径，并为 spacer / embed 删除安全性补测试，后续继续逐步缩小特判面。

### Stage 7：回归测试与真机验证
1. 连续 embed 插入 / 删除 / 反复删除。
2. embed 与 text 相邻时的删除、左右移动、回车、退格。
3. 复制 / 粘贴图片、复制 / 粘贴文本、混合内容粘贴。
4. selection 跨段复制与删除。
5. 真机上软键盘开启状态下的 focus 稳定性与 caret 稳定性。
6. 保存 / 重新进入页面后 lastCursorAnchor 是否稳定恢复。

### Stage 8：清理历史兼容与冗余分支
1. 在新语义验证稳定后，删除过渡期特判逻辑。
2. 清理无效注释、废弃 helper、旧兼容路径。
3. 将核心规则收敛到更少的函数，降低未来回归概率。
4. 更新注释与开发文档，确保后续维护者理解统一语义模型。

### Stage 9：风险检查与回滚预案
1. 每个 stage 完成后先做最小验收，不通过则不进入下一阶段。
2. 若出现回归，优先回滚 editor 层，再回滚 clipboard / selection 层，最后才回滚 controller 语义层。
3. 保留阶段性 commit 或可识别的 diff 边界，方便快速定位问题。

---

## 11. 执行原则补充

1. **先统一逻辑，再删特判。** 不要在旧模型上直接删除大量兼容代码。
2. **先 controller，后 editor。** 先收敛语义，再解决交互和焦点。
3. **先稳定删除，再扩展复制/选择。** 删除是根问题优先级最高的入口。
4. **任何新规则都必须有回退路径。** 不能一次性移除所有特殊机制。
5. **避免多点同时改动。** 每个阶段尽量只解决一类问题，以便编译和回归定位。
