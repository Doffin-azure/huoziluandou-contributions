# 冥府园林模型组

四种建筑与十二种边界构件，沿用当前地图的暗色石材、近黑屋面、低饱和铜绿、少量旧金和像素墨线。模型为真实网格，接受原生灯光与阴影；月洞门、漏窗、栏杆和桥下拱洞均为几何开口。

新增[凉亭、假山与二层小阁](../../../docs/art-concepts/2026-10-18-garden-landmarks/index.html)：`square_pavilion.tscn`、`hex_pavilion.tscn`、`low_rockery.tscn`、`hollow_rockery.tscn`、`small_loft.tscn`。这五件场景根缩放为 1，使用直接世界单位。独立工作台是 `res://src/tools/garden_landmark_lab.tscn`；现已用于庭院路线模式的房间内设。

新增[红枫与园林树木](../../../docs/art-concepts/2026-10-18-garden-trees/index.html)：`red_maple.tscn`、`leaning_red_maple.tscn`、`crooked_pine.tscn`、`weeping_willow.tscn`、`bare_locust.tscn`。五件树木根缩放为 1，共享色板与光照，保留根部占地和整体视觉范围；工作台为 `res://src/tools/garden_tree_kit_lab.tscn`。其中红枫、怪松、垂柳、枯槐现已用于庭院房间，斜生红枫仍保留为可选资产。

新增[八类房间内设](../../../docs/art-concepts/2026-10-18-furnished-rooms/index.html)，并补齐六件家具：`stone_table.tscn`、`writing_desk.tscn`、`stone_bench.tscn`、`incense_burner.tscn`、`lotus_tub.tscn`、`type_rack.tscn`。同为世界单位、根缩放 1；房间工作台是 `res://src/tools/garden_furnished_rooms_lab.tscn`，与实际地图共用装配、遮挡及门位避让规则。

这批模型保留独立工作台，同时已由 `garden_v1` 生成器接入实际远征。月洞门、石桥、游廊、照壁按布局选择，栏杆沿岸拼接，外围使用围墙与漏窗。庭院工作台仍是便于检查比例和调色的模型样板。见[运行接入记录](../../../docs/地图生成规则与园林接入记录.md)。

实际地图四边已沿 12×8 的真实边界闭合，四十段围墙与四十枚共享立柱连接，没有残墙或出口缺口；旧图／回退地图也沿用同一围合方式。墙基连续伸到水位以下，近侧墙遮挡玩家时仅局部淡化，墙基保持不透明。围墙随相邻边缘格的探索状态显示，未探索部分不提前泄露。

## 建筑

| 场景 | 内容 | 默认比例下的主要尺寸 |
|---|---|---|
| `moon_gate.tscn` | 月洞门；圆洞厚壁、切石门圈、深色瓦檐、封印及小灯笼 | 门体宽 2 格，屋面约 2.09 格 |
| `screen_wall.tscn` | 碑纹照壁；双面山形碑纹、石座、支脚及压暗屋面 | 基座约 1.75 × 0.48 格 |
| `covered_walk.tscn` | 双间游廊；六柱、斜撑、坐凳、后侧栏和两盏吊灯 | 基座约 2.16 × 0.87 格 |
| `stone_bridge.tscn` | 平拱石桥；凹弧桥腹、桥墩、石板桥面；栏杆复用模块 | 约 2.13 × 1.03 格；桥面 y=0 |

## 边界模块

| 栏杆 | 围墙 |
|---|---|
| `rail_straight.tscn`：整段 | `wall_straight.tscn`：实墙整段 |
| `rail_half.tscn`：半段 | `wall_window.tscn`：八角漏窗整段 |
| `rail_post.tscn`：共享立柱 | `wall_post.tscn`：共享墙柱 |
| `rail_end.tscn`：收口端柱 | `wall_end.tscn`：收口端柱 |
| `rail_broken.tscn`：残损段 | `wall_broken.tscn`：残损墙体 |
| `rail_corner.tscn`：直角转接 | `wall_corner.tscn`：直角转接 |

### 拼接尺寸

