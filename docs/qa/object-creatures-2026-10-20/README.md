# 器物成精接入验证

本轮重点是 6 位敌人的整体身体结构，不再将生肖作为造型约束。留白童保留原样。

- `six-object-creatures.png`：通过真实角色渲染的新版六只总览。
- `all-seven.png`：新版六只及保留的留白童。
- `before-after.png`：上一版人形与当前器物形体的对照。
- `object-motion-preview.mp4`、`motion-*.png`：待机、攻击、施术、受击与死亡的接入预览。
- `battle-*.png`、`phone-*.png`：全部六只的真实战斗桌面与手机画幅。
- `verification.json`、日志：全敌人功能覆盖与资源完整性检查。功能测试不代表艺术质量评价。

资源与内置 imagegen 提示词：`assets/taopunk/enemies/object_creatures/manifest.json`。

```powershell
godot --path . --rendering-method gl_compatibility res://src/tools/capture_object_creatures.tscn
godot --path . --rendering-method gl_compatibility res://tests/enemy_art_completion_test.tscn
```

视频为 12fps 采样预览。手机画幅来自桌面窗口模拟，不代表移动设备性能验证。
