# 全部遗物贴图 · 2026-10-19

目前 `Relics.DEFS` 中的 15 件遗物均已提供独立 1024×1024 RGBA 透明 PNG，总文件大小约 5.42 MiB。全部遗物去掉公共展示底盘，细化实体模型后重新正交渲染。商店模型与贴图使用同一份源文件。

本轮新增倒角、刃口、缠柄、刻字、铆钉、活字版块、香炉内壁与器足、布料褶皱与针脚、转轮轮齿与手摇柄、电瓶接线、弯曲的立体火焰、叶片与叶脉，以及屏风山水和竹枝。遗物专用材质区分金属氧化、木纹、织物纹理和石材颗粒。

应用位置：经典模式的遗物奖励与购买确认，战斗菜单的遗物说明，远征整备的遗物详情，以及远征商店的遗物按钮。商店柜台保留可交互的 3D 实体。

## 画面核对

- `all-relics.png`、`all-relics-refined.png`：全部 15 件去底盘后的新版造型、名称、稀有度。
- `shop-refined-1280.png`：实际商店柜台上的新版遗物实体。
- `purchase-1280.png`：购买确认中的图案与对应库存一致。
- `reward-1280.png`、`reward-640.png`：三选一的图案及说明，三项同时可见。
- `battle-collection-1280.png`、`loadout-1280.png`：完整持有集合及原有效果说明。

## 验证

Godot 4.7.2，贴图导入成功。本轮相关检查共 **289 项通过，0 项失败**：

| 场景 | 通过 | 记录 |
| --- | ---: | --- |
| relic_art_test | 91 | art-refined.log |
| classic_relic_test | 60 | classic-refined.log |
| shop_actions_test | 138 | shop-refined.log |

新贴图检查包含：15 件全覆盖、独立且完整的文件、1024 尺寸、非空图案与透明背景、模型直接落在柜台表面、部件按材质合并，以及真实奖励、购买、战斗和远征界面的引用。原有回归包含购买扣款、随机库存、存档、鼠标、键盘、触屏以及五种横屏尺寸。原有战斗与遗物文本说明保留。

渲染检查使用 Compatibility / NVIDIA RTX 4060；日志中的体积雾和景深提示来自原有场景使用 Forward+ 特效，不影响本次检查。未运行整个项目测试套件。

重现贴图及检查的方法见 `assets/relics/README.md`。例如：

```powershell
godot --path . --rendering-method gl_compatibility res://tests/relic_art_test.tscn -- --capture
```
