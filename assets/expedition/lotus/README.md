# 莲池格子模型

沿用已有冥府园林的灰褐石材、明确墨线与平涂分色；暗青水、灰绿荷叶、灰朱莲瓣和小面积骨色花心形成层次。风格转译依据为 [赤烛《九日》官方介绍](https://redcandlegames.com/presskit/sheet.php?p=nine+sols) 中的手绘环境与 Taopunk 方向，具体色值和斜俯视造型属于本项目设计。

完整莲池格子保留独立预览。实际远征已复用原有含苞、盛莲、残荷和大小叶片几何，优先布置在主要池塘；`plants_only` 模式只生成植物，避免重复叠加方形水面和岸沿。植物同步当前地图水位、迷雾与视野暗化，避开石路、桥面和建筑。只有合适水面才放置，不强行挤入窄水道。本组没有新增玩法效果，见[运行接入记录](../../../docs/地图生成规则与园林接入记录.md)和[围墙与荷花实机](../../../docs/art-concepts/2026-10-17-garden/godot-closed-lotus-garden/README.md)。

## 场景清单

| 文件 | 内容 |
|---|---|
| `lotus_leaves.tscn` | 随种子变化的大小混生叶片、叶脉和克制的局部涟漪 |
| `lotus_bud.tscn` | 含苞莲花、花梗与荷叶 |
| `lotus_bloom.tscn` | 双层盛莲；平滑受光的曲面花瓣、暗朱外瓣和骨色内瓣 |
| `lotus_withered.tscn` | 枯黄叶、折梗与残莲蓬 |
| `lotus_step.tscn` | 与地面同高的石踏面、暗刻字和周边小荷叶 |
| `pond_interior.tscn` | 无岸沿的内部水格 |
| `pond_edge.tscn` | 单侧直岸，供连续池岸拼接 |
| `pond_corner.tscn` | 两侧斜接岸帽组成外角 |
| `pond_inner_corner.tscn` | 对角陆地对应的圆弧石岛接角 |

## 无莲叶与格内水岸扩展

增加八个独立场景。保留上述莲池，新增水岸允许穿过格子内部，水面之外直接生成石地，不再限定为整块方池。

| 文件 | 内容 |
|---|---|
| `pond_clear.tscn` | 原莲池的无植物版本，四面石岸；沿用旧深水位 |
| `pond_open_water.tscn` | 无莲叶纯水，四边开放，供大水面内部使用 |
| `pond_corner_small.tscn` | 仅左上约 4% 的小片水面，剩余为石地 |
| `pond_corner_broad.tscn` | 较宽的左上偏角水面 |
| `pond_half.tscn` | 精确半格水面、直岸，可连续延长 |
| `pond_half_curve.tscn` | 接近半格的弧岸，水面略多于一半 |
| `pond_diagonal_half.tscn` | 对角切分的精确半格水面 |
| `pond_inlet.tscn` | 反向内湾，石地占据一角，水面包围石角 |

以上七种新形状使用 `src/map/expedition_pond_shape_tile.gd`。四角参数 `corner_values` 顺序为西北、东北、东南、西南，正数为水、负数为地；改变数值可以移动岸线交点，旋转根节点 90° 可调整朝向。`bend` 为单块预设的内部弯曲量，不改变共边交点。

制作尺寸仍为 2×2，场景缩放 0.5 后占 1×1。石岸与地面齐平，只有岸壁下沉。新形状默认 `water_depth=0.24`，实际水位 −0.12；特意比原莲池浅，避免极小水片被近侧岸壁遮住。与旧深水格混用时，需要将整组 `depth` 统一设为 0.64，不能直接混用两种水位。

### 连续不规则池塘

组合时共用一张**格子顶点场**，不用逐块猜岸线。相邻格取同一组边界值，经双三次插值保持岸线位置和切向连续，再把水面、岸帽、石地裁成互补网格。水纹沿用世界坐标。岸壁只沿实际水陆交界生成，格子之间没有隐藏围边。

```gdscript
const PondShape = preload("res://src/map/expedition_pond_shape_tile.gd")
var holder := Node3D.new()
holder.scale = Vector3.ONE * .5
add_child(holder)

# 默认未填写的顶点为 -1（陆地）。一个正顶点会在四格共角处
# 形成小池，各格分别只占一小角，并非四个独立方池。
var vertices := {Vector2i.ZERO: .65}
var colors = preload("res://assets/expedition/lotus/lotus_night.tres")
var pond := PondShape.assemble(
    holder, shared_style, vertices, Rect2i(-1,-1,2,2), colors, .24
)
```

`Rect2i` 表示生成哪些格子；场的键表示格子**顶点**，不是水格中心。闭合池塘应在外围保留负值顶点，或依赖默认陆地值收口。`cutaway_edges` 只是独立样板外露的剖面，组合时自动移除内部剖面，不参与水岸判定。

新预览入口：`res://src/tools/expedition_pond_shape_lab.tscn`。提供六种模块、3×3 不规则池、四格小池、半格连续岸线、园林组合与单格近看；可以开格子边界、转看、缩放和改水色。

- [六种格内水面](../../../docs/art-concepts/2026-10-17-garden/godot-water-shape-study/03-water-mode-1-1920.png)
- [3×3 拼接边界](../../../docs/art-concepts/2026-10-17-garden/godot-water-shape-study/02-irregular-grid-1920.png)
- [实机记录与检查](../../../docs/art-concepts/2026-10-17-garden/godot-water-shape-study/README.md)

## 尺寸和拼接

- 制作坐标一格为 **2×2**，所有预制场景根节点默认缩放 **0.5**，实际占 **1×1 格**。
- 原点位于格心，连接标记位于四条边的中点。本地 +X 为东、+Z 为南。
- 石岸顶部为 y=0，水面为制作高度 −0.64，即地图尺度 −0.32；与现有墨水地形的水位一致。踏石顶面保持 y=0。
- `water_neighbours` 按北、东、南、西的顺序使用位掩码 1、2、4、8；`diagonal_neighbours` 为东北、东南、西南、西北。
- 相邻水格之间不生成岸沿。两条岸帽用斜接顶面共边，中央不重复覆盖；只与对角陆地接触时，生成圆弧石角，连接相邻岸段。
- 水纹按世界坐标与共同时间生成，跨格连续。叶片布局使用独立种子，组合时根据格子坐标派生各格种子，不消耗玩法随机数。
- 刻字踏石默认使用“回”作为材质展示，可以修改 `glyph_text`；没有添加新词条或字效果。

### 生成连续莲池

```gdscript
const Lotus = preload("res://src/map/expedition_lotus_tile.gd")
var holder := Node3D.new()
holder.scale = Vector3.ONE * .5
add_child(holder)

var cells := {
    Vector2i(0,0): Lotus.Plant.LEAVES,
    Vector2i(1,0): Lotus.Plant.BLOOM,
    Vector2i(0,1): Lotus.Plant.BUD,
    Vector2i(1,1): Lotus.Plant.STEP,
}
var colors = preload("res://assets/expedition/lotus/lotus_night.tres")
var pond := Lotus.assemble(holder, shared_style, cells, colors)
```

`assemble` 根据八邻接决定各格岸线，仅生成表现节点。可传入第五个参数 `seed_value` 改变整池叶片布局。石材共用 `mochi_night.tres`；花叶、水色等由 `lotus_night.tres` 提供，支持实时改色。

## 零散小莲叶

新增三种独立格子：

| 文件 | 内容 |
|---|---|
| `lotus_scattered_leaves.tscn` | 2–5 枚大小不同的小叶，随机散开并保留空水面 |
| `lotus_small_cluster.tscn` | 5–8 枚更小的叶片，偏向局部成丛，也保留少量散叶 |
| `lotus_tiny_leaves.tscn` | 5–9 枚细小叶片，制作半径 0.05–0.12 |

原有荷叶、含苞、盛莲、残荷和踏石格也改成生成布局：叶片数量、半径、位置、朝向、椭圆比例与轻微色差各有变化，含苞／盛莲保留一枚中叶搭配小叶。踏石和花梗附近留空。小叶减少叶脉数量、减轻轮廓粗细，避免缩小后变成一团黑线。

`layout_seed` 控制可复现布局；`small_leaf_count` 是随机数量范围，`small_leaf_radius` 是制作半径范围。根节点缩放 0.5 后，小叶半径也对应缩小一半。生成器有空间限制时可以少放几片，不会强行重叠或压进石地。

纯叶片层位于 `src/map/expedition_lotus_leaf_layer.gd`，不附带水面或岸墙，可以叠在新不规则池塘上。通过 `water_test` 同时检查叶心与外缘，跨格布置时沿整池采样，不会在每格重复一组叶片。单片水格叠加示例：

```gdscript
const LeafLayer = preload("res://src/map/expedition_lotus_leaf_layer.gd")
var leaves := LeafLayer.new()
leaves.layout_seed = 137
leaves.small_leaf_count = 5
leaves.water_height = -pond_tile.water_depth
leaves.water_test = pond_tile.contains_water
pond_tile.add_child(leaves)
leaves.setup(shared_style)
```

运行中花丛同样使用 `water_test` 约束伴生叶片，并用 `water_height` 对齐真实水位。`plants_only=true` 可单独复用花、梗、莲蓬和叶片；不创建水面、岸沿或原整格涟漪。花丛之间保留间距，外围散叶避开花丛，布局使用独立装饰种子。

运行莲池预览 `res://src/tools/expedition_lotus_lab.tscn`，下拉末尾有“零散小莲叶”“小叶变化”“小莲叶·不规则池岸”三项。可修改布局种子或点击“换一组”，同一种子会恢复相同布局。工作台独立于玩法；实际地图已复用纯叶片层生成零散小叶。

- [不规则池塘里的小叶](../../../docs/art-concepts/2026-10-17-garden/godot-lotus-scatter-study/03-irregular-small-leaves-1920.png)
- [疏散／小丛／混生对照](../../../docs/art-concepts/2026-10-17-garden/godot-lotus-scatter-study/02-loose-cluster-mixed-1920.png)
- [本轮截图与检查](../../../docs/art-concepts/2026-10-17-garden/godot-lotus-scatter-study/README.md)

## 查看

运行 `res://src/tools/expedition_lotus_lab.tscn`。有连续 3×3、五种变化、单格近看、岸线检查和园林组合等视图；左键转看，中键拖看，滚轮缩放，可以打开格子边界和暖光对照。石材、荷叶、莲瓣和水色均有调色入口。

预制场景在运行时创建实际网格，可直接实例化；也可在创建后立即调用 `setup(shared_style)`，共用现有场景的材质与墨线。

- [3×3 实机样板](../../../docs/art-concepts/2026-10-17-garden/godot-lotus-tile-study/01-lotus-3x3-1920.png)
- [五种格子](../../../docs/art-concepts/2026-10-17-garden/godot-lotus-tile-study/02-lotus-mode-1-1920.png)
- [岸线拼接检查](../../../docs/art-concepts/2026-10-17-garden/godot-lotus-tile-study/07-lotus-mode-6-1920.png)
- [完整记录](../../../docs/art-concepts/2026-10-17-garden/godot-lotus-tile-study/README.md)
