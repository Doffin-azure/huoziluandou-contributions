# 活字战斗（Huozi）

> 4×4 字盘上的拼词构筑 Roguelike。玩家管理一袋会循环出现的**实体汉字**，按**四邻接**连线拼出真实中文词语，以词义触发攻击、防御、改盘、补字、储能、热度、经济等效果；战后通过加字 / 删字 / 复制 / 镀金改变自己的「可组词概率」，完成 **3 幕 × 8 节点**的冒险。

引擎：**Godot 4.7（stable）· GDScript**。所有内容为数据驱动（`Resource`），美术为程序化着色器，无外部贴图。

---

## 特性

- **字盘策略**：4×4、四邻接、可转弯、同路径不重复格；非法多字路径**不消耗、不扣次数**；单字「出牌 = 弃字」；出字后**不自动补满**；**无固定出字次数上限**。
- **内容规模**：**154 个词全部实现**（GDD 总账 99 + 新增/彩蛋 55），**61 个实体字**。
- **六大系统**：防反（临挡 / 持久盾 / 反击）、连携（合击 / 重合 / 连击 / 重复）、流转（回流 / 回收 / 回转 / 反转）、储能（充电 / 放电 / 蓄力 / 合资）、热度（加速 / 火爆 / 过载 / 冷却）、经济（金币 / 临时资金 / 股权 / 镀金）。
- **空间机制**：融合（化合）、叠层（重合 / 精炼）、临时牌（分化 / 再铸 / 铸币）、揭示与定点改造（转化 / 投放 / 精铸）。
- **局内循环**：3 幕 × 8 节点 = 24 节点，含普通战 / 事件 / 商店 / 岔路（精英或事件）/ 休整 / Boss，12～15 场战斗。
- **两套可切换视觉风格**：`宣纸活字`（传统）与 `墨芯`（大模型 / 科技）；令牌驱动，运行时切换。
- **可复现**：战斗随机数固定种子；特效/台词使用独立 `visual_rng`，不消耗战斗 RNG。
- **质量保障**：`tests/logic_test.tscn` **238 条断言**；另有内容导出、字网图谱、棋盘组词概率三套工具。

---

## 环境要求

- **Godot 4.7**（stable）。无需额外插件。
- 字体已随仓库提供：`assets/fonts/NotoSerifSC-VF.ttf`（SIL OFL 1.1）。若缺失会自动回退到系统字体。

---

## 快速开始

```bash
# 方式一：编辑器
#   Godot 4.7 → 导入 → 选择本目录的 project.godot → F5

# 方式二：命令行（把 <godot> 换成本机引擎可执行文件）
<godot> --path .                                    # 运行游戏
<godot> --headless --path . res://tests/logic_test.tscn   # 跑逻辑测试
```

> 仓库内不写死任何机器路径；`<godot>` 由使用者按本机安装位置替换。

---

## 目录结构

```
src/
  data/        资源类定义（字 / 词 / 效果 / 状态 / 污染 / 敌人 / 幕 / 规则）
  core/        纯逻辑：BattleState、BattleOps、EffectResolver、EffectHandlers(+Actions/Util)
  autoload/    Database、GameState、Settings、EventBus、Router
  board/ battle/ map/   视图
  screens/     各全屏界面（含 ScreenBase）
  ui/          Ink 美术工具箱、卡片/浮层/血条/印章等
  shaders/     宣纸、木纹（程序化）
  tools/       内容生成器与导出工具
resources/     生成出的 .tres（可在编辑器直接改）
data/import/   权威策划表格（总账 / 单字表 / GDD 纯文本）
docs/          策划案、字表、图谱、提案、裁撤记录 + 配图
tests/         逻辑测试
scenes/        入口场景
assets/fonts/  随仓库字体
```

---

## 内容工作流（改卡牌）

所有内容都是 `Resource`，**在 Godot Inspector 里直接改即可，无需改代码**：

| 想改什么 | 位置 |
|---|---|
| 一个字的单字效果 / 描述 / 稀有度 / 美术色 | `resources/characters/<id>.tres` |
| 一个词的组成字与效果 | `resources/words/<id>.tres` |
| 4×4 / 开局落盘 / 每回合补字 / 热容 / 每回合出字上限 | `resources/rules/default_rules.tres` |
| 初始字袋 | `resources/starter_decks/v03.tres` |
| 污染类型 | `resources/pollutions/*.tres` |
| 状态 / 敌人 / 三幕节点 | `resources/statuses|enemies|acts/*.tres` |

**效果系统三层**（改逻辑时看这里）：

- `src/core/effect_handlers.gd` —— 调度器：按 `EffectData.handler` 分发。
- `src/core/effect_handlers_actions.gd` —— 复杂词效实现（盘面改造 / 融合 / 揭示 / 回收 / 持续能力）。
- `src/core/effect_util.gd` —— 共享工具（伤害 / 支付 / 目标解析）。

**批量生成 / 重建内容**（改完 `data/import/` 的表格后运行）：

```bash
<godot> --headless --path . --script res://src/tools/build_content.gd
```

- 内容表（字 / 词效映射 / 默认文案）：`src/tools/content_build.gd`
- 权威来源：`data/import/word_ledger_105.txt`、`solo_effects.txt` 等

> 生成器会**清空并重建** `resources/characters`、`resources/words` 等目录，请勿把手工内容只放在这些目录而不留来源。

---

## 工具

