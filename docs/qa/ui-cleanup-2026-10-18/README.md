# UI 外观恢复与图层修正 · 2026-10-18

## 当前结果

用户否定了此前的扁平化整理：左右遮挡不一致、配色不协调、花纹丢失。该方案已撤回；下方 `after-*` 图片和原测试结果仅保留为被否定方案的历史记录，不代表当前版本或视觉验收通过。

当前恢复整理前的青铜绘卷外观：纸面山水花纹、青绿旧金边框、印章按钮、原有配色、行旅装饰和标题菜单。以 `shots/ui-cleanup-source-before/` 为恢复基线，保留该基线中已经存在的分辨率适配、Buff 状态行、内置字体、教程、触控和自动存档修复。未恢复已删除的旧主题入口。

额外修正战斗底板的绘制顺序：右侧底板与左侧底板都位于字盘边框下方；敌人内容仍在前景，右侧纸面保留原有不规则透景边缘。新增的 `UiStyle` 工厂已移除，不再改变原有控件皮肤。

本轮范围决策为 **Local Fix Only**：恢复上轮涉及的 6 个源文件，在恢复基线上只增加右侧底板排序的 2 行；测试与说明同步修正。可见问题为装饰丢失与边框遮挡不一致；退出条件为原有素材恢复、两侧底板层级一致、桌面原生截图与布局／交互回归通过。禁止扩展到新美术风格、手机调试或 APK 更新。

实际源码与整理前快照逐文件比较见 [恢复范围](logs/restore-source-scope.txt)。全工作区范围检查包含大量此前修改及二进制归档，仍触发预算提示，不能认定全工作区预算通过。

## 当前截图

电脑原生渲染，1440×810 与 960×432 两种横屏尺寸，共 30 张 `restored-*` 截图。`before-*` 为整理前，`after-*` 为被否定的整理方案；均保留供对照。

| 界面 | 1440×810 原版 | 1440×810 已撤回 | 1440×810 当前 | 960×432 当前 |
| --- | --- | --- | --- | --- |
| 主菜单 | [原版](before-title-1440x810.png) | [撤回](after-title-1440x810.png) | [当前](restored-title-1440x810.png) | [当前](restored-title-960x432.png) |
| 战斗 | [原版](before-battle-1440x810.png) | [撤回](after-battle-1440x810.png) | [当前](restored-battle-1440x810.png) | [当前](restored-battle-960x432.png) |
| 路线地图 | [原版](before-map-1440x810.png) | [撤回](after-map-1440x810.png) | [当前](restored-map-1440x810.png) | [当前](restored-map-960x432.png) |
| 战后奖励 | [原版](before-reward-1440x810.png) | [撤回](after-reward-1440x810.png) | [当前](restored-reward-1440x810.png) | [当前](restored-reward-960x432.png) |
| 市集 | [原版](before-shop-1440x810.png) | [撤回](after-shop-1440x810.png) | [当前](restored-shop-1440x810.png) | [当前](restored-shop-960x432.png) |
| 休整 | [原版](before-rest-1440x810.png) | [撤回](after-rest-1440x810.png) | [当前](restored-rest-1440x810.png) | [当前](restored-rest-960x432.png) |
| 事件 | [原版](before-event-1440x810.png) | [撤回](after-event-1440x810.png) | [当前](restored-event-1440x810.png) | [当前](restored-event-960x432.png) |
| 自定义构筑 | [原版](before-custom_deck-1440x810.png) | [撤回](after-custom_deck-1440x810.png) | [当前](restored-custom_deck-1440x810.png) | [当前](restored-custom_deck-960x432.png) |
| 墨途远征 | [原版](before-expedition_map-1440x810.png) | [撤回](after-expedition_map-1440x810.png) | [当前](restored-expedition_map-1440x810.png) | [当前](restored-expedition_map-960x432.png) |
| 字网图谱 | [原版](before-glyph_graph-1440x810.png) | [撤回](after-glyph_graph-1440x810.png) | [当前](restored-glyph_graph-1440x810.png) | [当前](restored-glyph_graph-960x432.png) |
| 新手教程 | [原版](before-tutorial-1440x810.png) | [撤回](after-tutorial-1440x810.png) | [当前](restored-tutorial-1440x810.png) | [当前](restored-tutorial-960x432.png) |
| 暂停菜单 | [原版](before-menu-1440x810.png) | [撤回](after-menu-1440x810.png) | [当前](restored-menu-1440x810.png) | [当前](restored-menu-960x432.png) |
| 设置 | [原版](before-settings-1440x810.png) | [撤回](after-settings-1440x810.png) | [当前](restored-settings-1440x810.png) | [当前](restored-settings-960x432.png) |
| 选择浮层 | [原版](before-choice-1440x810.png) | [撤回](after-choice-1440x810.png) | [当前](restored-choice-1440x810.png) | [当前](restored-choice-960x432.png) |
| 字库／字袋 | [原版](before-collection-1440x810.png) | [撤回](after-collection-1440x810.png) | [当前](restored-collection-1440x810.png) | [当前](restored-collection-960x432.png) |

