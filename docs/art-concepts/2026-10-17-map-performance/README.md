# 地图长条亮区与拖镜卡顿 · 定位和修正

2026-10-17，Godot 4.7.2 Forward+，本机 RTX 4060 Laptop，1280×720。用户反馈迷雾出现横竖亮带以及操作时卡顿；本轮分别定位渲染错误和 CPU 峰值，没有降低模型、描边宽度、灯光或抗锯齿质量。

## 亮带来源

原实现对超出地图的坐标使用 `clamp` 读取 12×8 探索纹理，导致最后一行／列的已探索状态沿更大的地面、水面和遮蔽平面延伸，形成长条亮区。关闭方向光的雾散射、全部雾光照乃至整个体积雾后，越界亮区仍存在，说明它不是实际额外光源。

`expedition_vision.gdshaderinc` 统一处理运行地图的取样：真实地图外返回未探索状态。地面、水面、岸壁、遮蔽平面与体积雾采用同一规则；体积雾用于保护可见地面的视线投影也受边界限制。`clip_vision_bounds` 只在实际地图开启，独立美术预览仍允许负坐标和全白遮罩。

- [修正前，关闭体积雾后仍有越界亮区](before-edge/04-no-volume.png)
- [修正后，保留原有体积雾和灯光](after-edge/05-overview-physical-fog.png)

## 卡顿来源与实测

原来拖动／跟随镜头时每 0.1 秒同步遍历整图模型边缘，包括已被迷雾隐藏的模型。一次更新约 100 毫秒，足以让下一帧明显延迟；同期 GPU 绘制约 1–2.5 毫秒。

本轮跳过隐藏及镜头外模型，预先剔除永远不会成为轮廓的共面内部边，将逐边世界坐标变换改为每物件一次相机变换，并以每帧约 2 毫秒的时间预算逐步完成扫描。若扫描期间视野或镜头改变，后续再扫描一次，避免新揭示物件漏掉轮廓。未改变画面时也不再每帧重算遮挡和重画界面标记。

| 同种子、同分辨率，持续拖镜 | 原实现 | 修正后 |
|---|---:|---:|
| 普通视野，帧耗时中位数 | 107.28 ms | 2.22 ms |
| 普通视野，帧耗时 P95 | 111.11 ms | 5.05 ms |
| 边缘视野，帧耗时中位数 | 108.12 ms | 3.64 ms |
| 边缘视野，帧耗时 P95 | 116.34 ms | 6.04 ms |

每组包含 120 帧，关闭垂直同步，先预热；数值只描述这台机器与当次场景，不能直接代表用户运行帧率。它们包含脚本与帧间等待，另外记录独立视口 CPU/GPU 渲染耗时；测量接口依据 [Godot RenderingServer 文档](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu)。

首次地形烘焙、着色器编译和首次网格轮廓缓存构建仍可能短暂停顿。同步诊断主动调用一次完整扫描时，冷缓存峰值仍高于热态，本轮没有将资源构建改成异步加载。运行中的时间预算也不是单个网格计算的硬中断；本轮主要修复持续镜头运动造成的反复百毫秒峰值。

## 重现与验证

```text
<godot> --path . --scene res://tests/expedition_map_profile.tscn -- --after
<godot> --path . --scene res://tests/expedition_map_profile.tscn -- --after --edge-vision
<godot> --path . --scene res://tests/expedition_render_regression.tscn
<godot> --path . --scene res://tests/expedition_map_view_test.tscn
```

原始日志见 `before.log`、`before-edge.log`、`after.log`、`after-edge.log`。专项验证 13 项：缩放旋转后的精确透视／正交轮廓、隐藏与视锥排除、分帧完成、重新揭示物件、四边越界 GPU 像素检测及独立负坐标预览兼容。地图交互回归 66 项通过，覆盖两种分辨率、拾取、移动、镜头、四主题、机关、迷雾与信标。正常地图仍沿用真实视野、探索记忆与信标规则。
