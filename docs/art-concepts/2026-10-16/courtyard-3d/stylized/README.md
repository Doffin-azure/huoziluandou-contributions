# 庭院风格化渲染

本轮按已定稿战斗画面的墨青、朱红、米金／旧金色系调整原庭院 3D 样板。以下均为 Godot 4.7.2 Forward+ 的原尺寸截图，没有使用图像生成、后期调色或绘制修补。

- [01-title.png](01-title.png)：标题构图，1920×1080。
- [02-courtyard.png](02-courtyard.png)：无 UI 的 3D 视口原始输出，2880×1620。
- [03-detail.png](03-detail.png)：镜头进入庭院，1920×1080。

原始写实截图保留在上一级，便于对照。全部资源都在本项目中。

## 调整

| 对象 | 色彩和处理 |
| --- | --- |
| 建筑 | 深墨蓝阴影、青绿漆面、灰青石材；柱、斗拱、瓦片和窗格保留真实几何 |
| 木面与收边 | 木面用低饱和暖灰褐，少量旧金用于檐口和雕饰，减少整片发黄 |
| 树冠、灯笼 | 朱红主体与暗红背面；花冠加大连成色块，关闭碎花投影和内部墨线 |
| 天空、远山 | 青绿渐层、米金月轮与青色远近分层 |
| 材质 | 为每类表面分别定义阴影、中间色、受光色；原贴图仅取低对比灰度磨损 |
| 线条 | 主要构件选择性外扩描边，主相机使用深度／法线边缘补充轻线条 |
| 水面 | 保留镜像相机的实际倒影，降低反射对比，加入缓慢的横向水纹；取消 SSR |

使用 Godot 的 [自定义光照](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) 与 [反向深度屏幕处理](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html)。这套材质在独立场景运行时分配，原建模材质未覆盖；上一级 GLB 导出保留原始建模材质，不会在 Blender 中自动复现本轮 Godot 渲染效果。

## 运行与验证

打开 `res://src/tools/title_art_sample.tscn`，F6 运行。空格进入／返回庭院，F2 调整真实日光、亭内补光、水面反射与建筑墨线。样板的开始按钮只预览镜头，不开新局、不写存档。

原生验证：`res://tests/title_art_sample_test.tscn`，23 项通过，0 项失败，标准错误输出为空。验证包括模型方向和细节、材质打包、镜头往返、灯光对实际像素的影响、反射开关停止额外渲染、轮廓与反射视口隔离、牌匾文字在屏幕处理后的像素可见性。日志见 [native-render.log](native-render.log)，尺寸和范围见 [verification.json](verification.json)。

旧写实配置的 7 个 Texture RID 退出警告在本配置中未再观察到；旧配置的具体原因没有定位。

这仍是风格与渲染样板。树木和山体的造型仍需美术打磨；没有完成移动端性能验证，也不把功能测试通过当作美术终稿验收。正式主界面、战斗 UI、StudyStage、游戏逻辑及存档未改动。工作保留在 `feat/title-3d-sample`，未提交或推送。
