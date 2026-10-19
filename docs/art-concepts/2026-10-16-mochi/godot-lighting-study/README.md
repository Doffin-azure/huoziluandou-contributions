# 问字龛 · 天空与多光源小样

2026-10-16。在已认可的问字龛与怪松造型上调整配色和照明，先验证单体同屏效果。

后续新增三座建筑后，用户指出整体和屋面偏浅。当前工具场景已采用[墨青屋面修正版](../godot-dark-palette-study/README.md)，增加屋面独立受光参数并降低整体灯光；本页保留最初多光源版本的截图记录。

## 实机对照

- [新版近景，1280×720](01-lighting-close-1280.png)
- [新版与怪松同屏，1280×720](02-lighting-pine-1280.png)
- [关闭龛内暖灯](03-lantern-off-1280.png)
- [关闭冷色边光](04-rim-off-1280.png)
- [关闭天空背景与天空环境光](05-sky-off-1280.png)
- [切回上一版配色与固定染光，同一镜头](06-previous-colors-1280.png)
- [新版与怪松同屏，1920×1080](07-lighting-pine-1920.png)
- [新版侧面](08-lighting-side-1280.png)
- [新版背面](09-lighting-back-1280.png)

全部来自Godot原生运行截图，未对画面进行后期调色或补画。

## HDR与发灰的原因

此前已经使用Forward+的HDR内部渲染，但展示场景只有纯色背景；建筑、屋顶和树的平涂材质使用`unshaded`，只接收一处自定义暖色染光。直接增加普通Godot灯光不会改变这些表面。大面积灰色地台与建筑明度接近，也削弱了主体。

本轮保留几何与墨线，给展示场景增加实际Godot灯光受光路径。HDR光照经过Filmic色调映射后输出普通屏幕预览，灯芯的高亮值用于产生小范围辉光。这里没有配置HDR显示器输出。

天空为独立制作的2048×1024绘制全景纹理，含暗青渐层、稀疏云带和旧金月面，通过`PanoramaSkyMaterial`作为天空背景及低强度环境光来源。它是LDR绘制贴图，**不是摄影HDRI**；背景和物件照明在HDR渲染管线中组合。斜俯视镜头主要看见全景的下半部渐层，月面位于上半部，不强行出现在地面背后。

## 配色与照明

新增`mochi_lantern.tres`，保留原`mochi_dusk.tres`供对照。深青地台退后，建筑灰青受光面、少量铜金与暖灯承担视觉重点。墨线不接受照明，避免随曝光和补光一起发灰。

| 光源 | 作用 | 投影 |
|---|---|---|
| 偏纸白的斜上主光 | 建立屋面、柱体、台阶明暗 | 实时 |
| 冷青后侧光 | 让背侧和暗青部件离开背景 | 实时 |
| 低强度前补光 | 保留龛口和柱面可读性 | 关闭，控制重影 |
| 龛内暖色点光 | 照亮碑面、供台与近处台阶 | 实时 |

表面使用自定义`light()`累加这些原生灯光，保留少量宽明暗带，关闭镜面高光。屋面继续依据四坡结构确定大片法线区域，避免三角网格形成碎斑；阴影仍来自真实屋顶几何。实际投影启用时隐藏旧固定绘制阴影，防止重叠。

树干与针叶立片现在也能接收这些灯光，但仍是面向相机的绘制立片；针叶层没有因此变成完整3D树冠，也未增加树冠实体投影。根石维持真实立体网格。

辉光只从超过阈值的高亮区域提取，强度较低。没有加入全屏灰雾、自动曝光或写实材质反射。

## 打开与调整

打开`res://src/tools/expedition_shrine_lab.tscn`按F6：

- 左键拖动转看，滚轮缩放；保留建筑近看、与怪松同屏和三视角按钮。
- **新版配色／实际受光**：与上一版的配色和固定染光比较，同时切换对应的地面投影方式。
- **天空与环境光**：同时切换天空背景和来自天空的环境光。
- **冷色轮廓光**、**龛内暖光**、**灯火微辉光**：分别开关，观察实际影响。
- **曝光**：调整HDR色调映射之前的亮度；灰石、屋面、墨线与线宽继续可调。

灯光状态和颜色修改只保存在该样板的运行实例中。其他样板默认沿用旧平涂路径；正式远征地图、玩法规则与随机数没有改动。

## 源文件与验证

- `assets/expedition/sky/mochi_twilight.svg`：可编辑天空全景。
- `assets/expedition/palettes/mochi_lantern.tres`：新配色。
- `src/shaders/expedition_lit_faces.gdshader`、`expedition_lit_roof.gdshader`、`expedition_stylized_light.gdshaderinc`：原生灯光受光与分带漫反射。
- `src/map/expedition_flat_style.gd`：按样板启用受光路径，保留原材质路径。
- `src/tools/expedition_shrine_lab.gd/.tscn`：天空、灯光、对照控件。
- `tests/expedition_lighting_lab_capture.gd/.tscn`：截图与集成检查。

Godot 4.7.2 Forward+／Vulkan、RTX4060 Laptop GPU。新版与旧版切换、真实暖灯和边光造成的视口像素变化、阴影切换不叠加、模型不重建、玩法随机数不改变检查通过。1280×720、1920×1080和侧背面实际画面已检查，运行错误日志为空。旧火光样板回归20项通过。

参考官方说明：[Spatial shader的light处理](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)、[Environment和色调映射](https://docs.godotengine.org/en/stable/classes/class_environment.html)。这些是本项目实现依据，不是对《九日》渲染管线的推断。
