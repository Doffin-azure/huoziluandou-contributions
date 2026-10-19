# 扩展事件目录

保留 `src/data/event_catalog.gd` 中的现有事件。新增事件可各自保存为本目录下的 `.tres` 或 `.res`，启动时按文件名排序登记；稳定 ID 不允许重复。无需修改地图生成器或效果解释器。

示例（另存为 `your_event.tres`，不要直接把示例加入正式事件池）：

```ini
[gd_resource type="Resource" script_class="" load_steps=2 format=3]
[ext_resource type="Script" path="res://src/data/event_definition.gd" id="1"]

[resource]
script = ExtResource("1")
event = {
"id": "your_event",
"title": "庭中残页",
"body": "一页旧纸压在灯座下。",
"acts": [1, 2],
"tags": ["gold", "heal"],
"weight": 1.0,
"options": [
{"text": "拾取铜钱", "effects": [{"type": "gold", "amount": 12}]},
{"text": "坐下歇息", "effects": [{"type": "heal", "amount": 6}]},
{"text": "离开", "effects": []}
]
}
```

`acts` 默认允许三幕，`weight` 默认 1，非正权重不抽取。`requires`、分支 `nodes`、选项 `goto` 和现有效果协议继续使用。插图写为 `illustration` 路径，只在事件界面需要时加载。

抽取袋按幕保存，耗尽前不重复，开启新一轮时避开紧邻重复。失去对应遗物等条件变化会清理失效候选。存档保存抽取袋、上次事件、已抽记录、当前事件内容和玩法随机状态，读档不会重抽。目录扩展只影响后续抽取。

扩展回归：`<godot> --headless --path . tests/event_system_test.tscn`。
