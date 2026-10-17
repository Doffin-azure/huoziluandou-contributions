# 连针蜂动画

[扇翅待机 GIF](animation-idle.gif) · [连续动作 GIF](animation-closeup.gif) · [完整战斗画面 MP4](animation-battle.mp4) · [关键姿势](animation-keyframes.png)

使用用户认可的 v01 透明原图，逐字节复制到 `assets/taopunk/enemies/needle_wasp.png`。本轮没有再次调用图像生成，也没有增强、重绘或改动原 PNG。Godot 通过同一纹理的十一块 Polygon2D 与父子关节完成动画。

## 动作

| 动作 | 表现 | 时长 / 发力点 |
|---|---|---|
| 扇翅待机 | 原图的三片可见膜翅错相展开、折拢；身体轻微悬浮，足部延迟摆动 | 翅膀基础频率 7 Hz，持续运行 |
| 三连点刺 | 每击分别收腹、送针、回收，三次刺击高度略有区别 | 0.46 / 0.43 / 0.48 秒；发力 0.16 / 0.13 / 0.15 秒 |
| 蓄势 | 抬身卷腹，振翅加快，暂不攻击 | 1.00 秒 |
| 重刺 | 后撤蓄力、短暂停顿，再由腰、腹和针依次甩出 | 1.08 秒；发力 0.48 秒 |
| 受击 | 躯干后让，腹部与尾针延迟回摆 | 0.42 秒 |
| 退场 | 振翅逐渐减慢、收拢，身体翻落，尾部跟随并淡出 | 1.15 秒 |

翅膀独立于动作播放器计算，切换攻击不重置振翅相位；不是整张立绘往返平移。腰—腹—针采用连续父子关节，轨迹起点跟随尾针尖端。攻击局部只添加短促针痕，使用现有窄刃轨迹传递实际命中。开启减少动效后恢复静态展翅，保留简短结算时间和静态战败状态。

## 接入与边界

`InkSpirit` 通过角色注册表识别 `needle_wasp`，按演员自身画幅等比适配，保留纸壳兵和墨灵各自的动作。`EnemyView` 传递受击、死亡反馈；`BattleScreen` 在每个真实伤害事件前播放对应点刺，并从当前针尖发出轨迹。

连针蜂未加入正式遭遇名单。专项测试创建生命 34、三连击 3×3、蓄势不攻击、重刺 10 的临时 EnemyData，完整运行三个真实回合。背景弱化和紧凑纸签仍限定在美术预览场景。视频逐帧采样展示动作，HUD 保持固定；实际伤害、攻击次数和时序由真实战斗测试验证。

动画帧来自 Godot 原生渲染，共 205 帧、30fps、约 6.83 秒。完整视频为 1980×792；GIF 展示敌人局部，另附单独的一秒扇翅待机循环。FFmpeg 仅用于裁取原生画面和编码，不生成或重绘素材。

## 验证

共 269 项通过：

- 连针蜂专项 40：原纹理哈希、十一片有效三角化、翅膀独立错相、攻击保留振翅相位、点刺与重刺差异、针尖位置、真实三连伤害与三个独立轨迹、无伤蓄势、单次重刺、受击恢复、死亡停止、减少动效、演员切换和待机不消耗战斗随机数。
- 纸壳兵 37、墨灵 27、原八只敌人攻击 113：原有动作和命中流程回归。
- 原生战斗 UI 52：使用实际 Compatibility 渲染器验证投影点击、交互、异步队列和浮层。

初次专项测试发现后足多边形交叉，已修正轮廓，重跑 40/40。旧测试运行时偶有退出阶段 ObjectDB 清理警告；预览仍出现现有 StudyStage 在 Compatibility 下不支持 TAA / 景深的警告。

## 复现

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/gamejam10/huoziluandou' --rendering-method gl_compatibility --audio-driver Dummy 'res://src/tools/enemy_concept_battle_preview.tscn' -- --study=res://docs/art-concepts/2026-10-17/needle-wasp/preview.json --animate
```

追加 `--animation-samples` 只输出八张关键姿势；完整模式在 `shots/needle-wasp-animation/` 输出连续帧。

```powershell
& 'C:/Users/Lenovo/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 30 --path 'E:/gamejam10/huoziluandou' --audio-driver Dummy 'res://tests/needle_wasp_animation_test.tscn'
```