## 当前回归

| 检查 | 通过／失败 | 日志 |
| --- | --- | --- |
| 实际页面、原始纹理、两侧绘制顺序与截图 | 68 / 0 | [日志](logs/restore-ui_consistency_test.log) |
| 旧主题迁移、内置字体及原始按钮皮肤 | 67 / 0 | [日志](logs/restore-frontend_cleanup_test.log) |
| 行旅页面与远征操作 | 45 / 0 | [日志](logs/restore-journey_ui_test.log) |
| 词效帮助浮层 | 29 / 0 | [日志](logs/restore-effect_help_test.log) |
| 标题菜单与路由 | 16 / 0 | [日志](logs/restore-title_menu_test.log) |
| 教程交互与冒险恢复 | 152 / 0 | [日志](logs/restore-tutorial_interaction_test.log) |
| 怪物状态与紧凑布局 | 32 / 0 | [日志](logs/restore-mobile_presentation_fix_test.log) |
| 多状态、护盾与气血对齐 | 30 / 0 | [日志](logs/restore-active_status_hud_test.log) |
| 7 组分辨率／密度与真实 Buff 回合 | 211 / 0 | [日志](logs/restore-battle_responsive_layout_test.log) |
| 原生渲染选字、实际点击与 5×5 字盘 | 58 / 0 | [日志](logs/restore-battle_ui_test.log) |

本轮 10 套回归合计 708 项通过、0 失败。页面截图、分辨率及实际点击测试使用电脑原生 OpenGL Compatibility 渲染；其余回归使用 headless。分辨率回归保留 1280×720、1920×1080、2560×1440、3200×1778、3440×1440，以及 1280×720@320dpi、2400×1080@440dpi 的覆盖。已人工检查恢复后的截图与两种尺寸的总览。导入无脚本解析错误，`git diff --check` 通过。

这些结果证明图层顺序、原始美术接入及既有交互未回归，不代表用户已确认外观。未进行手机调试或 APK 构建／更新，未测量真机性能。

## 以下为已撤回整理方案的历史记录

原始记录保留用于解释 `after-*` 截图及日志，以下“完成内容”“回归结果”“后续维护”均描述当时的方案，已由上方当前结果替代。

目标：统一战斗与非战斗界面的面板、按钮状态、文字层级、间距；去掉战斗布局先通用、再手机、最后桌面重复覆盖的结构。玩法、存档、素材中的角色与字盘不变。禁止启动手机调试、导出或安装 APK。

工程检查收据：`code-quality-workflow` → `ST-A0`，知识快照 `2026-08-16`；已读取 A0，目标、红线和验收如上。未引入外部设计或动效依赖。用户“做整理”授权分阶段修改，无需再次确认。

执行决策：分阶段重构。样式模块与战斗布局模块分别整理，保留公开控件、信号与路由接口。统一语义色：青绿环境、米白阅读面、朱砂主操作、细青铜分隔；厚装饰集中在字盘。浅色阅读面与深色环境共用样式生成器、字级和交互状态，属于同一设计规则。

