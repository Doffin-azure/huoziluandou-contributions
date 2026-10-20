# 动效设置与怪物漏接核查

## 核查基线

- 本地 HEAD：`0d5a0ea`，`refactor/frontend-legacy-cleanup`。
- 2026-10-19 fetch 后 `origin/main=aab2fe8`，仍只有 9 个旧敌人资源。
- `origin/merge/local-design-20261017=93106c4` 有 20 种新增机制怪物，加 9 个兼容旧资源，共 29 个。新增机制始于 `14698da`，后续参数、指定塞字修订在 `c373d4c`。
- Settings 默认 reduced_motion=false；新手测试设为 true 后直接 `_save()`，会污染实际玩家配置；当前桌面配置为 false。

## 修复边界与验证门槛

决策：Local Fix / 分阶段补接缺失怪物依赖；不重写模块。既有大量未提交改动全部保留。

1. 测试设置隔离：所有临时改动 reduced_motion 的 UI 测试使用各自配置路径；默认关闭、主动开启可持久化。验证新建配置、缺失键、开启后重载、教程测试前后实际配置哈希一致。
2. 怪物：补入远端 20 怪资源、机制、参数配置与候选关卡；保留 9 个旧资源用于现有存档/夹具。仅接入相关战斗钩子、远征投放和意图标记，保留本地 UI、日志、教程与动画。按合并前副本三方合入，冲突逐处处理。
3. 验证：远端怪物回归、塞字、参数、真实 UI、动画和存档回归。新脚本 headless 导入后运行。不得启动手机调试或打包 APK。

预算：怪物数据及测试按远端原文件恢复；生产逻辑修改限制在怪物依赖与存档兼容路径。禁止整分支覆盖本地美术、界面、音乐、发布配置或无关词效/经济改动。所有目标原文备份到临时目录，失败只撤销本次差异。

这次是相关玩法的选择性补接，不宣称已合入整个远端分支。

## 修复结果

| 问题 | 修复前 | 修复后 |
| --- | --- | --- |
| 减少动效 | 默认值虽为 false，教程回归会将临时 true 写入玩家 settings.cfg | 改动动效的测试使用独立配置；新建、旧配置缺键、主动切换及重载均通过 |
| 新怪物缺失 | 当前工作区只有 9 个旧敌人；20 怪所在的远端整合分支未接入 | 恢复 20 种机制怪物、参数配置、3 幕候选投放及远征分区投放；运行时共加载 29 个兼容资源 |
| 真实地图入口 | 单独配置数据库，关卡仍可引用未配置的缓存 .tres | 将关卡候选和默认敌人统一绑定配置副本；纸壳兵补盾目标为 8 |
| 已制作角色 | 策划 ID 与美术样例 ID 不同 | 纸壳兵、连针蜂、倾砚、折页蛾接入既有角色与动作，不改变原图或战斗随机数 |
| 新机制续档 | 对象实例 ID 在续档后变化，塞字上限可能失效；新增字段使旧存档被拒绝 | 同源塞字使用稳定敌人序号；只为已知新增字段提供缺省迁移，缺少原有关键字段仍拒绝 |

实际桌面玩家配置在教程、设置和其他回归前后 SHA256 均为 `90B6012833A12BF7C9901A7D966259BD41C7A9C8FC89FF410B7AE9749C39660F`，`visual/reduced_motion=false`。未连接手机或生成 APK。

## 最终验证

| 检查 | 通过 / 失败 | 日志 |
| --- | --- | --- |
| 动效默认值、保存重载和设置按钮 | 8 / 0 | [motion.log](motion.log) |
| 首局教程及设置隔离 | 9 / 0 | [tutorial.log](tutorial.log) |
| 20 怪机制、边界与投放 | 240 / 0 | [monster-final.log](monster-final.log) |
| 指定塞字、复制、净化与上限 | 52 / 0 | [injection-final.log](injection-final.log) |
| 怪物参数配置及无效输入 | 39 / 0 | [enemy-balance-final.log](enemy-balance-final.log) |
| 地图配置引用、旧存档兼容与续档塞字上限 | 39 / 0 | [save-final.log](save-final.log) |
| 自动存档和远征续档 | 44 / 0 | [autosave-fixed.log](autosave-fixed.log) |
| 新怪物任务标记、预告及原生截图 | 17 / 0 | [monster-native-settled.log](monster-native-settled.log) |
| 四只已制作角色的动作映射与随机数 | 48 / 0 | [art-merge.log](art-merge.log) |
| 墨灵骨骼和行动动画（原生渲染） | 28 / 0 | [guardian-native.log](guardian-native.log) |
| 战斗 UI、触控及 5×5 遗物（原生渲染） | 60 / 0 | [battle-ui-native.log](battle-ui-native.log) |
| 意图、详情和输入锁 | 105 / 0 | [intent-final.log](intent-final.log) |
| 标题→地图→新怪物真实入口 | 8 / 0 | [battle-entry.log](battle-entry.log) |
| 图鉴关闭、顶栏及多分辨率 | 88 / 0 | [header.log](header.log) |
| 非战斗界面和远征功能 | 45 / 0 | [journey.log](journey.log) |
| 15 件遗物及组合 | 119 / 0 | [relic.log](relic.log) |

共 949 项最终断言通过。初次诊断的失败日志保留；`guardian.log` 和 `battle-ui.log` 的 headless 动画时序/投影输入检查失败，最终分别以原生渲染验证，未削弱行为断言。旧版 UI 测试以明确的墨灵夹具检查原本伤害口径；正式关卡通过独立的新怪物入口、参数和映射检查。

## 原生截图

| 角色/机制 | 截图 |
| --- | --- |
| 对校官红蓝签 | [proof_boss.png](proof_boss.png) |
| 爆印机目标格 | [bomb_press.png](bomb_press.png) |
| 铅轨机原实体行标记 | [rail_boss.png](rail_boss.png) |
| 纸壳兵 | [merged-paper_shell.png](merged-paper_shell.png) |
| 连针蜂 | [merged-needle_bee.png](merged-needle_bee.png) |
| 倾砚 | [merged-tilting_inkwell.png](merged-tilting_inkwell.png) |
| 折页蛾 | [merged-fold_moth.png](merged-fold_moth.png) |

截图等待入场动画和输入锁结束后采集。只核验既有四只新角色和墨灵动画；其余未制作新角色仍沿用字形表现回退。

## 范围与限制

本地没有提交、推送或整分支合并。本次选择性恢复所需的远端怪物实现，未引入该分支的无关经济/词效改动、发布配置或音乐分支。怪物参数从现有 `data/balance/enemies.json` 加载；该分支另一套全战斗 Excel 数值覆盖模块未接入。

全工作区范围检查包含 3704 个改动文件和 3045 个无法计算文本行数的文件，混有大量此前工作，无法通过默认 5 文件/200 行门槛，**不宣称全工作区预算通过**。见 [global-scope.txt](global-scope.txt)。有已捕获基线的文件差异另存 [captured-baseline.patch](captured-baseline.patch) 和 [captured-baseline-scope.json](captured-baseline-scope.json)，该视图不覆盖全部恢复的新文件，也不替代全工作区检查。
