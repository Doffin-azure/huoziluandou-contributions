# 纸壳兵 v05：实际战斗背景预览

## 紧凑敌人信息区试验

[移除大纸面后](v05-battle-compact-header.png) · [同次运行调整前](v05-battle-compact-header-before.png)

在背景弱化预览上取消敌人身后大幅宣纸、撕边与原纸框，改为顶部小矩形纸签，承载名字、血条、护盾和行动意图。意图行略收紧，但保持图形与数值显著。纸壳兵的素材、位置、缩放和背景材质参数不变。

预览命令在场景路径后追加 `-- --mute-background --compact-enemy-header`。Godot 退出码 0，截图保存结果 OK。调整仅存在于独立预览工具，未写入正式 BattleScreen/EnemyView 的布局。

## 背景弱化试验

[弱化后](v05-battle-background-muted.png) · [同次运行处理前](v05-battle-background-before.png)

用户要求减少背景对视觉的影响。本次只在预览工具中给现有背景 TextureRect 附加 `src/art_samples/paper_shell_backdrop.gdshader`，采用低强度全局压色与敌人区平滑过渡的局部处理：降低红树饱和度、压缩场景明暗差、柔化细线。纸壳兵的位置、大小、素材和 UI 布局没有修改，源背景 PNG 也未修改。正式 StudyStage 未接入这个试验材质。

运行上面命令时末尾追加 `-- --mute-background`，会在同一帧序列中保存处理前后两张截图。Godot 退出码 0，两个文件保存成功。读取像素验证：生命条与字盘取样区差异为 0；词效和意图取样区最大差异分别为 2 和 1（半透明面板透出背景）；敌人右侧红树取样区 RGB 平均变化约 32.4。

视觉观察：身体与远景的分离改善，头部与上方宣纸面板颜色相近的问题仍然存在。本次不修改面板来掩盖这个区别。

## 原始放置预览

[完整原生截图](v05-battle-preview.png) · [透明提取素材](v05-cutout.png) · [原概念图](v05.png)

尺寸：1980×792。通过 `src/tools/paper_shell_battle_preview.tscn` 在 Godot 4.7.2 Compatibility 渲染器中运行真实战斗场景并截图。背景、字盘、边框和战况 UI 均由现有游戏绘制，没有对整张战斗画面做生成重绘。

纸壳兵使用内置 image_gen.imagegen 从 v05 提取透明底素材，再在原生敌人展示区域中等比完整显示；头足均可见，脚底与展示区底部对齐。透明提取为生成式编辑，不能保证与输入逐像素一致。原 PNG 只复制保存；透明边距通过 Godot 的 AtlasTexture 显示区域裁掉，未后期修改图片文件。

预览用临时 EnemyData：纸壳兵，32/32 生命、8 盾、攻击意图 6。仅用于示意新版名单中的状态，没有把新敌人机制接入正式战斗数据。没有替换运行素材。

命令：

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/gamejam10/huoziluandou' --rendering-method gl_compatibility --audio-driver Dummy 'res://src/tools/paper_shell_battle_preview.tscn'
```

运行结果：退出码 0，截图保存结果 OK。兼容渲染器报告了现有 StudyStage 的 TAA/景深不可用警告。

## 透明提取实际提示词

```text
Use case: background-extraction. Remove ONLY the plain dark teal background from the provided paper soldier concept and return that EXACT SAME complete character as a clean transparent PNG cutout. Preserve its current short compact proportions, blank angular face, paper folds, ivory colors, small flat antique-gold motifs on forehead and one shoulder, fine ink contours, hands, feet and every shape exactly. Preserve the artwork inside the character unchanged; no redesign, relighting, new detail, pose change, reframing of the body, extra shadow, outline halo, glow, replacement background or text. All negative space between arms and torso and between legs must be genuinely transparent too. The sole purpose is placing the existing concept into a native Godot screenshot without generating or altering the game background or UI. Transparent background, entire character visible.
```
