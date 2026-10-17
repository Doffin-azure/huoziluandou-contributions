# 倾砚动画 · 使用 v01 原版配色

[待机循环 GIF](animation-idle.gif) · [完整动作 GIF](animation-closeup.gif) · [完整战斗画面 MP4](animation-battle.mp4) · [关键姿势](animation-keyframes.png)

用户选择原版配色，增加“左右摇晃，墨汁随之晃动”。当前唯一演员纹理为 `assets/taopunk/enemies/tilting_inkstone.png`，从 `v01.png` 逐字节复制；未使用 v02 配色，也没有再次生成或改绘图片。

## 待机

砚体以底部为支点，约 3.6 秒完成一次左右找平，最大摆角约 4.3°。石面保持刚性；下方墨足随砚体拉伸、压缩，脚底始终贴住原位。墨池采用局部 UV 位移，驱动原图中的墨汁与高光：液面反向倾斜，并叠加延迟回荡与轻微波动。变形限定在池内，并在边缘收敛，保留原有眼缝、石面、鎏金与外轮廓。

图像由 884 个网格顶点、1650 个三角形承载。砚体上部按同一刚体变换移动；墨足下部平滑过渡到固定脚底。较大动作通过高度约束保留墨足的压缩空间，避免网格翻面或石体压穿脚底。退场时才解除着地约束。

## 其他动作

| 动作 | 表现 | 时长 / 发力点 |
|---|---|---|
| 左倾 | 向反方向稍作找平，再压低左侧，墨汁向侧壁回荡 | 1.20 秒 / 0.54 秒 |
| 旋转 | 支足拧身，砚面短暂收窄、左右换重，墨面余振 | 1.10 秒 / 0.52 秒 |
| 撞击 | 后撤蓄势，再以左侧砚边送出撞击，随后收回 | 1.05 秒 / 0.40 秒 |
| 受击 | 砚体退让再找平，墨面保留额外波动 | 0.48 秒 |
| 退场 | 失衡、墨足解除支撑、砚体沉落并淡出 | 1.20 秒 |

减少动效开启时，砚体、墨足和液面全部恢复原图静态状态；使用短结算时间，战败保留静态低透明度。

## 接入与边界

角色 ID 为 `tilting_inkstone`，由 `InkSpirit` 演员注册表创建。`EnemyView` 转发受击与死亡反馈；实际攻击用现有钝击轨迹，起点跟随砚体左边缘。无伤特殊动作会等待完整回收后释放输入，避免动作中途恢复玩家操作。

此轮只完成美术动画。新名单中的全盘左重力、中央 2×2 旋转规则没有在这一轮实现，新怪也未加入正式遭遇。测试临时数据用资源元数据 `visual_action=tilt/rotate` 指定表现，不依赖中文标题识别；两种 SPECIAL 仅验证无伤动作演出。普通撞击通过真实伤害事件验证为 7 伤、单次命中。

预览保持已试用的弱化背景和紧凑敌人纸签；这些调整仍限定于独立预览。视频采用 Godot 原生绘制的战斗背景与 UI 固定画面，角色随后逐帧原生渲染，HUD 数值固定；真实回合反馈另由测试验证。完整视频为 1980×792、30fps，共 267 帧、8.9 秒；独立待机 GIF 为 108 帧、3.6 秒完整循环。GIF 为敌人局部。FFmpeg 仅裁取、编码原生帧。

## 验证

307 项通过：

- 倾砚专项 38：原图哈希、双向摇摆、液面反向与滞后、脚底固定、所有动作网格不翻面、旋转与撞击差异、实际回合 7 伤、无伤动作回收、受击、退场与减少动效。
- 专项中包含 3 项原生像素检查：静止时保留原石面/旧金/墨色；砚体固定时液面像素仍变化；眼缝上方石面不受液面变形影响。
- 连针蜂 40、纸壳兵 37、墨灵 27、其他八敌人攻击 113、原生战斗 UI 52：共 269 项回归通过。

最初发现较大倾身时墨足网格翻面、特殊动作提前恢复操作，已分别加入着地高度约束和特殊动作回收等待。测试夹具也固定了字盘并清空字袋，排除正常回合补字对演出验证的影响。旧回归套件偶有退出时 ObjectDB 清理警告；预览仍有现有 StudyStage 在 Compatibility 下不支持 TAA / 景深的警告。

## 复现

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/gamejam10/huoziluandou' --rendering-method gl_compatibility --audio-driver Dummy 'res://src/tools/enemy_concept_battle_preview.tscn' -- --study=res://docs/art-concepts/2026-10-17/tilting-inkstone/preview.json --animate --freeze-scene
```

`--freeze-scene` 只用于固定美术评审视频的背景；不影响实际游戏。连续帧输出到 `shots/tilting-inkstone-animation/`。加 `--animation-samples` 只输出关键姿势。

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/gamejam10/huoziluandou' --rendering-method gl_compatibility --fixed-fps 30 --audio-driver Dummy 'res://tests/tilting_inkstone_animation_test.tscn'
```

专项使用实际 Compatibility 渲染器运行 38 项。headless 运行跳过 3 项 GPU 像素检查，其余 35 项保持有效。
