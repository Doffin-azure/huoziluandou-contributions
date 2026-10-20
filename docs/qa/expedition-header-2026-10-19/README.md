# 幕地图顶部状态栏修复

用户截图对应的是 `map_screen.gd` 的幕地图页面。根因是桌面标题栏把气血、金币、字袋和菜单放进了 `HFlowContainer`；容器在可用宽度不足时自动换行，导致右侧控件堆叠，标题面板被撑高，地图被压缩。

本次只修改了 [map_screen.gd](/E:/gamejam10/huoziluandou/src/screens/map_screen.gd) 的顶部状态行：桌面和手机都使用单行 `HBoxContainer`，桌面增加固定间距；手机原有标题与状态的紧凑布局保持不变。没有改地图规则、按钮功能、背景、美术资源或 Android 构建。

| 区域 | 修复前 | 修复后 |
| --- | --- | --- |
| 顶部标题栏 | 状态控件被流式布局换到多行，右侧出现纵向堆叠，标题栏占据过高空间 | 标题、气血、金币、字袋、菜单在同一行，标题栏高度由一行内容决定 |
| 地图区域 | 被高标题栏挤压，节点路线可视空间变小 | 顶部栏收紧，节点路线恢复完整高度 |
| 横屏手机 | 状态行可能跟随桌面换行逻辑 | 保留原有紧凑横屏布局和触控尺寸 |

截图：

- [修复后幕地图 1280×720](../../../../shots/journey-after-map.png)
- [修复前旧基线截图](../../../../shots/journey-before-map.png)

## 验证

- 原生 Godot 渲染 `tests/journey_ui_test.tscn -- --capture`：71 通过、0 失败，见 [journey-map-fix.log](journey-map-fix.log)。
- 无渲染器 `tests/journey_ui_test.tscn`：45 通过、0 失败，见 [journey-headless.log](journey-headless.log)。
- 横屏手机密度与触控布局 `tests/mobile_density_layout_test.tscn`：80 通过、0 失败，见 [mobile-density.log](mobile-density.log)。

这里的“修复前”截图来自现有基线；它使用旧版主题，主要用于记录堆叠前的布局状态。修复后截图使用当前青铜绘卷主题和真实游戏状态。
