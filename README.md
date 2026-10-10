# 活字战斗 · Godot 4.7 脚手架

以 GDD **V0.1 / V0.2（词效交接版）/ V0.3（初始字袋与冒险规模）** 为实现基准的可运行纵向切片。
目标：**改卡牌像改表格一样简单**；美术用程序化材质，不做“网页堆 div”的样子。

---

## 1. 运行 / 测试

```bash
# 运行
"D:/Downloads/Old-F/godot/Godot_v4.7-stable_win64.exe" --path .

# 白盒逻辑测试（12 条规则断言，可重复运行）
"D:/Downloads/Old-F/godot/Godot_v4.7-stable_win64_console.exe" --headless --path . res://tests/logic_test.tscn

# 重新生成全部内容资源（改完 data/import 的表格后）
"...Godot...console.exe" --headless --path . --script res://src/tools/build_content.gd
```

主场景：`scenes/main.tscn` → `src/screens/main.gd`。
流程：标题 → 三幕地图（每幕 8 节点）→ 战斗 → 奖励 → 商店 / 休整 / 事件 / 岔路 → 首领 → 通关。

---

## 2. 已接入的 V0.1 / V0.2 / V0.3 内容

| 来源 | 接入方式 |
|---|---|
| V0.2《完整词效总账 105 词》 | `resources/words/*.tres`（总账 105 → 裁撤 5 后 **100 个词**（100 已实现 / 0 待定）+ **6 个新增词**（火化/化合/精金/精铸/精分/开灯）；裁撤见 `docs/裁撤记录.md`） |
| V0.2 附录 C 单字效果表 | `resources/characters/*.tres` 的 `solo_effects`（击/防/护/御/回/重/清/反/甲/盾/破） |
| V0.2 Word Data Contract | `WordData` 的 `group/design_stage/effect_summary/effect_handler_id/requires_target/timing/p25_implemented/implementation_delta/priority/test_cases/implemented` |
| V0.2 战斗机制 | 临挡/持久盾、储能、热度/热容/灼热字、金币/临时资金、污染所有权、临时层、目标选择 |
| V0.2 敌人三类意图 | 攻击 / 注入污染字（刺痛、堵塞、灼热）/ 护盾 |
| V0.2 §2.2 回合 | 无固定出字次数上限；补字修正；后置结算（反击、临挡清除） |
| V0.3 初始字袋 | `resources/starter_decks/v03.tres`：12 枚 / 9 种，开局落 10，回合补 3 |
| V0.3 三幕八节点 | `resources/acts/act_{1,2,3}.tres` |
| V0.1 开发任务清单 | 作为验收口径，见 `data/import/dev_tasks.txt` |

导入的权威表格在 `data/import/`：`word_ledger_105.txt`、`solo_effects.txt`、
`dev_board_105.txt`、`dev_tasks.txt`、`p23_candidates_104.txt`、`GDD_v0.1.md`、`GDD_v0.2.md`。

### 未定稿怎么办

总账里“尚未收敛 / 未复审”的 16 个词**已进库、可在图鉴查看、可组词打出**，
但 `implemented=false` → 打出只消耗、不产生效果，预览会提示“效果待定”。
这对应 GDD 的 P0 待决项：是否允许“合法零效词”由 `BattleRules.allow_zero_effect_words` 控制。
未定稿的词**不会**被悄悄套上通用伤害/抽字。

---

## 3. 怎么改卡牌

一切内容都是 `Resource`，在 Godot Inspector 里直接改，无需动代码：

| 想做的事 | 改哪里 |
|---|---|
| 一个字的效果/描述/稀有度/美术色 | `resources/characters/<id>.tres` |
| 一个词的组成字与效果 | `resources/words/wNNN.tres` 的 `glyphs` / `effects` |
| 把一个“待定”词做成正式效果 | 给它的 `effects` 加一条 `EffectData`，或加 `handler` |
| 初始字袋 / 开局落字数 / 补字数 / 出字上限 | `resources/starter_decks/v03.tres`、`resources/rules/default_rules.tres` |
| 污染类型（刺痛/堵塞/灼热代价） | `resources/pollutions/*.tres` |
| 状态、敌人、幕、节点 | `resources/statuses|enemies|acts/*.tres` |

**效果系统两层**：
- `effects[].handler` 非空 → `src/core/effect_handlers.gd` 的具名处理器（适合有特殊规则的词，如反击/重合/放电）。
- 否则走 `EffectData.kind` 的通用数值分支（见 `src/core/effect_resolver.gd`）。

已实现的关键 handler：`block_temp / block_persist / ability_convert_block / counter / shield_smash /
break_shield_damage / replay_last_attack / gravity_damage / merge_duplicates / draw_random /
recover_consumed / rotate_2x2 / destroy_2x2 / cleanse_all / energy* / heat* / ability_* /
spend_gold_damage / capture_glyph / reveal_place / permanent_*` 等 40+ 个。

> 表格生成器 `src/tools/build_content.gd` 会解析 `data/import/word_ledger_105.txt` 生成 105 个词，
> 并按《总账》的“最近讨论效果方向”映射到 handler。生成后直接改资源即可。

