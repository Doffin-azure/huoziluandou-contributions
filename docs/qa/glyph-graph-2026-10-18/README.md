# 字网图谱拖动与尺寸修复 · 2026-10-18

修复原图谱只有点选、无法平移缩放，以及窗口尺寸变化时反复挤压节点的问题。保留现有青铜边框、深青底色和体系配色。

## 行为对照

| 检查项 | 修复前 | 修复后 |
| --- | --- | --- |
| 鼠标导航 | 只有点选；不能拖动 | 左键/中键拖动平移，滚轮以指针为中心缩放 |
| 手机导航 | 只有点按 | 单指拖动平移，双指以手势中心缩放 |
| 点击与拖动区分 | 鼠标按下即选字 | 抬起且未超过 10dp 移动阈值才选字，拖动不打开详情 |
| 查看全部图谱 | 无导航按钮 | − / ＋、缩放比例、适应窗口按钮；50%～800% 相对缩放 |
| 手机详情 | 常驻右侧栏挤占图谱宽度 | 图谱使用超过 90% 屏宽；点字弹出滚动详情，关闭后继续浏览 |
| 节点大小 | 小节点和文字未考虑显示密度 | 加大基础字号；测试最紧凑配置中总览字高约 14.5dp，可继续放大 |
| 窗口变化 | 重写节点坐标、重新压缩布局 | 仅调整视野；保留已浏览中心及相对缩放；自动适应模式继续适应窗口 |
| 特殊输入 | 未处理拖动、双指与取消 | 拖出图谱后释放、触摸取消、双指抬起后的单指接续、隐藏/失焦清理、忽略触摸模拟鼠标重复事件 |
| 特殊图数据 | 单节点与孤立节点布局不完整 | 空图、单个节点、多个孤立节点和单节点自环均可安全适应 |

## 修复前后截图

采用 Godot 4.7.2 原生 Compatibility 渲染截图，手机配置通过物理窗口分辨率和 `BattleTouchLayout.test_dpi` 模拟。下表表示分辨率/密度覆盖，不代表对应手机硬件的真机性能测试。

`before/` 来自修改本次图谱代码之前的工作区，`after/` 来自修复后的同一数据集。每组均归档全部字和初始字；修复后补充了选字详情和放大平移状态。

| 配置 | 用途 | 修复前（全部字） | 修复后（全部字） | 修复后详情 | 放大平移 |
| --- | --- | --- | --- | --- | --- |
| 960×432 / 160dpi | 紧凑横屏 | [截图](before/960x432-160dpi-all.png) | [截图](after/960x432-160dpi-all.png) | [截图](after/960x432-160dpi-detail.png) | [截图](after/960x432-160dpi-zoom-pan.png) |
| 1280×720 / 桌面 | HD 桌面 | [截图](before/1280x720-0dpi-all.png) | [截图](after/1280x720-0dpi-all.png) | [截图](after/1280x720-0dpi-detail.png) | [截图](after/1280x720-0dpi-zoom-pan.png) |
| 1280×720 / 320dpi | 640×360dp 紧凑高密度横屏 | [截图](before/1280x720-320dpi-all.png) | [截图](after/1280x720-320dpi-all.png) | [截图](after/1280x720-320dpi-detail.png) | [截图](after/1280x720-320dpi-zoom-pan.png) |
| 1920×1080 / 桌面 | FHD 桌面 | [截图](before/1920x1080-0dpi-all.png) | [截图](after/1920x1080-0dpi-all.png) | [截图](after/1920x1080-0dpi-detail.png) | [截图](after/1920x1080-0dpi-zoom-pan.png) |
| 2400×1080 / 440dpi | Android 20:9 横屏 | [截图](before/2400x1080-440dpi-all.png) | [截图](after/2400x1080-440dpi-all.png) | [截图](after/2400x1080-440dpi-detail.png) | [截图](after/2400x1080-440dpi-zoom-pan.png) |
| 2532×1170 / 460dpi | 19.5:9 高密度横屏 | [截图](before/2532x1170-460dpi-all.png) | [截图](after/2532x1170-460dpi-all.png) | [截图](after/2532x1170-460dpi-detail.png) | [截图](after/2532x1170-460dpi-zoom-pan.png) |
| 3440×1440 / 桌面 | 超宽桌面 | [截图](before/3440x1440-0dpi-all.png) | [截图](after/3440x1440-0dpi-all.png) | [截图](after/3440x1440-0dpi-detail.png) | [截图](after/3440x1440-0dpi-zoom-pan.png) |

初始字对照：

| 配置 | 修复前 | 修复后 |
| --- | --- | --- |
| 960×432 / 160dpi | [截图](before/960x432-160dpi-starter.png) | [截图](after/960x432-160dpi-starter.png) |
| 1280×720 / 桌面 | [截图](before/1280x720-0dpi-starter.png) | [截图](after/1280x720-0dpi-starter.png) |
| 1280×720 / 320dpi | [截图](before/1280x720-320dpi-starter.png) | [截图](after/1280x720-320dpi-starter.png) |
| 1920×1080 / 桌面 | [截图](before/1920x1080-0dpi-starter.png) | [截图](after/1920x1080-0dpi-starter.png) |
| 2400×1080 / 440dpi | [截图](before/2400x1080-440dpi-starter.png) | [截图](after/2400x1080-440dpi-starter.png) |
| 2532×1170 / 460dpi | [截图](before/2532x1170-460dpi-starter.png) | [截图](after/2532x1170-460dpi-starter.png) |
| 3440×1440 / 桌面 | [截图](before/3440x1440-0dpi-starter.png) | [截图](after/3440x1440-0dpi-starter.png) |

## 验证

- 图谱专项：302 项通过、0 失败。真实 `Input.parse_input_event` 注入鼠标与原生触摸事件，覆盖点选时机、节点/背景拖动、双指缩放及接续、坐标命中、释放到视图外、页面隐藏、触摸取消、缩放界限、导航按钮、筛选、窗口切换和空/孤立节点等边界数据。7 组配置检查节点圆不重叠、节点及选中环完整可见、按钮在屏内且不小于 48dp、总览字高不低于 14dp。
- 触摸交互回归：102 项通过、0 失败，覆盖字网点选及其他游戏界面的既有触摸操作。
- 行旅界面回归：45 项通过、0 失败。
- 修改文件 `git diff --check` 通过。

运行方式（项目根目录）：

```powershell
godot --path . --rendering-method gl_compatibility res://tests/glyph_graph_interaction_test.tscn -- --capture
godot --path . --rendering-method gl_compatibility res://tests/touch_access_audit_test.tscn
godot --headless --path . res://tests/journey_ui_test.tscn
```

原始结果：[图谱专项](graph-test.log) · [触摸回归](touch-audit.log) · [行旅回归](journey-regression.log)。
