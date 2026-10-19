extends Node
## 整局（run）试玩桥：JSON 进，JSON 出。逐步驱动 RunHarness（地图 + 战斗 + 奖励 + 商店 + 事件 + 修整）。
##
## 输入场景文件（默认 res://tests/run_scenario.json，或命令行 `-- 路径`）：
##   { "seed": 1, "starter": "v03", "hp": 60, "gold": 6,
##     "actions": [ {"type":"enter"}, {"type":"play","path":[[0,0],[1,0]]}, {"type":"end_turn"},
##                  {"type":"reward","index":0}, {"type":"shop_buy","index":2}, {"type":"pick","glyph":"击"} ] }
##
## 输出：{ observe, steps[], legal_actions[], summary }（未结束才给 legal_actions）
##
## AI 循环：传 {"actions": []} → 读 legal_actions → 追加一项再传 → 直到 observe.done。

const DEFAULT_IN := "res://tests/run_scenario.json"
const DEFAULT_OUT := "res://tests/run_transcript.json"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var in_path: String = args[0] if args.size() > 0 else DEFAULT_IN
	var out_path: String = args[1] if args.size() > 1 else DEFAULT_OUT
	if not FileAccess.file_exists(in_path):
		_write(out_path, "{\n  \"error\": \"场景文件不存在: %s\"\n}\n" % in_path)
		print("[run_bridge] 缺少场景文件: ", in_path)
		get_tree().quit()
		return
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(in_path))
	if cfg == null:
		cfg = {}
	var out := run_scenario(cfg)
	_write(out_path, JSON.stringify(out, "  "))
	print("[run_bridge] %s → %s" % [in_path, out_path])
	get_tree().quit()


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func run_scenario(cfg: Dictionary) -> Dictionary:
	if cfg.get("mode","")=="courtyard" and not cfg.has("layout"):
		cfg = cfg.duplicate(true); cfg["layout"] = "node_graph"
	var h = load("res://src/expedition/room_run_state.gd").new() if cfg.get("mode", "") == "courtyard" else RunHarness.new()
	h.reset(cfg)
	var steps: Array = []
	for a in cfg.get("actions", []):
		if h.is_done():
			break
		steps.append({"action": a, "result": h.apply(a)})
	var out := {
		"observe": h.observe(),
		"steps": steps,
		"summary": h.summary(),
	}
	if not h.is_done():
		out["legal_actions"] = h.legal_actions()
	return out
