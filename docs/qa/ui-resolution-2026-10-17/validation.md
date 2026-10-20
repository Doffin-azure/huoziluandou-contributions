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
