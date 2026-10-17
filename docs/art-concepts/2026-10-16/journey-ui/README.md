# 行旅 UI 重构实机记录 · 2026-10-16

此处保留第一轮平面界面的记录。商店与选卡已由 [3D 柜台 / 字匣版本](../object-menus/README.md) 取代，其他页面仍沿用这套行旅组件。

本轮把非战斗页面收敛到庭院与战斗的墨青、朱砂、米金色系。图片均来自 Godot 4.7.2 实际运行，不是生成概念稿。

## 主要页面

- [选卡](reward-desktop.png)：纸面字块、金色品阶刻点、统一说明与底部跳过操作。
- [商店](shop-desktop.png)：左侧购字，右侧删字 / 复制 / 治疗，价格操作与商品对应。
- [休整](rest-desktop.png)、[事件](event-desktop.png)、[幕地图](map-desktop.png)。
- [自定义构筑](custom_deck-desktop.png)、[远征](expedition_map-desktop.png)、[字网](glyph_graph-desktop.png)。
- [字库](collection-desktop.png)、[词库](collection-words-desktop.png)、[词条说明](effect-help-desktop.png)。
- [设置](settings-desktop.png)、[菜单](menu-desktop.png)、[岔路浮层](choice-desktop.png)。

## 手机横屏

960×432 原生窗口；按逻辑画布与窗口的比例放大说明和按钮。常规操作最低 48 屏幕像素。商店将购字价格放在字卡之前，长文可滚动。字袋按可用宽度减少列数。

[选卡](reward-phone.png) · [商店](shop-phone.png) · [休整](rest-phone.png) · [地图](map-phone.png) · [构筑](custom_deck-phone.png) · [图鉴](collection-phone.png) · [设置](settings-phone.png)

远征已改为[大地图与事件侧栏](expedition_map-phone.png) / [字阵侧栏](expedition-plate-phone.png)。格子至少 48 屏幕像素，地图纵向可滚动，走动后自动保证玩家所在格可见。切换行旅、字阵和战报不消耗步数或随机数。事件页另通过 844×390 横屏和 540×900 竖屏布局检查。

## 验证

- `journey_ui_test`：原生截图模式 59 通过 / 0 失败；另以 headless 验证菜单按钮获得焦点后 ESC 仍能关闭。
- `event_art_test`：原生截图模式 70 通过 / 0 失败。
- `title_menu_test`：原生截图模式 19 通过 / 0 失败。
- `effect_help_test`：29 通过 / 0 失败。
- `intent_design_test`：49 通过 / 0 失败。
- `expedition_test`：122 通过 / 0 失败，包含地图、商店、休整、词阵与战斗往返。
- `study_flow_test`：27 通过 / 0 失败。等待标题动画按真实时间计时，避免无帧率限制的 headless 执行把 180 帧误当成过渡时长。
- 固定种子对比修改前 fixture：奖励选项、商店内容 / 价格、事件抽取和 RNG 状态一致。
- 实际检查选卡加字、购买扣款、余额不足、治疗、拥有字列表、空列表、设置切换不重抽商品，以及说明浮层的颜色继承。

原有事件插画继续使用；本轮未重新生成插画。运行时界面素材位于 `assets/ui/journey/`，代码组织与边界见 `src/ui/journey/README.md`。
