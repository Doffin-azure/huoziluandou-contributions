# 莲池格子 · 独立模型样板

完成五种格子内容（荷叶、含苞、盛莲、残荷、刻字踏石）和四种岸线场景，共九个独立 Godot 场景。每片水面占一格，八邻接决定岸边、转角和石岛接角，支持拼成连续的莲池。

沿用上一组园林模型的灰石、压暗配色、平涂分色与明确墨线；莲瓣用灰朱与骨色，花叶保留少量结构线和曲面厚度。花瓣采用连续法线，避免近看时出现明显三角分面。岸石不投射多余的自阴影，水纹保持低对比，踏石沿用石材凹刻字。

本轮尚未接入玩法地图，没有新增莲池通行、奖励或单字效果。下列园林组合仅用于检验风格一致性。

## Godot 实机截图

- [连续 3×3，1920×1080](01-lotus-3x3-1920.png)
- [五种格子变化](02-lotus-mode-1-1920.png)
- [盛莲近看](03-lotus-mode-2-1920.png) / [侧向看曲面](13-lotus-flower-side-1920.png)
- [荷叶](04-lotus-mode-3-1920.png)
- [残荷](05-lotus-mode-4-1920.png)
- [刻字踏石](06-lotus-mode-5-1920.png)
- [内外角、单格水道、孤立水格](07-lotus-mode-6-1920.png)
- [与已有园林模型同屏](08-lotus-mode-7-1920.png)
- [格子边界对照](09-lotus-grid-1920.png)
- [3×3，1280×720](10-lotus-3x3-1280.png) / [暖光对照](11-lotus-warm-light-1280.png)
- [独立交互预览](12-lotus-workbench-1280.png)

全部截图由 Godot Forward+ 原生渲染。

## 资源

[资产清单与拼接说明](../../../../assets/expedition/lotus/README.md)

- 模型：`src/map/expedition_lotus_tile.gd`
- 花叶、水色调色板：`assets/expedition/lotus/lotus_night.tres`
- 预览：`src/tools/expedition_lotus_lab.tscn`
- 原生捕获与检查：`tests/expedition_lotus_lab_capture.tscn`

风格参考：[赤烛《九日》官方介绍](https://redcandlegames.com/presskit/sheet.php?p=nine+sols) 中的手绘环境与 Taopunk 设计方向；本样板的斜俯视、具体植物色值与格子化均为本项目的转译。

## 验证

31 项通过，0 失败。覆盖水面实际占一格、全池同高、九格池只有十二条外岸、中心不生成岸沿、石岛圆弧接角、孤池斜接岸帽面积无重叠、单格水道、踏石暗刻字、两种分辨率预览、实时改色、九个场景独立实例化，以及游戏状态和随机数隔离。
