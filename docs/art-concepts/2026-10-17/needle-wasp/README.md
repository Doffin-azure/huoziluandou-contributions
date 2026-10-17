# 连针蜂 · 单体概念 v01

状态：造型已获用户认可，已制作连续扇翅待机、三连点刺、蓄势重刺、受击与退场动画。沿用这张原图，本轮没有重新生成或修改角色图片，也未制作其他敌人。

[独立透明概念图](v01.png) · [真实战斗背景预览](v01-battle.png)

[动画局部预览](animation-closeup.gif) · [完整战斗画面视频](animation-battle.mp4) · [动画实现与验证](animation.md)

造型：非人形蜂虫，墨青小头胸、细腰、后垂针腹与长尾针；狭长浅色膜翅，与暗色身体形成对比。眼部采用完整黑色虫眼，没有人类眼白、眼睑或斜眉。旧金修饰集中在头胸、腹侧与尾针连接，保持平涂。

内置 image_gen.imagegen 单独生成此怪物，仅输入原墨灵作为画法和旧金配色参考。全图为 1402×1122 RGBA；核实透明通道存在，原生成 PNG 只复制保存，没有后期修改。完整实际提示词见 [v01-prompt.md](v01-prompt.md)。

战斗画面由 Godot 原生绘制：沿用已试用的背景弱化与紧凑敌人信息纸签。示意生命 34、无初始盾、三段 3 伤意图；采用悬浮摆放，脚部不贴台面。图中 UI 没有生成重绘。演员已接入真实战斗反馈，尚未把新怪加入正式遭遇名单；样片的动作展示与实战结算验证分别记录于动画文档。

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/gamejam10/huoziluandou' --rendering-method gl_compatibility --audio-driver Dummy 'res://src/tools/enemy_concept_battle_preview.tscn' -- --study=res://docs/art-concepts/2026-10-17/needle-wasp/preview.json
```

运行退出码 0，截图保存 OK。仅出现现有 StudyStage 在 Compatibility 渲染下的 TAA 和景深不可用警告。
