# 全部敌人贴图与动画

正式资源共 29 种敌人，全部使用自己的立绘和动画。此次补画 16 张透明 PNG，保留已有 13 种贴图及其专属动画。生成使用内置 imagegen；完整提示词与图片校验值在 `assets/taopunk/enemies/batch2-manifest.json`。运行图与源图逐字节一致，导入启用 mipmaps，透明边缘使用引擎导入处理。

新增角色由七个骨骼与细分蒙皮驱动，按不同形体配置头、颚、手足、翼、印臂、印轮与卷轴权重。普通攻击、连击、防御与特殊行动有独立的蓄力、释放和回收；受击与死亡由实际生命反馈触发。三位新 Boss 在实际生命到半血线时播放转阶段动作。旧八种角色继续使用原八姿势攻击画稿，补齐其余状态；墨灵保留原蒙皮并补结茧、受击、死亡。

文件：

- `all-29-enemies.png`：实际运行的 29 种敌人总览。
- `new-16-enemies.png`：本次补画的 16 种敌人。
- `enemy-motion-preview.mp4`：原生角色的待机、攻击、施术、受击、死亡预览。
- `motion-*.png`：上述动画的关键帧。
- `battle-*.png`、`phone-*.png`：真实战斗与 640×360 窗口截图。
- `verification.json` 与测试日志：最终检查结果。

核心验证：`tests/enemy_art_completion_test.tscn` 遍历全部正式敌人，检查独立贴图、全部行动的动画与命中时序、权重归一、随机数不变、受击/死亡/减少动效，再跑新增 16 种敌人的真实敌方回合、Boss 半血转阶段与手机画幅容纳。旧角色攻击测试检查每次真实命中的独立姿势和材质轨迹，原有 PNG 校验值保持不变。怪物机制和数值回归独立执行。

```powershell
godot --path . --rendering-method gl_compatibility res://tests/enemy_art_completion_test.tscn -- --capture
godot --path . --rendering-method gl_compatibility res://tests/enemy_attack_animation_test.tscn
godot --path . --rendering-method gl_compatibility res://tests/guardian_animation_test.tscn
godot --path . --rendering-method gl_compatibility res://tests/monster_ui_test.tscn
godot --headless --path . res://tests/monster_regression.tscn
godot --headless --path . res://tests/enemy_balance_test.tscn
godot --path . --rendering-method gl_compatibility res://src/tools/capture_enemy_completion.tscn
```

最后一条命令重建图集和 60 张原生动画帧。预览视频按 12fps 编码，不能作为设备性能测量。手机截图来自桌面窗口模拟。

附带修复：攻击意图详情保留行动描述中的机制预告；敌人注入字的来源改为战斗数组稳定索引，避免运行时对象 ID 在读档后变化而破坏同源注入上限。`monster_save_test` 验证首次注入、读档后继续注入与原上限仍一致。
