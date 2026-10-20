# 场景画法校准后的敌人

## 2026-10-20：器物成精

当前六位成人敌人使用 `object_creatures/` 的非人形重构：赊墨商为账册与欠条，拓印师为断碑与拓片，钤印官为悬浮铜印，轮印师为滚印机，对校官为判牍案台，万词编纂者为卷轴旋卷。取消生肖约束，保留角色职司和玩法。留白童仍使用 `human_repaint/blank_child.png`。完整提示词、生成记录与校验值在 `object_creatures/manifest.json`，原生总览、前后对照及六场战斗画幅在 `docs/qa/object-creatures-2026-10-20/`。此前各版 PNG 保留。

## 2026-10-20：人形敌人青铜面具

上一版曾使用 `zodiac_masks/` 内的鼠、牛、虎、马、蛇、龙面具；该版现作为历史稿保留。材质参照墨灵的青铜兽面。内置 imagegen 的完整提示词和资源校验值在 `zodiac_masks/manifest.json`，对应实机图及动作预览在 `docs/qa/zodiac-masks-2026-10-20/`。

## 2026-10-20：全敌人覆盖

现在全部 29 种正式敌人都有专属立绘与战斗动画。保留原有 13 种角色贴图，新绘留白童、墨蚀蠹、饕餮、炉腹兽、余电獾、赊墨商、双面简、铸巢蛾、爆印机、拓印师、钤印官、轮印师、漏电水蛭、对校官、铅轨机、万词编纂者共 16 张透明 PNG，文件名与正式敌人 ID 一致。新增图片均使用内置 imagegen 生成，原始 alpha 保留；完整提示词、源文件记录、尺寸和 SHA-256 见 `batch2-manifest.json`。

`TaopunkArt` 为全部 29 种敌人提供独立贴图映射，四个既有样例通过正式 ID 映射到原有美术文件。`EnemyAnimationCatalog` 配置新增角色的头、手足、书页、印臂和器物等活动区域，`RosterEnemyActor` 用独立骨骼和归一化蒙皮权重驱动。待机、攻击、连击、施术、防御、受击、死亡与 Boss 转阶段均由实际战斗事件触发；动作时序不消耗规则随机数。桌案、轨道与承重结构保持刚性，特效源点跟随印脚、方印、炉腹、兽颚或持笔手。

已有纸壳兵、连针蜂、倾砚、折页蛾的专属动画保留。墨灵补齐结茧与受击、死亡动作；其余八种旧角色保留八帧攻击画稿，并补上待机蒙皮、施术、防御、受击和死亡。开启减少动效会恢复静态姿态，已死亡角色不会重新待机。缩小显示启用 mipmaps。

实际战斗截图、29 种敌人总览、16 张新增图总览、动作预览视频，以及验证记录位于 `docs/qa/enemy-completion-2026-10-20/`。下文保留第一批八种角色的制作记录。

## 第一批角色记录

第一只墨灵仍使用上级目录的 `ink_guardian.png`。这里仅包含其余八只：

| 文件名 | 角色 | 形体方向 |
| --- | --- | --- |
| bronze_seal.png | 铜印 | 伏地青铜印兽、方形印面 |
| iron_seal.png | 铁画 | 长喙铁鹤、刀片双翼 |
| paper_guard.png | 纸卫 | 非对称纸偶、折扇盾 |
| rust_scribe.png | 锈笔 | 拱背笔虫、锈红罩壳 |
| ember_imp.png | 焦火 | 低伏炭核、朱红火焰 |
| boss_lead_plate.png | 铅版 | 厚重方形古制压印机 |
| boss_word_demon.png | 字魔 | 游动墨蛇、象牙色长颚 |
| boss_chaos_press.png | 混铅海 | 横向吞噬巨口、钝铅齿 |

绘制流程：以原墨灵实机画面为基准，在场景中校准线条、光色和材质，再用内置 imagegen 拆分透明角色。完整提示词和生成式同屏稿在 `docs/art-concepts/2026-10-15/style-calibration/`。透明原稿在 `assets/taopunk/source/enemies/`；本目录是轻度降噪后的运行图，均为 1402×1122 RGBA PNG。

离线增强命令（仓库根目录执行；需 numpy、Pillow、opencv-python-headless）：

```sh
python tools/enhance_enemy_art.py --source-dir assets/taopunk/source/enemies --output-dir assets/taopunk/enemies --preview-dir shots/enemy-calibrated --strength 6 --files bronze_seal.png iron_seal.png paper_guard.png rust_scribe.png ember_imp.png boss_lead_plate.png boss_word_demon.png boss_chaos_press.png
```

该步骤只处理实色区域的噪点，保留全部 alpha 及半透明边缘 RGB；不会生成细节。游戏运行无需 Python 或 OpenCV。数据报告保存于 `docs/art-concepts/2026-10-15/implemented/enemy-calibrated-report.json`。

`TaopunkArt.PORTRAIT_REGIONS` 去除透明留白，保留约 4 像素边缘余量。更换素材后应同时复核取区，不能在导入时缩小源图。导入开启 mipmaps，缩小时使用线性 mipmap 过滤；`InkSpirit.portrait_rect()` 完整容纳其他八只形体并贴住台面，墨灵保持旧比例与裁切。

原生检查命令：

```sh
godot --path . res://tools/capture_enemy_art.tscn
```

输出至忽略目录 `shots/enemy-calibrated/`，包含九场真实战斗、三种手机窗口和同屏对照。工具禁用存档且不保存设置。图中生命和意图来自实际敌人数据。手机截图是电脑窗口模拟，不代表移动设备性能验证。
