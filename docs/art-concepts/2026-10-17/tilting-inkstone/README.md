# 倾砚 · 单体概念

**当前采用 v01 原版配色。** 用户已确认原版优于 v02，随后授权制作动画；v02 仅留作对比记录。

[待机：左右摇摆与墨汁回荡](animation-idle.gif) · [完整动作 GIF](animation-closeup.gif) · [完整战斗画面视频](animation-battle.mp4) · [动画实现与验证](animation.md)

## v02 · 增加颜色对比（未采用）

按用户要求，在 v01 上通过内置 `image_gen.imagegen` 做局部配色编辑：砚体正面提亮为矿物石青，右侧厚面保持深青；上角旧金面积略增；左下既有边框增加一片朱红漆色，墨池与墨足仍为深墨。保持偏斜砚体、不等长眼缝与两只软墨足。原 v01 保留。

[v02 透明原图](v02.png) · [v02 战斗背景预览](v02-battle.png) · [v02 实际编辑提示词](v02-prompt.md)

v02 为 1375×1144 RGBA，透明通道范围 0–255；SHA-256 为 `3ed26a1df4b8508c8bdc0c8df04c9fc263506c05d5a99791b29027c13c40b810`。原始输出仅复制保存：`C:/Users/Lenovo/.codex/generated_images/01a128fa-5782-7363-a4ce-a77820474188/exec-debaec02-c2eb-460e-b426-e0f9383105ba.png`。

原生预览使用下方命令，将 `--study` 改为 `res://docs/art-concepts/2026-10-17/tilting-inkstone/preview-v02.json`。运行退出码 0，截图保存 OK；只调整美术评审素材，没有修改战斗代码或加入正式遭遇。

## v01 · 初稿

状态：原版造型与配色已获认可。按用户新版名单在连针蜂之后制作倾砚，本轮只有这一个敌人。

[透明单体原图](v01.png) · [Godot 战斗背景预览](v01-battle.png) · [实际生成提示词](v01-prompt.md)

构型为偏斜的厚砚体、上沿两道不等长眼缝、凹入墨池与两只长短不一的软墨足。没有另加人形头身、手臂或服装。石青主面、深墨池和墨足保持大块明暗；旧金集中在上角修补处，小朱印留在下侧。墨池保留清楚的液面，以表现倾斜与重量。

工具：内置 `image_gen.imagegen`，仅传入原墨灵 `assets/taopunk/ink_guardian.png` 作为画法参考，没有把连针蜂、纸壳兵或未通过的多人概念板输入本次生成。原文件复制保存，没有后期改绘或增强。图像为 1375×1144 RGBA，透明通道范围 0–255；SHA-256 为 `def992f050b9545c0d0c5063deae4e2241502206840f48bfa4a0a2a056743930`。

原始生成路径：`C:/Users/Lenovo/.codex/generated_images/01a128fa-5782-7363-a4ce-a77820474188/exec-f050abef-9d3b-4cc7-8d05-e5d4c2755caf.png`。

## 预览与机制边界

场景沿用已试用的背景弱化和紧凑敌人纸签；角色完整落在台面上。生命 34、初始盾 0，截图展示名单中攻击 7 的行动阶段。原名单完整循环为“全盘左重力 → 攻击 7 → 中央 2×2 顺时针旋转 → 攻击 7”；本轮是美术预览，没有用通用 SPECIAL 替代实现这些新机制，也没有加入正式遭遇。

UI 与背景由 Godot 原生绘制，只替换预览中的透明角色，未让图像生成重画游戏画面。后续已沿用此版制作找平待机、压重左倾、支足拧转、砚体撞击、受击和退场，具体接入边界见动画文档。

## 复现

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/gamejam10/huoziluandou' --rendering-method gl_compatibility --audio-driver Dummy 'res://src/tools/enemy_concept_battle_preview.tscn' -- --study=res://docs/art-concepts/2026-10-17/tilting-inkstone/preview.json
```

预览退出码 0，原生截图保存结果 OK。仅有现有 StudyStage 在 Compatibility 下的 TAA / 景深不可用警告。
