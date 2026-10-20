# 遗物贴图

`icons/` 包含全部 38 件遗物的 1024×1024 透明 PNG。直接渲染商店使用的 `relic_specimen.gd` 与 `relic_expansion.gd`，沿用青铜、墨绿、旧纸配色。全部取消通用展示底盘。

2026-10-19 补齐新增的 23 件模型和图标，原有 15 张 PNG 保持逐字节一致。新增模型包括开盖铅盒、熔蜡、血珀内的蝉、骨手、裂纹瓷瓶、腐果、骨骰、命灯、寿契、九连环、草人、金缕衣、阴阳镜和编绳等。每件均有独立轮廓和器物细节，模型与图标按稳定 ID 对应名称和效果。

细节包括：刀柄缠线与刃口、金属倒角与铆钉、器物刻字、活字版块、香炉内壁与器足、布料褶皱与针脚、转轮轮齿与手摇柄、电瓶接线、立体弯曲火焰、叶片与叶脉，以及屏风山水和竹枝。`relic_mesh.gd` 将这些部件合并为按材质分组的网格，`relic_pigment.gdshader` 提供金属氧化、木纹、织物纹理和石材颗粒。

`src/ui/relic_art.gd` 统一预载图标，供购买确认、战斗说明、远征整备与远征商店使用。精英、首领奖励通过 `relic_preview.gd` 显示实际 3D 网格；鼠标悬停和键盘焦点可转动模型，点击模型或名称即可领取。预览按需渲染，静止时保留画面。拾取后的绑定、贴金、复制与许愿流程保持有效。黑水瓶、命灯、寿契仍只通过专属事件取得。

重新导出（需图形渲染器）：

```powershell
godot --path . --rendering-method gl_compatibility res://src/tools/bake_relic_icons.tscn -- --missing-only
godot --headless --path . --editor --import --quit
```

`--missing-only` 保留已有 PNG，只生成缺失图标并更新图集；移除此参数会重新渲染全部模型。`icons/manifest.json` 记录四份模型/材质源文件的 SHA-256，以及每张图片的尺寸与 SHA-256。图片以 1536 分辨率渲染后缩小到 1024，逐件按轮廓取景。全部图集、新增 23 件图集及真实奖励截图位于 `docs/qa/relic-expansion-2026-10-19/`；验证记录见该目录的 `README.md`。