| 工具 | 命令 | 用途 |
|---|---|---|
| 逻辑测试 | `<godot> --headless --path . res://tests/logic_test.tscn` | 238 条规则断言 |
| 内容生成 | `<godot> --headless --path . --script res://src/tools/build_content.gd` | 从表格重建 `.tres` |
| 词效表 | `<godot> --headless --path . res://src/tools/dump_words.tscn` | 导出 154 词效果表 |
| 字表 | `<godot> --headless --path . res://src/tools/dump_chars.tscn` | 导出 65 字表（含出/入度） |
| 字网图谱 | `<godot> --headless --path . res://src/tools/glyph_graph.tscn` | 度数表 + Graphviz + Mermaid |
| 字网 SVG | `<godot> --headless --path . res://src/tools/glyph_network_svg.tscn` | 力导向网络图（SVG） |
| 棋盘概率 | `<godot> --headless --path . res://src/tools/board_sim.tscn` | 4×4 vs 六边形组词概率模拟 |

---

## 文档

- **主策划案**：`docs/活字战斗_GDD_V1.0.md`（含系统图解）
- 字表：`docs/附录_字表.md`
- 字网图谱：`docs/附录_字网图谱.md`
- 词效设计提案：`docs/词效设计提案_V0.4.md`
- 裁撤记录：`docs/裁撤记录.md`

---

## 操作与设置

- **连词**：在字块上按下并拖过四邻接格；点「出字」或回车/空格确认。
- **默认手感**：松手**保留选择**（需确认）。可在标题页或战斗内「设置」里打开「拖拽松手立即出字」。
- **取消**：`ESC` 或「清除」。
- **选目标**：需要时字盘/浮层会进入选择模式（选格 / 选行或列 / 选弃字堆 / 揭示 N 选 1 等）。
- **词语预览 / 结果**：显示在左下角**鲸鱼气泡框**里；**已选路径**在下方以字块缩略展示。
- **无效词反馈**：打出无效词会弹约 0.6 秒的「无效词！」反应（可替换素材，见 `assets/reactions/`）。
- **视觉风格**：标题页或战斗内「设置」可切换 `宣纸活字 ↔ 墨芯`（战斗内切换下一场生效）。
- 设置持久化到 `user://settings.cfg`。

---

## 协作约定

- 提交前请跑一遍逻辑测试，保持 **238/238**。
- 改内容优先改 `.tres`；批量改内容改 `data/import/` + `src/tools/content_build.gd` 后重生成。
- 换行统一 LF（见 `.gitattributes`）；二进制资源（字体 / PNG）已在属性中标注。
- **不要提交** `.godot/`（编辑器缓存，已在 `.gitignore`）；首次打开工程会自动重建。
- 顶层职责保持不变：`src/` 代码、`resources/` 数据、`docs/` 文档、`tests/` 测试。

---

## 调试与自动化

### 游戏内控制台
调试构建（编辑器运行 / Debug 导出）下按 **`**（反引号）或 **F1** 呼出，`/help` 看命令，`ESC` 关闭。
（若按键无反应：可能开的是旧实例，重启游戏；或键盘布局差异，用 F1。）

**暂停 / 中途退出**：`ESC` 或界面上「菜单」按钮 → 继续 / 设置 / 放弃本局（返回标题）/ 退出游戏。

- **数值/规则**：`/hp /maxhp /gold /heat /heatcap /energy /equity /funds /draw N /turn-draw N /opening N /plays N(0=无限) /goldcap N`
- **盘面**：`/board`（打印坐标/污染/层/镀金） `/set r c 字` `/clear` `/fill` `/give4 字` `/pollute r c rush|block|scorch` `/enemy-add 字 [污染]` `/gravity` `/rotate r c` `/reverse row|col i` `/fuse r1 c1 r2 c2` `/seed N`
- **流程**：`/endturn` `/nextturn`（跳过敌人） `/win` `/lose` `/heal` `/god` `/status add|clear id [n]` `/intent`
- **字袋/构筑**：`/deck` `/add 字 [n]` `/remove 字` `/clone 字` `/gild 字`
- **查询**：`/word 击破` `/char 化` `/words-of 击` `/reload` `/style paper|neon`

新增命令 = 在 `src/debug/debug_commands.gd` 注册一行。

### AI / 批量测试接口
- **纯逻辑接口** `BattleHarness`（`src/core/battle_harness.gd`，Gym 风格、固定种子可复现）：
  `reset(cfg)` · `observe()` · `legal_actions()` · `apply(action)` · `is_done()` · `summary()`
- **批量跑分**：
  ```bash
  <godot> --headless --path . res://src/tools/batch_test.tscn
  # → docs/batch_report.json（胜率 / 回合数 / 词回合比 / 单字占比 / 金币）
  ```
- **JSON 桥（供外部 AI 反复调用）**：
  ```bash
  <godot> --headless --path . res://src/tools/agent_bridge.tscn -- <scenario.json> <transcript.json>
  ```
  场景形如 `{ "seed":7, "deck":[...], "enemies":[...], "board":[...], "actions":[...], "auto":false }`；
  输出 `{ steps[], final(observe), legal_actions[], summary }`。`legal_actions` 的 `path` 为 `[[x,y],...]`，可直接回填。
  AI 循环：传入 `actions:[]` → 读 `legal_actions` → 追加一个 action 再传 → 直到 `final.done`（固定种子，逐步确定性）。

---

## 状态与后续

- 数值为**测试起点**，尚未正式平衡；金币反刷方案待定。
- 六边形棋盘已评估，结论**维持 4×4**（见 GDD 12.1）。
- 表现层（动画 / 音效）尚未实现。

---

## 许可

- 字体 `Noto Serif SC`：SIL Open Font License 1.1。
- 其余代码与内容：**待定**（`LICENSE` 待补充）。