---

## 4. 目录结构

```
src/
  data/        资源类（字/词/效果/状态/污染/敌人/幕/规则）
  core/        纯逻辑：BoardState / BattleState / Combatant / CharInstance / EffectResolver / EffectHandlers
  autoload/    EventBus / Database / GameState / Router
  board/ map/ battle/  视图
  screens/     ScreenBase + 各界面
  ui/          Ink 美术工具箱 / CharCard / CollectionOverlay / ChoiceOverlay / StatBar / SealView
  shaders/     宣纸、木纹（程序化，无贴图）
  tools/       build_content.gd
resources/     characters(63) / words(105) / pollutions(3) / statuses(6) / enemies(9) / acts(3) / rules / starter_decks
tests/         logic_test.tscn + logic_test.gd
data/import/   权威策划表格
assets/fonts/  Noto Serif SC
```

---

## 5. GDD 规则对照（关键）

- 4×4、四邻接、可转弯、不重复格；非法多字路径**不消耗**（`BoardState.valid_path`）。
- 单字出牌 = 弃字，同一操作；无单字效果也能打出。
- 出字后**不自动补满**；只有回合补字（3）或补字词效。
- 一回合**无固定出字次数上限**（`plays_per_turn = 0`）。
- `CharInstance`：`uid / owner / pollutions / modifiers / temporary_uses`，敌字消耗后消失、不进己方袋。
- 污染不改变字，可与正常词效并行触发（`_apply_pollution`）。
- 过热：热度 > 热容时每点溢向往本场字袋塞 1 枚带灼热的【热】（战内循环）。
- 重合：1 实体 + N-1 临时层，其余真实副本回字袋（守恒，见测试）。
- 反击：敌方整次行动后，用**剩余临挡**+3/层转伤害，不动持久盾。
- 词效预览与实际结算共用同一 `try_play` 语义（预览只读描述；目标选择在提交前完成）。

对应测试见 `tests/logic_test.gd`：共 **30 条断言**，覆盖防御/护盾/刺痛/过热/重合/回/反击/注入/击破/股权闭环/储能热度互转/缩放攻击/爆冷/停火/放火/反复/铸币/回购/重力。

---

## 6. 美术与 UI

- 宣纸底 `paper.gdshader`、木活字 `wood.gdshader`（程序化）。
- 统一主题/配色/字号：`src/ui/ink.gd` + `src/ui/palette.gd`。
- 字块显示：所属（敌=偏红、自生=偏琥珀）、污染角标、临时层数 ×N。
- 战斗屏常驻：气血、临挡、持久盾、储能、热度/热容、临时资金、字袋/弃字堆、战报、实时预览。

---

## 7. 字网图谱（出度 / 入度）

有向边 `A → B` = 存在某个词，其中 A 紧接在 B 之前（按连线顺序）。节点大小 = 总度，颜色 = 所属体系。

- **游戏内**：标题 → **字网图谱**。可切换「全部 105 / 已实现 82 / 初始 9 字」三个视图；点击节点查看该字的出度、入度、加权度、后续字、前置字。
- **命令行生成报告**：
  ```bash
  "...Godot...console.exe" --headless --path . res://src/tools/glyph_graph.tscn
  ```
  输出：`docs/glyph_graph_report.md`（表格）、`docs/glyph_graph.dot`（Graphviz）、`docs/glyph_graph.mmd`（Mermaid）。

**初始字袋 9 字的字网（关键结论）**：击 入度 4（反/连/重/回→击）、出度 1（击→破）；回 出度 3（回→击/流/防）、入度 0；防→御；破→防。攻击全部汇入【击】，【回】是唯一的多向连接器——增字/删字时要优先保护这两个枢纽。

## 8. 仍是原型的地方

- **总账词已全部实现**（100/100）；另有 6 个额外词（火化/化合/精金/精铸/精分/开灯）。
- 已裁撤 4 词 + 1 字（纯化/纯金/纯利/精纯、纯），见 `docs/裁撤记录.md`；临时资金改为可直接支付经济词。
- **手感设置**：标题/战斗内「设置」可开关「拖拽松手立即出字」（默认关=需确认），持久化 `user://settings.cfg`。
- 【转化】【分化】【强化】【炼化】【精炼】【精力】由设计负责人重新定义；新增【火化】【化合】【精金】【精铸】【精分】。见 `docs/词效设计提案_V0.4.md`。
- 数值未平衡；`gold_cap_per_battle=18` 是原型安全阀。
- `流利`（对角一步）、`复合`（临时层保留）等空间词为“已记录、占位实现”。
- 存档与可复现 RNG 流尚未完全落地（`BattleState.rng` 已支持固定种子）。
- 反应梗图（蓝色大肥鱼/惊讶图）未接入——V0.2 要求其仅在合适时机短显，且信息须独立显示。

---

## 8. 设计资料

- `../huozi_godot_gdd_v01_package/`、`../huozi_godot_gdd_v02_package/`、`../huozi_godot_gdd_v03_design_pack/`
- 工程内副本：`data/import/`（表格与 GDD md）
