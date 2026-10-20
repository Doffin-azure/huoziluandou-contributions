# 横屏 UI 修复与截图归档

仅覆盖横屏，不增加竖屏或旋转提示。已同步并合并远端 `origin/main`（`2745557`，本地合并提交 `0d5a0ea`）。

[打开交互式修复前／后图库](index.html) · [完整对照数据](comparison.json) · [截图校验清单](sha256.json)

## 测试口径

Godot 4.7.2、Windows、RTX 4060 Laptop、Vulkan Forward+。正式 `main.tscn` 和 Router 创建真实页面；使用固定种子（行旅 `20261016`、战斗 `7`，事件按脚本内固定候选种子映射），减少动效开启，逐帧等待布局后直接读取视口截图。共用浮层、三种普通事件、三种远征谜事件、整备、战报、选字与结算均归档。

手机型号仅表示对应的有效横屏视口尺寸。测试图片按该有效尺寸渲染；下列面板像素作为型号映射参考，并未逐台连接实机。浏览器工具栏、安全区、刘海、系统字体及真实设备性能仍需实机验收。DPI 换算代码统一复用战斗现有规则；本矩阵没有模拟各型号的操作系统。

当前归档：修复前 918 张，修复后 918 张。完整矩阵为 18 组 × 51 个检查场景 = 918 对（1836 张原图）。

修复前屏外控件出现次数 685；修复后 0。同一缺陷在多个状态重复出现会重复计数。修复后另检查禁用横向滚动区域的横向裁切，以及奖励／商店价格与主操作按钮重叠。滚动区域内可滚达的纵向内容不计为越界。自动检查不等于所有像素级遮挡均可自动判定，另目检代表尺寸原图及全状态缩略图。

## 修复前／后表

| 界面 | 修复前 | 修复后 | 代表尺寸原图对照 |
| --- | --- | --- | --- |
| 自定义构筑 | 顶栏固定单行，已选数、返回和开始按钮越界 | 顶栏流式换行，字块网格保留独立滚动区 | [前](before/phone-640x360/custom-deck.png) / [后](after/phone-640x360/custom-deck.png) |
| 字网详情 | 选择节点后详情撑高侧栏，底部内容落出屏幕 | 侧栏独立纵向滚动，图形区域保留高度 | [前](before/phone-640x360/glyph-detail.png) / [后](after/phone-640x360/glyph-detail.png) |
| 幕地图 | 窄屏路径节点间距不足，触区互相挤占 | 路线按触控单位保留节点间距，可横向滚动 | [前](before/phone-640x360/map.png) / [后](after/phone-640x360/map.png) |
| 休整 | 卡片最小高度可能把页尾挤出，短屏无内容滚动 | 选项内容区可滚动，页眉与页尾保留 | [前](before/phone-640x360/rest.png) / [后](after/phone-640x360/rest.png) |
| 远征探索与整备 | 整张大地图作为最小宽度，右侧操作区和菜单被挤出 | 地图双向滚动，行旅／字阵／战报／整备分栏切换 | [前](before/phone-640x360/expedition-actions.png) / [后](after/phone-640x360/expedition-actions.png) |
| 设置 | 长说明和固定面板宽度可能导致横向裁切 | 面板按可用宽度限制，说明自动换行 | [前](before/phone-640x360/settings-top.png) / [后](after/phone-640x360/settings-top.png) |
| 图鉴／选字 | 大固定外边距挤占小屏内容，长副标题推挤关闭按钮 | 缩小外边距，标题栏流式换行，词效字号按单位换算 | [前](before/phone-640x360/collection-words.png) / [后](after/phone-640x360/collection-words.png) |
| 商店／奖励 | 按钮高度与触控单位不一致，4:3 平板右侧整备印台出画 | 按钮最小 48 单位，窄比例拓宽视野，短屏保留价格间距 | [前](before/tablet-4x3/shop.png) / [后](after/tablet-4x3/shop.png) |
| 战斗血量 | 100 / 100 等较长数值超出预留宽度，被侧栏裁切 | 按实际文字宽度分配血量区，长数值适配字号 | [前](before/phone-640x360/battle-status.png) / [后](after/phone-640x360/battle-status.png) |
| 战报与通用浮层 | 战报固定小面板和字号，DPI 换算与战斗页不一致 | 战报按视口限高、字号与触控单位缩放；暂停、词条统一换算 | [前](before/phone-640x360/battle-log.png) / [后](after/phone-640x360/battle-log.png) |

