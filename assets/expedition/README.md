# 冥府碑林大地图 · 平涂立体物件与连续地形

正式远征地图已接入逐件细化的建筑、墓碑和物件，地图全屏显示。点击行者或按 **I** 展开生命、金币、墨与字匣，排字、行记和菜单收在行囊内；滚轮缩放，中键拖看，**Home** 回到行者，**M** 总览。没有常驻顶栏、右侧版面或日志。

## 当前实机

当前迷雾由真实视野和历史探索驱动：未探索被雾遮住，探索过但不在视野内暗化，当前可见区域散雾。“开灯”“夜灯”“左右”及情报揭示沿用玩法规则。石材恢复暗灰褐本色，主光接近中性月光，少量紫色侧光与蓝紫鬼火提供冷色；灯笼继续使用暖金色。

已修复边缘探索状态沿地图外延伸形成长条亮区的问题，并将运行地图描边改为跳过隐藏／镜头外模型、按时间预算分帧更新，减少拖镜时的 CPU 峰值。[定位与修正记录](../../docs/art-concepts/2026-10-17-map-performance/README.md)包含实机对照和本机测量数据。

- [美术全揭示总览，1920×1080](../../docs/art-concepts/2026-10-16-mochi/godot-engraved-floor-study/08-overview-1920.png)
- [局部近看](../../docs/art-concepts/2026-10-16-mochi/godot-engraved-floor-study/05-local-1920.png)
- [地面凹刻字近景](../../docs/art-concepts/2026-10-16-mochi/godot-engraved-floor-study/17-carved-stone-3x3-1920.png) / [同一石面受到暖光](../../docs/art-concepts/2026-10-16-mochi/godot-engraved-floor-study/18-carved-stone-lit-1920.png)
- [正常迷雾探索](../../docs/art-concepts/2026-10-16-mochi/godot-immersive-map-study/01-exploration-1280.png) / [初始视野](../../docs/art-concepts/2026-10-16-mochi/godot-immersive-map-study/11-initial-vision-overview-1280.png) / [探索记忆](../../docs/art-concepts/2026-10-16-mochi/godot-immersive-map-study/12-moved-vision-overview-1280.png)
- [点击行者展开行囊](../../docs/art-concepts/2026-10-16-mochi/godot-immersive-map-study/14-inventory-1280.png) / [熔炉材料选择](../../docs/art-concepts/2026-10-16-mochi/godot-immersive-map-study/16-forge-context-1280.png)
- [设施使用后](../../docs/art-concepts/2026-10-16-mochi/godot-immersive-map-study/07-used-states-1920.png)
- [地形拼接检查](../../docs/art-concepts/2026-10-16-mochi/godot-immersive-map-study/06-terrain-joins.png)

除正常探索图外，捕获脚本会揭示地图以检查美术。正常游戏继续使用原有迷雾、信标和视野规则。

## 表现与接口

- 固定45°斜俯视、25°弱透视镜头。连续地形与实体建筑共用世界坐标，人物与怪松的绘制面朝向相机，移动时保留近远视差。
- 问字龛、息灯亭、字摊、门阙、封匣、灯柱、墨障、四种墓碑共用暗色调色板、面色、墨线和原生灯光。屋面保持近黑蓝灰，暖灯仅作小面积强调。
- 地面沿用共边网格、圆角岸线和下沉0.32的墨水面。三个接近的石色按世界坐标混合，分格明度与细缝对应玩法网格；地面与岸壁接收实际光照和物件阴影。
- 设施落脚格、散字与机关均保留字体显示的汉字。奖励开匣、休息与事件熄灯、墨障碎石、开闭闸门对接原状态；其余三主题共用渲染结构，机关逻辑保留。
- 地面字使用石材凹刻材质：与脚下地板共用世界坐标石色、纹理、分格、湿边、灯光和视野遮罩，暗槽与细窄切边替代白色填色。火字只有少量冷色火星，没有额外强光；消耗或离开当前视野后关闭。
- `ExpeditionMapView.refresh(ex, boss_steps)` 同步表现；`cell_pressed(k)` 转发移动，`walker_pressed()` 打开行囊；`cell_at(point)` 进行地面射线换算，`pick_cell(point)` 补充立体设施包围范围，`walker_at(point)` 进行人物立片透明像素拾取。
- 可走格中心保留交互，遮挡行者或邻近可走格的高物件淡化。迷雾外的已知建筑暗化并关闭局部灯光，重新可见时复用原模型。
- 保留12×8四向移动、地图种子、随机数、排字机制和远征战斗往返。排字为行囊中的二级入口；奖励、商店与战斗等事件按需展开，熔炉同时展开字匣以选择材料。日志只显示短暂提示，完整记录在行囊的“行记”内查看。美术适配器仅负责显示。

## 资源入口

