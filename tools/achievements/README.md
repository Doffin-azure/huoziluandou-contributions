# 成就系统与配置

游戏已接入48项玉符成就、32个统计指标。主界面「成就总览」显示已解锁、未解锁、达成条件、进度与未满足的前置，可按分类、状态和文字筛选。达成时提示依次出现，切换场景仍会继续显示。

策划编辑 `策划配置/成就配置.xlsx`，保存后双击同目录「导入成就配置」；重启游戏生效。Mac用 `.command`，Windows用 `.bat`。需要Python 3，无第三方依赖。只修改成就定义，不改变战斗数值或玩家进度。

```sh
python3 tools/achievements/import_achievements.py --check
python3 tools/achievements/import_achievements.py
python3 tools/achievements/import_achievements.py --restore
```

输出为 `data/achievements/catalog.json`；导入前的有效配置备份为 `catalog.json.bak`。只校验不写入，恢复只替换JSON，不回写Excel。无效工作簿和损坏的旧JSON不会被覆盖。接入前v1定义的元数据会迁移至v2，目标值保持原值。支持 `--input`、`--output`、`--schema` 以便隔离测试。

## 表格约定

- 第4行为表头，第5行起为数据。可排序、复制数据行；保留表头与列顺序，不使用公式。
- 目标、开关、排序为浅黄格；名称、说明、品质、分类、前置和美术需求也可改。指标字典为只读程序契约，新增指标必须同步代码。
- 名称使用繁体。说明保留 `{target}`，不能手写目标数字或使用其他占位符。改目标后说明自动更新。
- 成就ID与徽章ID发布后保持稳定。用「启用=0」停用；改ID会失去旧进度的展示关联。
- 前置ID用英文逗号分隔，全部达成后解锁；前置未完成时仍统计进度。不能循环依赖或依赖停用项。
- `enemy_kills` 允许筛选 `boss_lead_plate`（铅版）、`boss_word_demon`（字魔）、`boss_chaos_press`（混铅海），其他指标的筛选列留空。
- 按当前需求，所有启用成就都展示名称和条件。「隐藏」列保留兼容，本版不遮挡未解锁条件。
- 品质为素玉、青玉、金縫、墨玉，只是美术标签，无战斗加成。

## 玉符资源

默认使用已确认的 `assets/achievements/previews/achievement_atlas_jade_unique_v6.png`，图案区域在 `data/achievements/jade_icons.json` 中逐项对应。运行时使用AtlasTexture并以着色器淡去原图底色，没有修改原图；名称来自Excel，不依赖图中文字。

「徽章美术」保持成就与玉符一一对应。图标路径留空时使用现有图集；填入 `assets/achievements/` 下的独立PNG或SVG路径时，资源存在就优先使用。新增成就需提供新图案。独立资源为512×512透明画布、自然物象轮廓、四周留40像素；64像素下检查辨识度。保留自然玉材、沁色与细金补缝，不再使用六边金属框，不靠换色重复图案。

导出包需要包含 `data/achievements/*.json` 和v6图集纹理；本地Android预设的include_filter已补入该数据目录。`export_presets.cfg` 在本项目被Git忽略，新建导出预设时也应保留此规则。

## 统计与存档

正式冒险、经典路线和旧版远征共用 `user://achievements.json`。自定义构筑、作弊和自动化测试不计。作弊只停止本局后续统计，之前获得的成就保留。

累计进度跨局保存；单局、单战、单回合、单次条件在相应边界重新统计，总览展示历史最高记录。已解锁永久保留；降低目标后启动时重新判定，提高目标不收回已解锁结果。旧版本没有明细的行为不补算。

以实际成功结算为依据：无效连线、取消服务、失败融合不计；组词重演不重复记出词。伤害只计实际扣血和吸盾，储能与降温只计实付/实降，镀金金币只计实际入账。净化按移除的污染标签数计；普通签和区域标记不算污染。折页、红蓝签和压轨在真实任务完成路径计数。

节点、交易与战斗事实携带稳定ID，避免重复回调和读档刷同一奖励。房间冒险存档携带成就会话，恢复时账号中较新的去重记录优先。旧冒险存档从恢复后开始统计，并补存会话ID。解锁立即保存，平时合并写入；保留一份有效备份，损坏时尝试备份，均损坏时保留原文件。测试使用独立存档路径。

验证：`python3 -m unittest discover -s tests -p 'test_achievement_import.py'`；Godot场景 `tests/achievement_system_test.tscn`、`achievement_hooks_test.tscn`、`achievement_run_test.tscn` 与 `title_menu_test.tscn`。
