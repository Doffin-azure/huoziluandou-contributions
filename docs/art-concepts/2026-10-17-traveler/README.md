# 持灯行者 · 原生低模预览

本页全部为 Godot Forward+ 实际渲染，模型由几何切面组成，使用明确轮廓、少量分色与园林共用的分段光照。独立样模尚未替换当前游戏行者。

| 图片 | 检查内容 |
|---|---|
| [三面](01-three-views-1920.png) | 同一模型的正面、侧面、背面，1920×1080 |
| [转角近看](02-model-volume-1920.png) | 空心兜帽、折面面具、披肩、袍摆和提灯的厚度 |
| [园林同屏](03-garden-scale-1920.png) | 与月洞门、照壁、栏杆、墓碑及石地同场景，1920×1080 |
| [小分辨率](04-garden-scale-1280.png) | 相同园林比例，1280×720 |
| [夜间提灯](05-real-lantern-light-1280.png) | 降低主光后的实际灯照 |
| [关闭提灯光](06-lantern-light-off-1280.png) | 同镜头检查点光实际影响 |
| [工作台](07-workbench-1280.png) | 转看、缩放、换色与待机入口 |

模型 1,934 三角面，不计描边。独立场景和可改色资源位于 `assets/expedition/characters/`；使用方式、比例和后续动画接入事项见 [资产说明](../../../assets/expedition/characters/README.md)。

运行 `res://src/tools/expedition_traveler_lab.tscn` 打开工作台。捕获与实例化验证由 `tests/expedition_traveler_capture.tscn` 完成。
