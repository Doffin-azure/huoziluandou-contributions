# 战斗入场动画 · 2026-10-18

新增约 0.96 秒的「活字入阵」转场：四枚活字依次落印，配合一次现有木块音效；两扇青铜色屏风向两侧展开，字盘入场动效随之播放，完成后恢复操作。

![实际运行录制](battle-entrance-preview.gif)

GIF 取自原生渲染器运行帧，末帧延长便于观察战场。

| 战斗入口 | 表现 |
| --- | --- |
| 普通地图战斗 | 活字入阵 + 节点名称 + 敌人名称 |
| 精英 / 岔路精英 | 精英临阵，朱红边框 |
| 远征首领 | 首领现身，朱红边框 |
| 读档续战 | 直接恢复战斗，无重复入场转场 |
| 减少动态效果 | 直接进入战场，无入场转场 |

动画只使用轻量 2D 绘制和节点绑定 Tween；不新增外部图片、全屏模糊或视频资源，不消耗战斗 RNG。动画期间锁定字盘、结束回合和菜单，并拦截键盘/鼠标/原生触摸；结束恢复操作。退出当前界面会释放动画；中途切换减少动态效果也会结束动画并解锁。

## 横屏截图

手机通过窗口分辨率和 DPI 注入模拟；属于布局检查，不代表手机真机性能测试。

| 配置 | 落字 | 落印完成 | 展开 | 战场 |
| --- | --- | --- | --- | --- |
| 1280×720 桌面 | [截图](1280x720-0dpi-stamp.png) | [截图](1280x720-0dpi-settled.png) | [截图](1280x720-0dpi-reveal.png) | [截图](1280x720-0dpi-ready.png) |
| 1280×720 / 320dpi | [截图](1280x720-320dpi-stamp.png) | [截图](1280x720-320dpi-settled.png) | [截图](1280x720-320dpi-reveal.png) | [截图](1280x720-320dpi-ready.png) |
| 2400×1080 / 440dpi | [截图](2400x1080-440dpi-stamp.png) | [截图](2400x1080-440dpi-settled.png) | [截图](2400x1080-440dpi-reveal.png) | [截图](2400x1080-440dpi-ready.png) |
| 3440×1440 超宽桌面 | [截图](3440x1440-0dpi-stamp.png) | [截图](3440x1440-0dpi-settled.png) | [截图](3440x1440-0dpi-reveal.png) | [截图](3440x1440-0dpi-ready.png) |

## 验证

- [入场专项](entrance-test.log)：39 项通过、0 失败，覆盖操作锁定、结束解锁、规则与 RNG 不变、首局引导、读档跳过、减少动态效果、切屏清理、三个战斗入口和四组横屏截图。
- [战斗交互回归](battle-ui-test.log)：60 项通过、0 失败。原测试现在等待真实入场结束后再操作字盘。
- [首局引导回归](first-run-test.log)：9 项通过、0 失败。
- [自动存档回归](autosave-test.log)：44 项通过、0 失败。

复现：

```powershell
godot --path . --rendering-method gl_compatibility res://tests/battle_entrance_test.tscn -- --capture
godot --path . --rendering-method gl_compatibility res://tests/battle_ui_test.tscn
godot --headless --path . res://tests/first_run_tutorial_test.tscn
godot --headless --path . res://tests/autosave_test.tscn
```
