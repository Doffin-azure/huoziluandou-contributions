# 庭院薄雾与环境动态

在上一轮墨青／朱红风格化庭院上，加入局部体积雾和持续的环境动画。模型、运行场景、着色器及预览都在本项目内，没有图像生成或事后绘制。

- [preview.gif](preview.gif)：6 秒原生运行预览，960×540、10 fps；Godot 动效持续按实际帧率计算，GIF 仅用于快速查看。
- [01-title.png](01-title.png)：带菜单的原尺寸截图，1920×1080。
- [02-courtyard.png](02-courtyard.png)：无 UI 的 3D 视口，2880×1620。
- [03-detail.png](03-detail.png)：进入庭院后的原尺寸近景，1920×1080。
- [04-frozen-mist.png](04-frozen-mist.png)／[05-frozen-no-mist.png](05-frozen-no-mist.png)：同一冻结时间下的雾开／关对照。

## 动态处理

水面和后景各放置一块原生 FogVolume，全局雾密度为 0，天空不受雾影响。fog shader 用缓慢的大尺度变化控制雾流动，不添加颗粒噪声。低密度薄雾保留分阶明暗与建筑细节，菜单仍处于清楚的前景。

112 片弯曲花瓣用一个 MultiMesh 绘制，带缓慢下落、横向漂移、正反面色差与翻转。它们在真实 3D 深度中受到建筑遮挡；轨迹在庭院开放区域循环，循环不创建新节点。出生及落地前缩小，减少重置跳变。没有做物理碰撞或落花堆积。

树冠与枝干做小幅度风摆。灯笼的纸面、骨架、帽沿、流苏和墨线都绕各自悬挂点一起摆动。风、落花、雾和水纹使用同一场景时钟，设置中暂停后可继续，不影响菜单和镜头操作。

入口：`res://src/tools/title_art_sample.tscn`，F6 运行。空格进入／返回，F2 打开调节面板；「薄雾浓度」为 0 时关闭体积雾渲染，「环境动态」可暂停／恢复。

## 验证

`tests/title_art_sample_test.tscn` 原生执行 33 项通过、0 项失败，标准错误输出为空。新增验证覆盖雾开关对渲染图像的影响、花瓣在墨线合成后的可见性、实例数与循环范围、运动暂停与恢复；原有镜头、灯光、反射、牌匾可读性检查继续通过。见 [native-render.log](native-render.log) 与 [verification.json](verification.json)。

`tests/courtyard_ambient_capture.tscn` 以 1280×720、固定 30 fps 运行，每 3 帧采样一次，取 60 张原生帧。使用 `src/art_samples/courtyard/make_motion_preview.py` 组装统一色板 GIF，未叠加绘制内容。GIF 有缩放及 256 色量化，原生 PNG 仍用于检查细节；它不是帧率测试，也没有声称无缝循环。

体积雾依赖 Godot Forward+，参见 [官方说明](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html) 与 [fog shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/fog_shader.html)。尚未做移动端替代方案和性能验收。仍为独立样板，未接入正式主界面，未改战斗界面、StudyStage、游戏逻辑或存档，未提交或推送。