范围预算：样式定义及接入约 400 行；战斗布局与控件去重约 350 行；验证与归档单独计数。已有大量未提交修改，基线按本次修改前文件快照保存于 `shots/ui-cleanup-source-before/`，不得通过恢复 HEAD 覆盖此前工作。每阶段若功能回归失败，修复或只回退本次差异。

验收：电脑原生渲染两种横屏尺寸下的所有主要界面、战斗浮层前后截图；既有输入、布局、行旅、字体、教程回归；对照字体颜色、按钮各状态与实际截图。仅代码检查不能替代画面验收。

## 完成内容

- `src/ui/ui_style.gd` 为通用组件唯一主题生成器；`Ink` 与 `JourneyStyle` 分别选择浅色阅读面／深色环境，字级、圆角、边线与按钮五种状态共用定义。
- 战斗底板不再绘制厚重卷轴边框；出字、清除、结束回合以及标题菜单不再单独拼装按钮皮肤。主操作用朱砂，次操作用青绿，文字入口用透明底；保留键盘焦点标记。
- 词效说明浮层使用同一面板生成器，保留深浅背景对应的文字颜色；不再单独添加阴影。
- 战斗先选择桌面或紧凑布局，再统一落位；删除通用布局之后再次覆盖桌面布局的分支。字盘投影在模式确定后更新。状态行继续预留，Buff 不移动或压缩词效区。
- 本次源码相对整理前快照：8 个文件（含 1 个 UID），增加 207 行、删除 480 行，净减少 273 行。样式及接入 375 行变动，战斗 311 行变动；未更改规则、存档格式、路由与打包配置。

## 截图前后对照

电脑 Godot 4.7.2 原生 OpenGL Compatibility 渲染。每个页面包含 1440×810 与 960×432 两种横屏尺寸，共 30 张整理前、30 张整理后截图；文件名保留尺寸。检查实际画面中的文字对比、边界、按钮层级及紧凑显示。设置、图鉴及长描述使用原有滚动容器，首屏截图不代表内容被删除。

| 界面 | 1440×810 整理前 | 1440×810 整理后 | 960×432 整理前 | 960×432 整理后 |
| --- | --- | --- | --- | --- |
| 主菜单 | [前](before-title-1440x810.png) | [后](after-title-1440x810.png) | [前](before-title-960x432.png) | [后](after-title-960x432.png) |
| 战斗 | [前](before-battle-1440x810.png) | [后](after-battle-1440x810.png) | [前](before-battle-960x432.png) | [后](after-battle-960x432.png) |
| 路线地图 | [前](before-map-1440x810.png) | [后](after-map-1440x810.png) | [前](before-map-960x432.png) | [后](after-map-960x432.png) |
| 战后奖励 | [前](before-reward-1440x810.png) | [后](after-reward-1440x810.png) | [前](before-reward-960x432.png) | [后](after-reward-960x432.png) |
| 市集 | [前](before-shop-1440x810.png) | [后](after-shop-1440x810.png) | [前](before-shop-960x432.png) | [后](after-shop-960x432.png) |
| 休整 | [前](before-rest-1440x810.png) | [后](after-rest-1440x810.png) | [前](before-rest-960x432.png) | [后](after-rest-960x432.png) |
| 事件 | [前](before-event-1440x810.png) | [后](after-event-1440x810.png) | [前](before-event-960x432.png) | [后](after-event-960x432.png) |
| 自定义构筑 | [前](before-custom_deck-1440x810.png) | [后](after-custom_deck-1440x810.png) | [前](before-custom_deck-960x432.png) | [后](after-custom_deck-960x432.png) |
| 墨途远征 | [前](before-expedition_map-1440x810.png) | [后](after-expedition_map-1440x810.png) | [前](before-expedition_map-960x432.png) | [后](after-expedition_map-960x432.png) |
| 字网图谱 | [前](before-glyph_graph-1440x810.png) | [后](after-glyph_graph-1440x810.png) | [前](before-glyph_graph-960x432.png) | [后](after-glyph_graph-960x432.png) |
| 新手教程 | [前](before-tutorial-1440x810.png) | [后](after-tutorial-1440x810.png) | [前](before-tutorial-960x432.png) | [后](after-tutorial-960x432.png) |
| 暂停菜单 | [前](before-menu-1440x810.png) | [后](after-menu-1440x810.png) | [前](before-menu-960x432.png) | [后](after-menu-960x432.png) |
| 设置 | [前](before-settings-1440x810.png) | [后](after-settings-1440x810.png) | [前](before-settings-960x432.png) | [后](after-settings-960x432.png) |
| 选择浮层 | [前](before-choice-1440x810.png) | [后](after-choice-1440x810.png) | [前](before-choice-960x432.png) | [后](after-choice-960x432.png) |
| 字库／字袋 | [前](before-collection-1440x810.png) | [后](after-collection-1440x810.png) | [前](before-collection-960x432.png) | [后](after-collection-960x432.png) |

