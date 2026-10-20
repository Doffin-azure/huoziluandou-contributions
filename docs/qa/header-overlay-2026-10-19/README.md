# 图鉴关闭、战斗顶部与敌人动画修复

本轮使用 Godot 4.7.2 原生桌面渲染，模拟桌面与横屏手机尺寸及密度。没有连接手机、启动 Android 调试或重新打包 APK。截图为真实游戏视口，不是设计稿。

| 问题 | 修复前 | 修复后 |
| --- | --- | --- |
| 图鉴关闭按钮 | 与标题、副标题在同一个流式容器，随文字停在中间 | 标题组占据剩余空间，关闭按钮独立固定在标题栏右端，保持至少 48dp 点击高度 |
| 回合、金币、菜单 | 回合文字靠上，菜单另有负偏移；窗口缩小时菜单残留旧最小尺寸 | 三者垂直居中；先更新最小尺寸再设置实际尺寸，缩放可以正确回缩 |
| Buff 遮挡回合 | 各区域独立计算，六位金币、窗口缩放等情况会相交 | 从右向左预留菜单、金币和回合，Buff 只使用剩余宽度，超出收进“更多” |
| 窄桌面生命数字 | 1100×720 的大字号超出血条进入 Buff 区 | 数字按可用宽度缩小，并验证实际文字宽度与边界 |
| 墨灵动画停住 | 本机 settings.cfg 的 reduced_motion=true，停止骨骼播放 | 已将本机配置恢复为 false；真实攻击、注入与返回待机通过；减少动效选项继续保留 |

对比拼图左侧为修复前，右侧为修复后：[图鉴](collection-comparison.jpg)、[战斗极限数据](battle-comparison.jpg)。

墨灵：[攻击动图](guardian-attack.gif)、[动作连续帧](guardian-frames.png)。原立绘和动画脚本没有修改。动图由测试采集帧组成，用于观察姿态变化，不代表真机帧率测量。

## 分辨率截图

“战斗压力”使用回合 99、金币 999999 与多种 Buff；每组另存 normal 截图，使用回合 2、金币 6。

| 渲染尺寸 / 模拟密度 | 战斗压力：前 / 后 | 图鉴：前 / 后 |
| --- | --- | --- |
| 1920×1080 / 桌面 | [前](before-1920x1080-0dpi-battle.png) / [后](after-1920x1080-0dpi-battle.png) | [前](before-1920x1080-0dpi-collection.png) / [后](after-1920x1080-0dpi-collection.png) |
| 1280×720 / 桌面 | [前](before-1280x720-0dpi-battle.png) / [后](after-1280x720-0dpi-battle.png) | [前](before-1280x720-0dpi-collection.png) / [后](after-1280x720-0dpi-collection.png) |
| 1100×720 / 窄桌面 | [前](before-1100x720-0dpi-battle.png) / [后](after-1100x720-0dpi-battle.png) | [前](before-1100x720-0dpi-collection.png) / [后](after-1100x720-0dpi-collection.png) |
| 2560×1440 / 桌面 | [前](before-2560x1440-0dpi-battle.png) / [后](after-2560x1440-0dpi-battle.png) | [前](before-2560x1440-0dpi-collection.png) / [后](after-2560x1440-0dpi-collection.png) |
| 844×390 / 横屏布局 | [前](before-844x390-0dpi-battle.png) / [后](after-844x390-0dpi-battle.png) | [前](before-844x390-0dpi-collection.png) / [后](after-844x390-0dpi-collection.png) |
| 1280×540 / 横屏布局 | [前](before-1280x540-0dpi-battle.png) / [后](after-1280x540-0dpi-battle.png) | [前](before-1280x540-0dpi-collection.png) / [后](after-1280x540-0dpi-collection.png) |
| 2400×1080 / 440dpi 手机模拟 | [前](before-2400x1080-440dpi-battle.png) / [后](after-2400x1080-440dpi-battle.png) | [前](before-2400x1080-440dpi-collection.png) / [后](after-2400x1080-440dpi-collection.png) |
| 2340×1080 / 440dpi 手机模拟 | [前](before-2340x1080-440dpi-battle.png) / [后](after-2340x1080-440dpi-battle.png) | [前](before-2340x1080-440dpi-collection.png) / [后](after-2340x1080-440dpi-collection.png) |

## 验证

- 修复前初始顶部/图鉴检查：56 通过、24 失败，见 before.log；后续截图复查补入 8 项生命文字边界检查。
- 最终顶部/图鉴：88 通过、0 失败，见 after.log。覆盖窗口由宽变窄、状态溢出、六位金币、关闭按钮位置与关闭操作。
- 墨灵实际战斗演出：28 通过、0 失败，见 guardian.log。
- 血条/盾/状态单行稳定性：60 通过、0 失败，见 hud-regression.log。
- 状态详情：30 通过、0 失败，见 status-regression.log。
- 原生战斗 UI：60 通过、0 失败，见 battle-ui-regression.log。
- 响应式战斗布局：211 通过、0 失败，见 responsive-regression.log。

恢复正常动效后，旧 guardian/active-status 测试会在入场输入锁尚未释放时点击，已让这两个测试等待实际入场完成，并禁用其真实存档写入、隔离设置写入路径。没有修改游戏的入场锁或战斗规则。

全仓库范围检查包含大量此前未提交文件和二进制资源，不能作为本轮补丁范围通过的依据。本轮生产修改仅为 collection_overlay.gd、battle_screen.gd、status_strip.gd，相对任务开始快照的独立差异保存在 current-task-production.patch；其余既有修改保留。
