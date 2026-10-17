# 折页蛾动画 · 朝向玩家的 v02

[待机循环](animation-idle.gif) · [完整动作 GIF](animation-closeup.gif) · [完整战斗画面 MP4](animation-battle.mp4) · [关键姿势](animation-keyframes.png)

使用用户确认朝向的 `v02.png`，复制到 `assets/taopunk/enemies/fold_page_moth.png`。原图逐字节保留；没有再次调用图像生成，也没有改绘或增强纹理。所有动作保持头朝左，面向玩家。

## 动作

| 动作 | 表现 | 时长 / 发力点 |
|---|---|---|
| 待机 | 两片页翅错相缓慢开合，身体轻悬，触角与两条书签延迟摆动 | 3.00 秒循环 |
| 折页标记 | 近侧页角沿单独折痕内卷，折面变暗，保留展开的双页 | 1.10 秒 / 0.55 秒 |
| 折页攻击 | 先卷角、展页蓄势，双页迅速拍合，随后分开回收 | 1.12 秒 / 0.50 秒 |
| 普通攻击 | 省去卷角准备，更快地拍合、前送和展开 | 0.94 秒 / 0.34 秒 |
| 受击 | 两页先后退让、错开回弹，书签继续回摆 | 0.48 秒 |
| 退场 | 页角收起，双页逐步闭合，身体失去悬浮并飘落淡出 | 1.12 秒 |

角色由两片页翅、身体、两根触角和两条书签共七个独立部件承载。页翅绕各自根部转动，并随闭合改变投影宽度与长度；折角按实际折痕将网格分成两面，各自保持线性变换，避免跨折痕的细三角形翻面。折角加局部折面阴影与短促折痕强调。原画中的金纹随纸面一起折叠。

拍合时页翅会收缩投影，确保翼尖不进入敌人意图区域。攻击轨迹跟随前侧页缘；没有叠加整个立绘挤压。减少动效开启时，所有页翅、折角、触角、书签恢复静态原位，只保留短结算和静态战败状态。

## 接入与边界

角色 ID 为 `fold_page_moth`，通过 `InkSpirit` 演员注册表接入 `EnemyView` 的动作、受击和死亡反馈。攻击使用现有纸片材质轨迹，按真实伤害事件分别等待发力、命中与回收。测试临时资源用 `visual_action=mark/fold_attack` 元数据指定表现；普通攻击无需额外标签。

本轮没有实现新版名单中的“标记某枚原实体、处理后从 8 减至 5、组词解除另造成 3 点机制伤害”，也未加入正式遭遇。标记仅展示折角动作，不冒充已经完成棋盘标记。实际攻击 8、5、7 由三个临时测试行动分别验证，动画不会改变这些数值。

视频采用 Godot 原生绘制的战斗背景与 UI 固定画面，角色随后逐帧原生绘制，HUD 数值固定；真实战斗回合另由测试验证。预览仍使用弱化背景和紧凑信息纸签。原生完整画面 1980×792，视频与采样 24fps，共 198 帧、8.25 秒；独立待机 GIF 为 72 帧、3 秒循环。FFmpeg 仅裁取和编码帧，不生成或重绘角色。

## 验证

折页蛾专项 56 项通过（headless 为 53 项，实际 Compatibility 渲染另含 3 项像素检查）：

- 采用正确的 v02 原图、七个部件几何有效、双页待机错相、书签余摆不同、局部卷角与普通拍合有所区别。
- 所有六类动作逐段采样：页翅网格不翻面，翼尖不遮挡敌人意图。
- 原生像素验证：纸白、旧金、墨青保留原色；折角局部可独立变形与变暗；折痕外纸面保持原位。
- 真实回合分别验证标记无伤、折页攻击 8、折页攻击 5、普通攻击 7；每次攻击只有一个独立轨迹，动作回收后恢复输入。
- 受击返回待机、退场停止、减少动效恢复静态，以及待机不消耗战斗随机数。

另有 307 项回归通过：倾砚 38、连针蜂 40、纸壳兵 37、墨灵 27、原有八只敌人的攻击 113、原生战斗 UI 52。与折页蛾专项合计 363 项通过，详见 `shots/moth-regression-*.log`。

调试中修正了拍合后翼尖过高、折角细三角形跨折痕导致翻面，以及 GDScript 字典访问处的类型推断错误。旧回归套件偶有退出阶段 ObjectDB 清理警告；预览保留现有 StudyStage 在 Compatibility 下不支持 TAA / 景深的警告。

## 复现

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/gamejam10/huoziluandou' --rendering-method gl_compatibility --audio-driver Dummy 'res://src/tools/enemy_concept_battle_preview.tscn' -- --study=res://docs/art-concepts/2026-10-17/fold-page-moth/preview-v02.json --animate --freeze-scene
```

`--freeze-scene` 只用于固定美术评审视频背景，不影响游戏。连续帧输出到 `shots/fold-page-moth-animation/`；追加 `--animation-samples` 仅输出关键姿势。

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/gamejam10/huoziluandou' --rendering-method gl_compatibility --fixed-fps 30 --audio-driver Dummy 'res://tests/fold_page_moth_animation_test.tscn'
```