| 资源 | 用途 |
|---|---|
| `src/map/expedition_map_art.gd` | 将细化组件缩放、镶字并映射到真实地图事件状态 |
| `src/map/expedition_flat_style.gd` | 共享面色、像素墨线与轮廓缓存 |
| `palettes/mochi_night.tres` | 当前暗灰褐石材、深色屋面、木材和暖灯色 |
| `src/shaders/expedition_ground.gdshader` | 夜色分格石地、细缝和低对比色差 |
| `src/shaders/expedition_stone_surface.gdshaderinc` | 地板与刻字共用的石材取样 |
| `src/shaders/expedition_engraved_glyph.gdshader` | 暗刻槽、磨损切边与凹面受光 |
| `src/map/expedition_glyph_mask.gd` | 从字体缓存生成可复用的单字笔画遮罩 |
| `src/shaders/expedition_shore.gdshader` | 连续岸壁和湿边 |
| `sky/mochi_night.svg` | 绘制天空提供低强度环境光 |
| `map-actors.png` + `.json` | 暂时沿用的行者与敌人立片；人物美术待后续统一 |

旧设施图集及生成材质保留作过程资料和早期样板兼容，正式地图的建筑、箱子、墨障、墓碑与树已使用代码原生组件。最新交付见 [石地凹刻字](../../docs/art-concepts/2026-10-16-mochi/godot-engraved-floor-study/README.md)；界面改动见 [全屏地图与自然夜色](../../docs/art-concepts/2026-10-16-mochi/godot-immersive-map-study/README.md)，视野实现见 [玩法视野迷雾说明](../../docs/art-concepts/2026-10-16-mochi/godot-vision-fog-study/README.md)。

## 园林模型与运行地图

新增月洞门、碑纹照壁、双间游廊、平拱石桥，以及支持整段、半段、共用柱、转角和残损状态的栏杆与围墙模块，共十六个独立场景。见 [园林资产说明](garden/README.md) 和 [原生实机预览](../../docs/art-concepts/2026-10-17-garden/godot-garden-model-study/README.md)。

运行 `res://src/tools/expedition_garden_lab.tscn` 可单独转看、缩放、改色和检查拼接。实际远征已接入 `garden_v1` 园林布局，桥面与游廊可走、实体建筑占地不可走，设施入口留在建筑前方。规则取舍见[地图生成与园林接入记录](../../docs/地图生成规则与园林接入记录.md)，画面见[实际生成截图](../../docs/art-concepts/2026-10-17-garden/godot-generated-garden/README.md)。

地图现已沿四边完整围墙围合，实墙与回纹、海棠、冰裂三种八角漏窗交替；墙基保持连续，近侧遮挡时局部淡化。主要池塘复用此前的盛莲、花苞和残荷几何，不重复叠加方形水面。见[最新围墙与荷花实机](../../docs/art-concepts/2026-10-17-garden/godot-closed-lotus-garden/README.md)。

## 持灯行者低模样模

新增独立原生角色 `characters/lantern_traveler.tscn`：空心兜帽、折面面具、朱砂围巾、连续披肩与提灯，1,934 个三角面，配色可编辑并接收真实灯光。预览入口 `res://src/tools/expedition_traveler_lab.tscn`；见 [角色资产说明](characters/README.md) 与 [原生渲染三面图](../../docs/art-concepts/2026-10-17-traveler/README.md)。这次用于确认造型，尚未替换游戏内行者或制作行走骨骼。

## 莲池格子与池岸组件

新增荷叶、含苞、盛莲、残荷、刻字踏石五种格子与四种岸线场景，支持八邻接拼成连续水面。每格占 1×1，水位与现有墨水地形一致。见 [莲池资产说明](lotus/README.md) 和 [3×3 原生实机预览](../../docs/art-concepts/2026-10-17-garden/godot-lotus-tile-study/README.md)。预览入口为 `res://src/tools/expedition_lotus_lab.tscn`。

另补八个无植物／局部水面场景，包括左上极小片、偏角、半格直岸与弧岸、斜半片和内湾。通过共用顶点场拼成非矩形池塘，水岸可经过格子内部。局部水片采用较浅水位，详见 [格内水岸说明](lotus/README.md#无莲叶与格内水岸扩展) 与 [拼接实机图](../../docs/art-concepts/2026-10-17-garden/godot-water-shape-study/README.md)。独立入口为 `res://src/tools/expedition_pond_shape_lab.tscn`。

莲叶进一步改为独立种子生成，增加疏散小叶、小叶丛与细小散叶三种预制场景。叶片大小、数量与位置有变化，纯叶片层也可铺在不规则水面上并避开石地。莲池预览提供布局种子和“换一组”按钮，见 [零散小叶实机图](../../docs/art-concepts/2026-10-17-garden/godot-lotus-scatter-study/README.md)。

## 检查

```text
<godot> --headless --path . res://tests/expedition_test.tscn
<godot> --path . res://tests/expedition_map_view_test.tscn -- --capture
<godot> --path . res://tests/expedition_terrain_gallery.tscn
```

渲染捕获使用项目默认Forward+，输出到临时目录 `huozi-map3d`，也可用 `--output-dir res://...` 指定位置。测试检查两种分辨率的拾取、缩放拖动、真实视差、随机数隔离、岸壁接合、原生物件状态、视野切换、四主题以及事件操作。
