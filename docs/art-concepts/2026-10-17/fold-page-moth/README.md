# 折页蛾 · 单体概念

**当前采用 v02 朝向玩家的造型，已按用户要求制作动画。** 原图没有重新生成，演员纹理逐字节沿用 v02。

[待机开合 GIF](animation-idle.gif) · [完整动作 GIF](animation-closeup.gif) · [完整战斗画面 MP4](animation-battle.mp4) · [动画实现与验证](animation.md)

## v02 · 面向玩家

用户要求“朝向玩家”。按战斗布局，将身体改为朝画面左侧的侧前方飞行姿态：头和触角领向左，腹部与短书签拖向右下；近侧页翅展开，远侧页翅收窄并部分遮挡。保留纸白页翅、下角折页、墨青细躯、旧金与朱红书签，没有仅镜像原来的正面图。

[v02 透明原图](v02.png) · [v02 战斗预览](v02-battle.png) · [实际编辑提示词](v02-prompt.md)

通过内置 `image_gen.imagegen` 仅编辑 `v01.png`；原版本保留。v02 为 1402×1122 RGBA，透明通道范围 0–255；SHA-256 为 `47e07ed7c2af404cffb316b8baf7967583362e084d97cc1abcc42694fa2d1d23`。原始输出仅复制保存：`C:/Users/Lenovo/.codex/generated_images/01a128fa-5782-7363-a4ce-a77820474188/exec-416e0e55-a6ac-4d16-880f-02013c379f01.png`。

下方复现命令改用 `--study=res://docs/art-concepts/2026-10-17/fold-page-moth/preview-v02.json`，即可输出新朝向的原生战斗预览。运行退出码 0，截图保存 OK。随后已制作动画，仍未加入正式遭遇。

## v01 · 首稿

状态：单体首稿与原生战斗背景预览，等待造型评审。按新版名单顺序在倾砚之后制作折页蛾，本轮不制作其他敌人。

[透明单体图](v01.png) · [战斗背景预览](v01-battle.png) · [实际生成提示词](v01-prompt.md)

构型：两片宽窄略有差异的纸白页翅，极细墨青身体藏在中央，页翅下角各有一道折页；两条短书签一朱红、一淡赭。头部只露出触角，没有套用墨灵的面具、眉眼或其他敌人的眼型。平涂留白为主，少量旧金集中在中央与页角，没有文字排版或密集纹样。

通过内置 `image_gen.imagegen` 单独生成，唯一输入为原墨灵 `assets/taopunk/ink_guardian.png`，只作画法与配色参考。没有输入连针蜂、倾砚、纸壳兵或此前未通过的多敌概念板。原图只复制保存，没有后期改绘。图像为 1402×1122 RGBA，透明通道范围 0–255；SHA-256 为 `55685153d3909c301a0351d3d3ceb353932c87d3ded5b465fcb6b0d4dd3a1876`。

原始输出：`C:/Users/Lenovo/.codex/generated_images/01a128fa-5782-7363-a4ce-a77820474188/exec-504695be-d716-4692-9a30-6386bfbb3bb5.png`。

## 预览与边界

Godot 采用已试用的背景弱化、紧凑敌人纸签与悬浮摆放。UI 与背景由引擎原生绘制，没有让图像生成重画战斗画面。生命 32、初始盾 0，截图展示名单中的普通攻击 7 阶段。

完整名单机制为“折页攻击 5/8 → 攻击 7”：先标记一枚非固定原实体，使用或移出可降低折页伤害；组词解除另有 3 点机制伤害。概念阶段没有接入机制；随后完成的动画围绕页角内折、双页合拢与书签余摆展开，机制与正式遭遇仍留待后续接入，详见动画文档。

## 复现

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/gamejam10/huoziluandou' --rendering-method gl_compatibility --audio-driver Dummy 'res://src/tools/enemy_concept_battle_preview.tscn' -- --study=res://docs/art-concepts/2026-10-17/fold-page-moth/preview.json
```

预览退出码 0，截图保存 OK。仅有现有 StudyStage 在 Compatibility 下不支持 TAA / 景深的警告。
