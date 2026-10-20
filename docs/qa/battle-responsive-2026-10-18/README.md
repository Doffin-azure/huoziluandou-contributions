# 战斗布局适配与旧主题删除 · 2026-10-18

桌面不再把固定 1980×792 画布居中缩放。字盘按可用高度保持正方形，左右侧栏使用剩余宽度；手机仍按横屏空间和 DPI 分配触控区域。Buff 在桌面顶栏、手机固定预留行中展示，获得、叠加、到期、清空都不改变词效面板位置或尺寸。

宣纸活字旧主题已删除：移除 `GameStyle.paper()`、旧书房／共享桌面、旧纸张与木材贴图、6 个专用 shader 及渲染分支。保留的 StudyStage 名称仅作为路由中的轻量绘卷背景宿主，不创建旧 3D 世界或隐藏视口。旧配置中的 `paper` 等 ID 自动迁移到青铜绘卷；设置只提供内置字体选择。

## 修复前后

同一战斗种子与字盘，分别截图无 Buff、实际打出「流」后的首次 Buff、多个 Buff／双护盾。桌面 16:9 字盘高度占比由 50.7% 提升到 73.6%，左侧外边距由约 10.1% 降至 1.25%。长词效仍在固定区域内滚动。

| 分辨率／密度 | 修复前 | 修复后 | 结果 |
| --- | --- | --- | --- |
| 1280×720 桌面 | [无 Buff](before-1280x720-0dpi-empty.png) · [首个 Buff](before-1280x720-0dpi-first-buff.png) | [无 Buff](after-1280x720-0dpi-empty.png) · [首个 Buff](after-1280x720-0dpi-first-buff.png) | 字盘 50.7% → 73.6% 高度；面板固定 |
| 1920×1080 桌面 | [无 Buff](before-1920x1080-0dpi-empty.png) · [首个 Buff](before-1920x1080-0dpi-first-buff.png) | [无 Buff](after-1920x1080-0dpi-empty.png) · [首个 Buff](after-1920x1080-0dpi-first-buff.png) | 三栏扩展；面板固定 |
| 2560×1440 桌面 | [无 Buff](before-2560x1440-0dpi-empty.png) · [首个 Buff](before-2560x1440-0dpi-first-buff.png) | [无 Buff](after-2560x1440-0dpi-empty.png) · [首个 Buff](after-2560x1440-0dpi-first-buff.png) | 三栏扩展；面板固定 |
| 3200×1778（用户截图比例） | [无 Buff](before-3200x1778-0dpi-empty.png) · [首个 Buff](before-3200x1778-0dpi-first-buff.png) | [无 Buff](after-3200x1778-0dpi-empty.png) · [首个 Buff](after-3200x1778-0dpi-first-buff.png) | 字盘 51.3% → 73.6% 高度；面板固定 |
| 3440×1440 超宽桌面 | [无 Buff](before-3440x1440-0dpi-empty.png) · [首个 Buff](before-3440x1440-0dpi-first-buff.png) | [无 Buff](after-3440x1440-0dpi-empty.png) · [首个 Buff](after-3440x1440-0dpi-first-buff.png) | 正方形字盘，侧栏向两侧扩展 |
| 1280×720／320 DPI 横屏 | [无 Buff](before-1280x720-320dpi-empty.png) · [首个 Buff](before-1280x720-320dpi-first-buff.png) | [无 Buff](after-1280x720-320dpi-empty.png) · [首个 Buff](after-1280x720-320dpi-first-buff.png) | 固定状态行，面板不再下移缩短 |
| 2400×1080／440 DPI 横屏 | [历史基线，无 Buff](before-2400x1080-440dpi-empty.png) · [首个 Buff](before-2400x1080-440dpi-first-buff.png) | [无 Buff](after-2400x1080-440dpi-empty.png) · [首个 Buff](after-2400x1080-440dpi-first-buff.png) | 修复后按实际分辨率截图，触控目标保持至少 48dp |

2400×1080 的修复前历史基线实际输出为 1280×720，不能用于等分辨率像素对比；文件名保留测试请求值并在此明确说明。其余六组前后 PNG 尺寸一致。修复后七组均检查 PNG 实际尺寸。DPI 由调试参数模拟，这些图片是 Windows 原生渲染，不代表对应手机型号的真机测试。

同目录还保存每组 `many-buffs` 截图，共 42 张。修复后的压力场景含更多 Buff，前后压力截图不应按相同图标数量比较。

## 验证

| 回归项目 | 结果 |
| --- | --- |
| 原生渲染，7 组分辨率／密度、实际出字、回合到期、长词效、双护盾、多 Buff | 211 通过 / 0 失败 |
| 旧配置迁移、旧主题工厂删除、内置字体、设置无主题切换入口 | 67 / 0 |
| 正式标题 → 地图 → 战斗入口 | 8 / 0 |
| 当前美术素材、独立字盘、字体设置与布局 | 55 / 0 |
| 主菜单路由 | 16 / 0 |
| 行旅界面与操作 | 45 / 0 |
| 原生鼠标／触屏输入与战斗结算 | 58 / 0 |
| 怪物异常状态与手机显示回归 | 32 / 0 |
| 玩家状态栏回归 | 30 / 0 |
| 庭院与地图／战斗切换 | 27 / 0 |
| 新手教程交互与存档隔离 | 152 / 0 |

修复前测试重现布局问题，日志中的失败是基线证据；修复后增加了实际回合到期与长词效检查，前后检查总数不完全一致。无渲染器的测试不能替代字块投影和鼠标命中测试，因此输入回归使用 OpenGL 原生渲染器。

日志保存在本目录的 `*.log` 中。复现命令：

```powershell
& $godot --path . --rendering-method gl_compatibility res://tests/battle_responsive_layout_test.tscn -- --capture
& $godot --path . --rendering-method gl_compatibility res://tests/battle_ui_test.tscn
& $godot --headless --path . res://tests/frontend_cleanup_test.tscn
```

按用户最新要求，后续验证只在电脑本地进行，不再启动手机调试或更新 APK。本报告不以手机安装结果作为验收依据。