上一轮四项修复（图层、玩家状态、异常立绘跳变、手机庭院渲染预算）继续保留，参见[上一轮记录](../../界面修复_2026-10-17.md)。本轮修复前截图以这些修复已存在的本地版本为基线；不将其伪称为最初版本。[用户原始图层问题截图](original-layer-bug.jpg)单独保留。

## 分辨率矩阵

| 型号／类别 | 测试横屏尺寸 | 面板像素参考（横屏） | 前／后状态数 | 修复后几何问题 |
| --- | --- | --- | --- | --- |
| Android 小屏基线 | 640×360 | 1280×720（2× 示例） | 51 / 51 | 0 |
| iPhone SE 2 / 3 | 667×375 | 1334×750 | 51 / 51 | 0 |
| iPhone X / XS / 11 Pro | 812×375 | 2436×1125 | 51 / 51 | 0 |
| iPhone 12 / 13 / 14 | 844×390 | 2532×1170 | 51 / 51 | 0 |
| iPhone 14 Pro | 852×393 | 2556×1179 | 51 / 51 | 0 |
| iPhone XR / 11 | 896×414 | 1792×828 | 51 / 51 | 0 |
| Pixel 7 有效视口 | 915×412 | 2400×1080 | 51 / 51 | 0 |
| iPhone 14 / 15 Pro Max | 932×430 | 2796×1290 | 51 / 51 | 0 |
| Android 20:9 代表尺寸 | 960×432 | 2400×1080（2.5× 示例） | 51 / 51 | 0 |
| iPad 4:3 代表尺寸 | 1024×768 | 2048×1536（2× 示例） | 51 / 51 | 0 |
| 小窗口 16:9 | 1024×576 | — | 51 / 51 | 0 |
| 桌面 HD | 1280×720 | — | 51 / 51 | 0 |
| 常见笔记本 | 1366×768 | — | 51 / 51 | 0 |
| 桌面 900p | 1600×900 | — | 51 / 51 | 0 |
| 桌面 FHD | 1920×1080 | — | 51 / 51 | 0 |
| 桌面 QHD | 2560×1440 | — | 51 / 51 | 0 |
| 超宽屏 | 2560×1080 | — | 51 / 51 | 0 |
| 桌面 UHD | 3840×2160 | — | 51 / 51 | 0 |

## 页面与状态覆盖

