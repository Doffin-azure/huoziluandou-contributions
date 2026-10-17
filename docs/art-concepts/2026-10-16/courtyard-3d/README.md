# 庭院建筑与风格化渲染

庭院已接入正式标题，F5 正常启动即可看到。接入记录见 [integration/README.md](integration/README.md)；源代码组织见 `src/title/README.md`。以下为各轮审阅记录，保留当时的范围说明。

当前运行版本见 [ambient/README.md](ambient/README.md)，增加局部体积雾、落花、树冠和灯笼动态，附原生运行 GIF。上一轮静态风格版见 [stylized/README.md](stylized/README.md)：墨青建筑、朱红树冠、旧金收边，三色光照与墨线。下面的 01／02／03 图片和模型记录上一轮写实基线，保留供对照。

用户参考见 `references/`。本轮放弃原来的单体机关造型，按前景门廊／中景水院／后景藏字阁建立完整建筑场景。图片均为 Godot 4.7.2 的原生渲染截图，没有图像生成、后期增强或绘制修补。

- `01-title.png`：带标题菜单的整体构图，1920×1080。
- `02-courtyard.png`：无 UI 的 3D 场景原始输出，2880×1620。
- `03-detail.png`：镜头进入庭院后的近景，1920×1080。
- `models/courtyard_geometry.glb`：包含贴图的 glTF 2.0 模型，可在 Blender 中打开。
- `models/courtyard_geometry.scn`：可独立打开的 Godot 原生模型场景。

模型使用 Godot 参数化建模代码构建，Blender 没有参与本轮制作。GLB 中的图像全部内嵌，无需额外的 PNG。Godot 中的世界空间材质、牌匾标签、动态镜头、灯光、雾及实时水面不属于 GLB 的完整可移植效果，换软件后需重新设置。

入口：`res://src/tools/title_art_sample.tscn`，在 Godot 中打开后按 F6 运行。空格进入／返回，F2 调节光照。这个场景未接入正式主界面，没有改动 StudyStage、游戏逻辑或存档。

源码与素材说明：`src/title/courtyard/README.md`。材质来源：`assets/title/courtyard/materials/sources.json`，使用 Poly Haven CC0 木材、石材、灰泥、屋面和天光资源。

## 验证记录

原生测试 `tests/title_art_sample_test.tscn` 检查独立世界、梁件方向尺寸、实际几何、打包材质、镜头往返、光照与反射开关。模型具有 2053 个建筑构件建模操作；建筑、景观合计约 28.2 万三角形，已按材质合并。数量仅记录实现成本，不作为美术质量验收。

上一轮写实基线退出原生截图测试时有 `7 RIDs of type Texture were leaked` 警告，未出现运行脚本错误；简单 SubViewport 对照及现有意图界面回归没有这个警告。原因尚未定位，不把它归因于引擎或声称已经解决。当前风格化配置取消写实环境通道后，原生验证标准错误输出为空，未再观察到该警告；尚未定位旧配置的具体原因。

这是建筑颗粒度与光照的评审样板，植物、山体尚是程序构建资产；整体完成度尚未达到用户参考图的成熟美术品质。没有完成手机性能验收。改动在 `feat/title-3d-sample`，本轮未提交或推送。
