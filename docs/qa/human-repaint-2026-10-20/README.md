# 人形敌人按用户参考改绘

改绘 7 种有脸的人形敌人，采用更集中的墨黑、骨白和冷灰硬阴影，调整五官与衣褶的绘制方式，保持角色职责、道具及原有动作体系。图片由内置 imagegen 编辑生成，用户提供的图片仅作为画法参考。

- `all-seven.png`：游戏实际使用的 7 个新版角色。
- `face-comparison.png`：左侧原版、右侧改绘，逐角色比较脸部。
- `human-motion-preview.mp4`、`motion-*.png`：独立关节驱动的待机、攻击、特殊行动、受击和死亡。
- `battle-*.png`、`phone-*.png`：1280×720 及 640×360 真实战斗截图。
- `verification.json` 和测试日志：注册表、实际贴图、行动动画、受击死亡、转阶段及小屏适配验证。

新版源图位于 `assets/taopunk/enemies/human_repaint/`，其 `manifest.json` 记录完整提示词、参考图及校验值。上一版 16 张源图全部保留，非人形敌人继续使用原有贴图。战斗模型与图鉴预览统一从 `TaopunkArt` 取图。

```powershell
godot --path . --rendering-method gl_compatibility res://tests/enemy_art_completion_test.tscn
godot --path . --rendering-method gl_compatibility res://src/tools/capture_human_repaint.tscn
```

最后一条命令重建本目录的图片及 `frames/` 中的 60 张导出中间帧。视频预览为 12fps，不用于设备性能评估；手机画幅来自桌面窗口模拟。
