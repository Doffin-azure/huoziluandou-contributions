# 青铜面具接入验证

7 个人形敌人改为墨灵同系的青铜兽面，遮住原有人脸。使用内置 imagegen；完整提示词及资产记录在 `assets/taopunk/enemies/bronze_masks/manifest.json`。

- `all-seven.png`：游戏实际使用的 7 个新版角色。
- `mask-comparison.png`：上一版与青铜覆面的头部对照。
- `human-motion-preview.mp4`、`motion-*.png`：待机、攻击、特殊行动、受击和死亡。
- `battle-*.png`、`phone-*.png`：真实战斗的桌面及手机画幅。
- `verification.json`、测试日志：资源完整性及全敌人动画接入验证。

重新导出截图：

```powershell
godot --path . --rendering-method gl_compatibility res://src/tools/capture_human_repaint.tscn -- --bronze-masks
```

运行覆盖测试：

```powershell
godot --path . --rendering-method gl_compatibility res://tests/enemy_art_completion_test.tscn
```

视频为 12fps 采样预览，不用于性能评估；手机画幅由桌面窗口调整尺寸模拟。
