# 场景画法校准后的敌人

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