| 页面／状态 | 修复前／后截图 |
| --- | --- |
| 战斗／字袋词图鉴与分层遮挡 | [前](before/phone-640x360/battle-deck-words.png) / [后](after/phone-640x360/battle-deck-words.png)；其他尺寸见交互图库 |
| 战斗／败北 | [前](before/phone-640x360/battle-defeat.png) / [后](after/phone-640x360/battle-defeat.png)；其他尺寸见交互图库 |
| 战斗／5×5 字盘与四位数血量 | [前](before/phone-640x360/battle-five.png) / [后](after/phone-640x360/battle-five.png)；其他尺寸见交互图库 |
| 战斗／战报 | [前](before/phone-640x360/battle-log.png) / [后](after/phone-640x360/battle-log.png)；其他尺寸见交互图库 |
| 战斗／抽牌堆 | [前](before/phone-640x360/battle-pile.png) / [后](after/phone-640x360/battle-pile.png)；其他尺寸见交互图库 |
| 战斗／三敌人与玩家状态 | [前](before/phone-640x360/battle-status.png) / [后](after/phone-640x360/battle-status.png)；其他尺寸见交互图库 |
| 岔路与选择弹窗 | [前](before/phone-640x360/choice.png) / [后](after/phone-640x360/choice.png)；其他尺寸见交互图库 |
| 字库图鉴／实体字 | [前](before/phone-640x360/collection-chars.png) / [后](after/phone-640x360/collection-chars.png)；其他尺寸见交互图库 |
| 字库图鉴／词 | [前](before/phone-640x360/collection-words.png) / [后](after/phone-640x360/collection-words.png)；其他尺寸见交互图库 |
| 自定义构筑 | [前](before/phone-640x360/custom-deck.png) / [后](after/phone-640x360/custom-deck.png)；其他尺寸见交互图库 |
| 当前字袋 | [前](before/phone-640x360/deck.png) / [后](after/phone-640x360/deck.png)；其他尺寸见交互图库 |
| 词条说明浮层 | [前](before/phone-640x360/effect-help.png) / [后](after/phone-640x360/effect-help.png)；其他尺寸见交互图库 |
| 事件／断碑 | [前](before/phone-640x360/event-all-broken_stele.png) / [后](after/phone-640x360/event-all-broken_stele.png)；其他尺寸见交互图库 |
| 事件／墨池（确定种子） | [前](before/phone-640x360/event-all-ink_pool.png) / [后](after/phone-640x360/event-all-ink_pool.png)；其他尺寸见交互图库 |
| 事件／旧书肆（确定种子） | [前](before/phone-640x360/event-all-old_bookshop.png) / [后](after/phone-640x360/event-all-old_bookshop.png)；其他尺寸见交互图库 |
| 事件／墨池 | [前](before/phone-640x360/event-ink_pool.png) / [后](after/phone-640x360/event-ink_pool.png)；其他尺寸见交互图库 |
| 事件／旧书肆 | [前](before/phone-640x360/event-old_bookshop.png) / [后](after/phone-640x360/event-old_bookshop.png)；其他尺寸见交互图库 |
| 远征／幕间结算 | [前](before/phone-640x360/expedition-act_end.png) / [后](after/phone-640x360/expedition-act_end.png)；其他尺寸见交互图库 |
| 远征／整备操作 | [前](before/phone-640x360/expedition-actions.png) / [后](after/phone-640x360/expedition-actions.png)；其他尺寸见交互图库 |
| 远征／压字石绑定 | [前](before/phone-640x360/expedition-bind-full.png) / [后](after/phone-640x360/expedition-bind-full.png)；其他尺寸见交互图库 |
| 远征／首领迎战 | [前](before/phone-640x360/expedition-boss.png) / [后](after/phone-640x360/expedition-boss.png)；其他尺寸见交互图库 |
| 远征／许愿机 | [前](before/phone-640x360/expedition-forge.png) / [后](after/phone-640x360/expedition-forge.png)；其他尺寸见交互图库 |
| 远征／满印章及全遗物整备 | [前](before/phone-640x360/expedition-late.png) / [后](after/phone-640x360/expedition-late.png)；其他尺寸见交互图库 |
| 远征／图例 | [前](before/phone-640x360/expedition-legend.png) / [后](after/phone-640x360/expedition-legend.png)；其他尺寸见交互图库 |
| 远征／战报 | [前](before/phone-640x360/expedition-log.png) / [后](after/phone-640x360/expedition-log.png)；其他尺寸见交互图库 |
| 远征／大赏 | [前](before/phone-640x360/expedition-loot.png) / [后](after/phone-640x360/expedition-loot.png)；其他尺寸见交互图库 |
| 远征／中止 | [前](before/phone-640x360/expedition-loss.png) / [后](after/phone-640x360/expedition-loss.png)；其他尺寸见交互图库 |
| 远征／探索 | [前](before/phone-640x360/expedition-map.png) / [后](after/phone-640x360/expedition-map.png)；其他尺寸见交互图库 |
| 远征／谜事件一 | [前](before/phone-640x360/expedition-mystery-0.png) / [后](after/phone-640x360/expedition-mystery-0.png)；其他尺寸见交互图库 |
| 远征／谜事件二 | [前](before/phone-640x360/expedition-mystery-1.png) / [后](after/phone-640x360/expedition-mystery-1.png)；其他尺寸见交互图库 |
| 远征／谜事件三 | [前](before/phone-640x360/expedition-mystery-2.png) / [后](after/phone-640x360/expedition-mystery-2.png)；其他尺寸见交互图库 |
| 远征／字阵 | [前](before/phone-640x360/expedition-plate.png) / [后](after/phone-640x360/expedition-plate.png)；其他尺寸见交互图库 |
| 远征／遗物绑定 | [前](before/phone-640x360/expedition-relic_bind.png) / [后](after/phone-640x360/expedition-relic_bind.png)；其他尺寸见交互图库 |
| 远征／休息点 | [前](before/phone-640x360/expedition-rest.png) / [后](after/phone-640x360/expedition-rest.png)；其他尺寸见交互图库 |
| 远征／印章已满替换 | [前](before/phone-640x360/expedition-seal-full.png) / [后](after/phone-640x360/expedition-seal-full.png)；其他尺寸见交互图库 |
| 远征／印章替换 | [前](before/phone-640x360/expedition-seal_swap.png) / [后](after/phone-640x360/expedition-seal_swap.png)；其他尺寸见交互图库 |
| 远征／商店 | [前](before/phone-640x360/expedition-shop.png) / [后](after/phone-640x360/expedition-shop.png)；其他尺寸见交互图库 |
| 远征／胜利 | [前](before/phone-640x360/expedition-win.png) / [后](after/phone-640x360/expedition-win.png)；其他尺寸见交互图库 |
| 字网／节点详情 | [前](before/phone-640x360/glyph-detail.png) / [后](after/phone-640x360/glyph-detail.png)；其他尺寸见交互图库 |
| 字网图谱 | [前](before/phone-640x360/glyph-graph.png) / [后](after/phone-640x360/glyph-graph.png)；其他尺寸见交互图库 |
| 幕地图 | [前](before/phone-640x360/map.png) / [后](after/phone-640x360/map.png)；其他尺寸见交互图库 |
| 暂停菜单 | [前](before/phone-640x360/pause.png) / [后](after/phone-640x360/pause.png)；其他尺寸见交互图库 |
| 休整 | [前](before/phone-640x360/rest.png) / [后](after/phone-640x360/rest.png)；其他尺寸见交互图库 |
| 休整／删字选取 | [前](before/phone-640x360/rest-picker.png) / [后](after/phone-640x360/rest-picker.png)；其他尺寸见交互图库 |
| 战后／四选一奖励 | [前](before/phone-640x360/reward-four.png) / [后](after/phone-640x360/reward-four.png)；其他尺寸见交互图库 |
| 设置／手感与音量 | [前](before/phone-640x360/settings-bottom.png) / [后](after/phone-640x360/settings-bottom.png)；其他尺寸见交互图库 |
| 设置／字体 | [前](before/phone-640x360/settings-top.png) / [后](after/phone-640x360/settings-top.png)；其他尺寸见交互图库 |
| 商店／买字 | [前](before/phone-640x360/shop.png) / [后](after/phone-640x360/shop.png)；其他尺寸见交互图库 |
| 商店／复制选字 | [前](before/phone-640x360/shop-picker.png) / [后](after/phone-640x360/shop-picker.png)；其他尺寸见交互图库 |
| 商店／整备服务 | [前](before/phone-640x360/shop-service.png) / [后](after/phone-640x360/shop-service.png)；其他尺寸见交互图库 |
| 主界面 | [前](before/phone-640x360/title.png) / [后](after/phone-640x360/title.png)；其他尺寸见交互图库 |