## 回归结果

| 检查 | 通过／失败 | 证据 |
| --- | --- | --- |
| 整理前页面与截图基线 | 52 / 0 | [baseline.log](logs/baseline.log) |
| 整理后页面、共享样式与截图 | 74 / 0 | [ui_consistency_test.log](logs/ui_consistency_test.log) |
| 旧主题迁移、内置字体、通用按钮 | 67 / 0 | [frontend_cleanup_test.log](logs/frontend_cleanup_test.log) |
| 行旅页面与远征操作 | 45 / 0 | [journey_ui_test.log](logs/journey_ui_test.log) |
| 词效帮助浮层 | 29 / 0 | [effect_help_test.log](logs/effect_help_test.log) |
| 标题菜单与路由 | 16 / 0 | [title_menu_test.log](logs/title_menu_test.log) |
| 教程交互与冒险恢复 | 152 / 0 | [tutorial_interaction_test.log](logs/tutorial_interaction_test.log) |
| 怪物状态与紧凑布局 | 32 / 0 | [mobile_presentation_fix_test.log](logs/mobile_presentation_fix_test.log) |
| 多状态、护盾与气血对齐 | 30 / 0 | [active_status_hud_test.log](logs/active_status_hud_test.log) |
| 7 组分辨率／密度与真实 Buff 回合 | 211 / 0 | [battle_responsive_layout_test.log](logs/battle_responsive_layout_test.log) |
| 原生渲染选字、点击与 5×5 字盘 | 58 / 0 | [battle_ui_test.log](logs/battle_ui_test.log) |
| 核心逻辑 | 250 / 0 | [logic_test.log](logs/logic_test.log) |
| 词效回归 | 411 / 0 | [word_effect_regression.log](logs/word_effect_regression.log) |

整理后 12 套测试合计 1375 项通过、0 失败；[导入日志](logs/import.log) 无脚本解析错误，`git diff --check` 通过。

布局回归覆盖：1280×720、1920×1080、2560×1440、3200×1778、3440×1440，以及 1280×720@320dpi、2400×1080@440dpi。密度在电脑进程内注入，未启动 Android Studio、模拟器、ADB、手机调试或 APK 构建／安装，因此不作为真机性能结论。

范围检查：按技能执行了包含全部已跟踪及未跟踪文件的 `staged-refactor` 检查。工作区包含此前字体、存档、教程、安卓工具与大量截图，触发默认文件数、行数和二进制预算提示；不能将全工作区结果当成本次补丁通过。另以整理前 `src` 快照逐文件比较，[本次源码差异清单](logs/task-source-scope.txt) 为 +207/-480，满足预先记录的分阶段范围；没有为消除提示覆盖已有修改。

后续维护：组件皮肤在 `UiStyle` 修改；页面布局在各页面或布局计算器修改。角色、字盘与意图图标等专用表现保留自身绘制；旧装饰资源本轮只解除生产调用，未扩大到无关素材清理。
