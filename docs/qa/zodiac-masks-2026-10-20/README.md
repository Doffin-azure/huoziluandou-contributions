# 生肖面具接入验证

当前版本为 6 种独立生肖青铜面具，留白童使用上一版立绘。本目录预览来自游戏实际贴图与动画。

- `six-zodiac-masks.png`：鼠、牛、虎、马、蛇、龙 6 种面具近景。
- `all-seven.png`：6 位覆面角色及保留原样的留白童。
- `mask-comparison.png`：上一版人形与当前头部逐个对照，留白童两侧相同。
- `human-motion-preview.mp4`、`motion-*.png`：独立骨骼驱动的待机、攻击、特殊行动、受击和死亡。
- `battle-*.png`、`phone-*.png`：真实战斗的桌面及手机画幅。
- `verification.json`、日志：全敌人贴图和动画覆盖、历史资源完整性及留白童源图保留校验。

资源与内置 imagegen 完整提示词：`assets/taopunk/enemies/zodiac_masks/manifest.json`。

```powershell
godot --path . --rendering-method gl_compatibility res://src/tools/capture_human_repaint.tscn -- --zodiac-masks
godot --path . --rendering-method gl_compatibility res://tests/enemy_art_completion_test.tscn
```

视频为 12fps 采样预览，不用于性能评估。手机画幅由桌面窗口调整尺寸模拟。