## 复现

```powershell
godot --path . res://tests/ui_resolution_matrix.tscn -- --phase=after
godot --path . res://tests/ui_resolution_matrix.tscn -- --phase=after --stress-only
python tests/ui_resolution_report.py --require-complete
```

单一尺寸可加 `--profile=iphone-13`。修复前源码为合并提交加 [baseline.patch](baseline.patch)；截图脚本见 `tests/ui_resolution_matrix.gd`。原图、视口大小、控件矩形、缺陷计数保存在每阶段 JSON 中。`before/*-extras.json` 补充了同一基线的 13 个状态，`*-stress.json` 补充满印章、绑定类遗物和 5×5 字盘的 4 个状态，未修改基线生产代码。

`baseline-source-sha256.json` 记录基线生产源码，`source-sha256.json` 记录修复后生产源码。校验清单覆盖所有原图和矩阵 JSON。操作系统原生字体选择器和调试控制台不属于游戏正式页面，不纳入截图矩阵。

## 行为回归与原生检查

| 检查 | 结果 | 日志 |
| --- | --- | --- |
| 横屏截图矩阵 | 18 × 51，918 对原图；修复后几何问题 0 | [完整对照](comparison.json) |
| 行旅界面行为、随机结果、地图移动及标签页 | 45 / 45，原生 | [日志](logs/resolution-test-journey-native.log) |
| 实物商店与奖励、价格及触区 | 18 / 18，原生 | [日志](logs/resolution-test-object-native.log) |
| 事件交互 | 63 / 63 | [日志](logs/resolution-test-event_art.log) |
| 标题菜单 | 16 / 16 | [日志](logs/resolution-test-title_menu.log) |
| 标题与书房流程 | 27 / 27 | [日志](logs/resolution-test-study_flow.log) |
| 词条浮层 | 29 / 29，无头与原生均通过 | [日志](logs/resolution-test-effect-native.log) |
| 战斗牌堆 | 21 / 21 | [日志](logs/resolution-test-battle_pile_ui.log) |
| 玩家状态 HUD | 30 / 30 | [日志](logs/resolution-test-active_status_hud.log) |
| 分层遮挡、异常立绘稳定、玩家状态、四位数血量、手机庭院预算 | 28 / 28，原生 | [日志](logs/resolution-test-mobile-native.log) |
| 核心逻辑 | 250 / 250 | [日志](logs/resolution-test-logic.log) |
| 词效规则 | 411 / 411 | [日志](logs/resolution-test-word_effect_regression.log) |

