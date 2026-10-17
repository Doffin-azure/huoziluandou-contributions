# 庭院 3D 美术样板

此场景按用户提供的建筑参考构建，现在采用与已定稿战斗画面相衔接的墨青、朱红、旧金色系，用来审阅真实 3D 空间的风格化渲染。这套庭院已接入正式标题界面。独立审阅工具仍可运行；正式入口与工具共用 `src/title/courtyard_view.gd` 和 `src/title/courtyard/` 中的运行资源，避免维护两套背景。

## 独立工具

在 Godot 4.7.2 中打开 `res://src/tools/title_art_sample.tscn`，按 F6 运行当前场景。不要修改项目的主场景配置。

- 点击「开始新冒险」或按空格：镜头从廊下进入庭院。
- 点击「返回」或再次按空格：回到标题构图。
- 点击「设置」或按 F2：调整日光、亭内补光、水面反射、建筑墨线、薄雾浓度和环境动态。
- ESC：关闭光照面板或返回标题构图。
- 「字库图鉴」使用现有图鉴。样板的开始按钮只预览镜头，不开新局，不读写存档。

## 本轮构成

- 前景门廊和窗扇、中景水院与木桥、左右廊亭、后景藏字阁、树木及远景山体。
- 独立桶瓦、屋脊、弯曲檐口、椽头、柱础、三层斗拱、木格窗、菱形窗花、回纹栏杆、灯笼骨架与流苏等实际几何细节。
- 建模材质保留项目内 1K 颜色、法线、粗糙度贴图，供原始模型导出。运行时由独立 `render_style.gd` 换成三色颜料材质，仅取原贴图的低对比灰度纹理，不使用照片色相、法线凹凸及镜面高光。
- 每类材质独立定义阴影／中间色／受光色；真实灯光和投影决定色阶。构件选择性使用外扩描边，主相机再进行轻量深度／法线轮廓处理；花冠不参与内部轮廓，避免碎线和点状投影。
- 天空改成青绿渐层与米金月轮；远山用青色分层，材质统一处理远近色。取消写实 HDRI、SSR 和反射探针，保留独立日光、亭内补光、灯笼灯光和适量环境遮蔽。当前加入两块低密度局部体积雾，分别位于水面与后景；全局雾密度为 0，天空不受雾影响。没有实例化、调用或修改 StudyStage。
- 水面倒影由共享 3D 世界中的镜像相机实时渲染；反射相机排除水面和地基，防止递归及地基背面遮挡。反射视口为主视口的一半分辨率，关闭反射会停止额外的渲染通道。

## 源文件分工

- `architecture.gd`：建筑比例、构件和庭院布局。
- `mesh_workshop.gd`：构件、屋面与瓦片建模；按材质合并网格，避免一件构件一次绘制。非均匀缩放在局部轴施加。
- `landscape.gd`：有主次分枝的树木、花朵、灯笼、远景。
- `material_library.gd`：原始建模材质及打包在项目中的贴图引用。
- `render_style.gd`：按材质与构件分配有限色板；只影响独立运行样板，不覆盖建模材质。
- `pigment.gdshader`：三色光照、低对比灰度纹理与远近色。
- `ink_outline.gdshader` / `contour.gdshader`：选择性外轮廓和主相机的屏幕墨线。
- `painted_sky.gdshader`：青绿天空与纸色月轮。
- `courtyard_stage.gd` / `.tscn`：独立光照、相机、反射与镜头过渡。
- `water.gdshader`：水面反射与微小水纹。
- `atmosphere.gd`：局部体积雾、112 片固定实例花瓣、共享动画时钟与暂停控制。花瓣循环不创建新节点。
- `breeze.gdshaderinc`：树冠与枝干轻摆、灯笼整组绕悬挂点摆动；主体和墨线使用同一变形。
- `low_mist.gdshader` / `falling_petal.gdshader`：缓慢流动的局部雾与有正反面色差的花瓣。
- `make_motion_preview.py`：把 Godot 原生帧组装成共享色板 GIF。
- `fetch_materials.py`：可重复的素材获取脚本，校验 Poly Haven 官方 MD5 并记录来源。
- `bake_geometry.gd`：生成可单独打开的 Godot 二进制场景与 GLB 模型。

