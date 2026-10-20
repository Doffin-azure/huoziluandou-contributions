# 墨池 · 紫灰夜色、贴地体积雾与鬼火

2026-10-16。按本轮反馈压低整体亮度，将绿青环境改为紫灰夜色；保留小范围暖灯，明火改用蓝紫鬼火。以下均为Godot原生运行捕获，无后期调色。

## 实机

- [全揭示总览，1920×1080](08-overview-1920.png)
- [局部与地面大字](05-local-1920.png)
- [鬼火、暖灯与怪松近景](10-ghost-fire-local-1920.png)
- [同镜头关闭体积雾对照](09-without-volume-fog-1920.png)
- [正常开局探索，1280×720](01-exploration-1280.png)
- [追逐路线](04-chase-1280.png)
- [使用后状态](07-used-states-1920.png)
- [连续岸线拼接检查](06-terrain-joins.png)

全揭示图只用于美术检查；正常游戏仍使用原有探索、视野和信标规则。标题页进入“墨途远征”即可查看当前表现。

## 调整内容

| 部分 | 当前处理 |
|---|---|
| 夜色 | 紫灰石材与木材，墨紫屋面、低强度绘制天空与偏紫的主光、边光；墨河压到近黑 |
| 地砖 | 一块石地对应一格，四档接近的夜色明度与清楚的细缝；仍为共边连续网格，不增加独立立方体边框 |
| 地面印记 | 散字去除字模底座，按格子尺寸直接印在地面；设施印记独立于模型缩放，隐藏样板中的微型重复印记 |
| 印记受光 | 字形固定朝上，细刻槽与填色接收实际灯光；遮挡淡化只影响上方物件，不把地面信息一起淡化 |
| 薄雾 | 原生FogVolume＋世界坐标雾着色器，缓慢流动、贴地分布；墨河更浓、石路更薄、行者附近留出稀薄区 |
| 鬼火 | 蓝紫外焰、冷蓝内焰和浅色焰心，较细长且略悬浮，带独立冷色点光与克制辉光 |
| 灯笼 | 保留暖色灯芯和点光，不随鬼火配色改变 |
| 人物 | 原立片接收夜色和局部光照；行者提灯补上实际暖色点光 |
| 界面 | 地图页背景、按钮、侧栏和首领沉睡提示条同步去绿，保持现有布局 |

此前接入时，散字恢复了旧字模底座、设施印记随缩小后的模型一起变小。本轮在正式地图适配器中修正，独立建筑样板保留原组件，作为历史比较。

## 调整入口

- `assets/expedition/palettes/mochi_night.tres`：当前地图的材质配色，`mochi_lantern.tres`保留为上轮对照。
- `assets/expedition/sky/mochi_night.svg`：绘制的紫夜天空。
- `src/map/expedition_map_view.gd`：原生环境、夜间光照、雾体与行者提灯。
- `src/shaders/expedition_low_mist.gdshader`：雾密度、贴地高度、漂移和岸边浓度。
- `src/shaders/expedition_ground.gdshader`：分格明度、夜色色差与接缝。
- `src/map/expedition_map_art.gd`：地面字大小、设施落点和鬼火接入。
- `src/map/expedition_stylized_fire.gd`：鬼火与原暖色火焰分开控制，现有火光样板保持兼容。

体积雾使用项目默认的Forward+渲染。墨雾与灯火仅影响表现，不修改玩法状态、不消耗玩法随机数。关闭体积雾对照也由实际视口重新渲染。

API依据：[Godot体积雾与局部雾体](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)、[雾着色器](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/fog_shader.html)。

验证场景：`tests/expedition_map_view_test.tscn`；原生捕获参数：`-- --capture --output-dir res://docs/art-concepts/2026-10-16-mochi/godot-night-mist-study`。覆盖两种分辨率、镜头与拾取、状态切换、岸线、四主题、随机数隔离、地面印记和冷暖光共存。

本轮检查：原生地图与捕获49项通过，旧火光样板20项通过。包含1280×720、1920×1080及缩放拖动后的真实拾取；运行错误日志为空。
