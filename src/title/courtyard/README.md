# 庭院运行资源

已用于正式标题，职责、操作与测试说明见 [上一级 README](../README.md)。

- `architecture.gd` / `mesh_workshop.gd`：建筑与构件建模、按材质合并网格。
- `landscape.gd`：树木、灯笼和远景；只使用私有固定种子，不消耗游戏随机数。
- `material_library.gd`：建模材质引用；`render_style.gd`：运行时按构件分配墨青、朱红、米金三色色阶。
- `pigment.gdshader` / `ink_outline.gdshader` / `contour.gdshader`：三色光照、选择性外轮廓和主相机深度／法线轻描边。
- `courtyard_stage.tscn` / `.gd`：独立世界中的灯光、相机、实时倒影和渲染通道。
- `atmosphere.gd` / `low_mist.gdshader` / `falling_petal.gdshader` / `breeze.gdshaderinc`：局部体积雾、112 片固定实例落花、共享时钟和风摆。
- `water.gdshader` / `painted_sky.gdshader` / `menu_scrim.gdshader`：水面、天空与菜单前景遮罩。

模型和植物仍是程序构建的资产，保留后续美术打磨空间。所有材质打包在 `assets/title/courtyard/materials/`；来源见该目录 `sources.json`，使用 Poly Haven CC0 素材。预览工具与正式标题共用这些文件。