- 制作单位：整段长度 **2**，场景根节点默认缩放 **0.5**，落到游戏尺度即 **1 格**；半栏杆长度 **1**，即半格。
- 直段原点是左侧柱中心，沿本地 **+X** 延伸。连接点为 `Socket0` 和 `Socket1`，高度统一为 y=0；改变朝向用 90° 整数倍旋转。
- 段体不含端柱。相邻直段、转角与收口共用柱中心，柱只放一枚；栏杆顶梁和墙身留有被柱遮住的接合余量。
- 手工直角件自带角柱和两条正交段体，连接口在本地 `(2,0,0)` 与 `(0,0,2)`。不再在角柱处叠放另一枚立柱。
- 自动路径拼接使用“直段＋唯一立柱”，支持直连、内外转角、闭合回折、栏杆半段和开口端柱；漏窗可与实墙交替。
- 围墙帽采用沿段长不变的截面，避免每段中央鼓起或接头低陷；墙柱瓦帽覆盖交接。正常围墙高约 1 格，栏杆高约 0.55 格。

### 园林窗棂

八角漏窗保留真实墙厚和内凹边框，窗棂为立体构件，双面可见并投射阴影。`window_pattern` 支持回纹、海棠、冰裂三种图案；自动拼墙时依次轮换，与实墙交替，配色仍使用共享的暗色石材、铜绿和近黑瓦檐。它们均为不可穿行的窗，不生成通路。[三种窗棂近看](../../../docs/art-concepts/2026-10-17-garden/godot-closed-lotus-garden/05-garden-window-lattices-1920.png)。

### 通过路径摆放

```gdscript
const Boundary = preload("res://src/map/expedition_garden_boundary.gd")

var holder := Node3D.new()
holder.scale = Vector3.ONE * .5
add_child(holder)
var points: Array[Vector3] = [
    Vector3(0,0,0), Vector3(6,0,0), Vector3(6,0,4)
]
var rail := Boundary.assemble(holder, shared_style, points)
# 围墙：Boundary.assemble(holder, shared_style, points, true)
# 闭合：第五个参数 closed=true；第六个参数 windows=true 交替使用漏窗。
```

路径使用制作单位，保持正交。围墙路径边长为 2 的倍数；栏杆还支持多出 1 的半段。该函数只构建表现节点，不创建玩法格子或消耗随机数。

## 查看与改色

在 Godot 中运行 `res://src/tools/expedition_garden_lab.tscn`。可切换四种建筑、栏杆页、围墙页、拼接检查和庭院组合；左键转看，中键拖看，滚轮缩放，开启“拼接锚点”查看共用柱位置。暖光可以关闭，石材、屋面和铜绿支持现场调整。

这些 `.tscn` 是程序化模型场景，运行时生成网格。直接实例化会读取根节点的 `palette_source`；由统一美术适配器使用时，可调用 `setup(shared_style)` 共用调色板与墨线。新场景也生成连接用的 `Marker3D`。

默认调色板为 `res://assets/expedition/palettes/mochi_night.tres`，与现有地图一致。工作台为方便检查使用略强的中性月光，保留轻微紫色侧光和小面积灯笼暖光。怪松为已有资产，仅用于组合对照。

## 预览与检查

- [庭院组合实机图](../../../docs/art-concepts/2026-10-17-garden/godot-garden-model-study/01-garden-courtyard-1920.png)
- [栏杆模块](../../../docs/art-concepts/2026-10-17-garden/godot-garden-model-study/07-modules-5-1920.png)
- [围墙模块](../../../docs/art-concepts/2026-10-17-garden/godot-garden-model-study/08-modules-6-1920.png)
- [拼接检查](../../../docs/art-concepts/2026-10-17-garden/godot-garden-model-study/09-modules-7-1920.png)
- [完整交付记录](../../../docs/art-concepts/2026-10-17-garden/godot-garden-model-study/README.md)

运行 `res://tests/expedition_garden_lab_capture.tscn` 可重现独立模型截图，并检查共用柱、连接点、十六个独立场景的实例化和玩法状态隔离。生成后的实际地图见[园林组装截图](../../../docs/art-concepts/2026-10-17-garden/godot-generated-garden/README.md)。