上表行为回归共 938 项通过。同一套用例在无头和原生运行时只计一次。词条测试显式设置 1280×720 起始窗口，避免无头引擎默认 64×64 假窗口触发不适用于横屏验收的密度换算；随后仍覆盖原有 844×390 小屏用例。血量回归增加实际字体宽度检查，防止 `clip_text` 隐藏文字裁切却通过矩形检查。

原生手机庭院预算配置仍为 960×540、峰值 80 次绘制调用；桌面配置为 1920×1080、峰值 695 次。同机渲染调用约减少 88%，不能当作手机真机帧率。

## 已存在的测试失败

以下失败与修复前 HEAD 快照日志逐条比较，名称和数量完全相同，未将其计为通过。它们不属于本轮新增回归：

| 测试 | 修复前 | 修复后 | 既有失败内容 |
| --- | --- | --- | --- |
| battle_ui | 54 通过 / 4 失败 | 54 通过 / 4 失败 | 开场单击选择、撤销末字、中间字回退、拖动回退的输入路径断言 |
| status_intent_fix | 90 通过 / 2 失败 | 90 通过 / 2 失败 | 桌面意图区至少 64 屏幕像素、关键字号约 36 屏幕像素的规格断言 |

[战斗基线](logs/baseline-battle-ui.log) / [修复后](logs/resolution-test-battle_ui.log)；[意图基线](logs/baseline-status-intent.log) / [修复后](logs/resolution-test-status_intent_fix.log)。

所有正式页面的截图均从真实运行场景获得。检查含窗口越界、禁用横向滚动区域的裁切、价格与主按钮相交、血量文字实际宽度；可纵向或横向滚达的内容不算不可达。代表原图和缩略图目检补充自动检查；不将“0 个自动检查问题”解释为覆盖所有系统环境。

[640×360 修复前全状态缩略图](before-contact.jpg) / [修复后](after-contact.jpg)。

最后补拍了全部尺寸的战斗状态、战报、牌堆、败北、字袋词图鉴和 5×5 字盘，记录在 `after/zz-*-battle.json`，图库优先采用这些最终数据；对应图片已原位更新。4:3 平板组在相机视野修正后完整重跑。