本轮模型由 Godot 的参数化建模代码构建，Blender 未参与本轮制作。导出的 `.glb` 可在 Blender 中继续编辑；Godot 的风格化着色、世界空间材质、牌匾文字、光照和实时水面属于运行场景，导入 Blender 后需要另行设置。

静态风格版截图在 `docs/art-concepts/2026-10-16/courtyard-3d/stylized/`；当前薄雾与动态版在 `docs/art-concepts/2026-10-16/courtyard-3d/ambient/`，包含原生截图、6 秒 GIF 预览与验证记录。旧版写实截图保留在上一级供对照。导出的 GLB／SCN 是原始建模材质版本；花冠尺度默认值也保留原样，风格化场景单独加大以连成色块。

模型放在 `docs/art-concepts/2026-10-16/courtyard-3d/models/`，不会作为正式游戏的运行资源自动导入。参考截图和模型均在项目文件夹内。旧机关样板已移至忽略的 `shots/rejected-glyph-foundry/`，不参与运行。

## 验证与重建

原生渲染验证场景：`res://tests/title_art_sample_test.tscn`。它检查独立世界、梁件尺寸方向、实际模型、相机往返、光照滑块、反射开关、雾开关对图像的影响、花瓣在屏幕处理后的可见性、固定实例数量与运动暂停／恢复，保存原生截图到 `shots/title-art-*.png`。

重新烘焙模型：

```powershell
& 'C:\Users\Lenovo\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path E:\gamejam10\huoziluandou --script res://src/art_samples/courtyard/bake_geometry.gd
```

材质来源和许可：`assets/title/courtyard/materials/sources.json`。全部为 Poly Haven 的 CC0 素材：https://polyhaven.com/license 。没有使用图像生成或把生成图作为 3D 背景。

## 当前精度

这是建筑和光照样板。建筑构件已细化；植物、山体仍是程序构建的占位资产，尚未达到用户参考图的完整美术品质。没有进行移动端性能验收，也没有把功能测试通过当作美术验收通过。正式接入范围及回归记录见 `src/title/README.md`。

风格化渲染依据 Godot 官方 [Spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) 与 [Advanced post-processing](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html) 的自定义光照、反向深度和屏幕处理机制实现。轮廓通道只在主相机渲染层 8 中绘制，镜像相机仅绘制层 1。牌匾采用 alpha discard，避免被屏幕采样覆盖。


## 环境动态预览

体积雾使用 Godot Forward+ 原生 FogVolume 与 fog shader；参见 [官方体积雾说明](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)。Mobile／Compatibility 渲染器不支持这套体积雾，本轮只验证桌面 Forward+。没有更改全局项目渲染设置。

花瓣是双面弯曲小网格，通过一个 MultiMesh 绘制，分布在庭院开放区域。有翻转、横向漂移、出生和落地前的缩小，场景深度负责建筑遮挡。它是环境装饰，没有做物理碰撞或落地堆积。树木与灯笼保留原始几何，通过局部顶点变形运动；灯笼、骨架、流苏和墨线共享同一悬挂点。水纹与雾流动也使用同一时钟，关闭「环境动态」可暂停后继续。

`tests/courtyard_ambient_capture.tscn` 在固定相机下保存 60 张原生帧到 `shots/courtyard-ambient-frames/`。以 `--fixed-fps 30 --resolution 1280x720` 原生运行；每 3 帧取样一次，记录 6 秒、10 fps。用 `make_motion_preview.py <帧目录> <输出.gif>` 生成 960×540 预览，统一色板且不做抖色。GIF 带格式量化，不替代原生 PNG 评审。动效在 Godot 中按实际帧率持续计算。
