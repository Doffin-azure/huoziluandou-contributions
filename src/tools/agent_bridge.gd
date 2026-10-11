extends Node
## AI / 外部程序接入桥：JSON 进，JSON 出。无 UI、可复现。
##
## 输入场景文件（默认 res://tests/scenario.json，或命令行 `-- 路径`）：
## {
##   "seed": 1,
##   "deck": [{"glyph":"击","count":2}, ...],     // 也可写 ["击","击","防",...]
##   "enemies": ["ink_spirit"],
##   "rules": {"opening_draw":10, "turn_draw":3, "plays_per_turn":0, "heat_capacity":10},
##   "board": ["击","防","","", ...],             // 可选：16 格强制盘面
##   "actions": [ {"type":"play","path":[[0,0],[1,0]]}, {"type":"end_turn"} ],
##   "auto": false,                                // true=应用完 actions 后由贪心 bot 续跑
##   "max_turns": 40
## }
##
## 输出：{ scenario, steps[], final(observe), legal_actions[], summary }
## 默认写 res://tests/transcript.json；输入路径可用 `--res://x.json` 指定。
##
## AI 循环用法（固定种子，逐步）：
##   1) 传 {"actions": []} → 读 legal_actions
##   2) 追加一个 action 再传 → 读新的 legal_actions
##   直到 final.done == true。

const DEFAULT_IN := "res://tests/scenario.json"
const DEFAULT_OUT := "res://tests/transcript.json"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var in_path: String = args[0] if args.size() > 0 else DEFAULT_IN
	var out_path: String = DEFAULT_OUT
	if args.size() > 1:
		out_path = args[1]
	if not FileAccess.file_exists(in_path):
		_write(out_path, "{\n  \"error\": \"场景文件不存在: %s\"\n}\n" % in_path)
		print("[agent_bridge] 缺少场景文件: ", in_path)
		get_tree().quit()
		return

	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(in_path))
	if cfg == null:
		cfg = {}
	var out := run_scenario(cfg)
	_write(out_path, JSON.stringify(out, "  "))
	print("[agent_bridge] %s → %s" % [in_path, out_path])
	get_tree().quit()


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func run_scenario(cfg: Dictionary) -> Dictionary:
	var h := BattleHarness.new()
	var reset_cfg := cfg.duplicate(true)
	if cfg.has("rules"):
		for k in cfg["rules"].keys():
			reset_cfg[k] = cfg["rules"][k]
	h.reset(reset_cfg)

	var steps: Array = []
	var max_turns := int(cfg.get("max_turns", 40))
	var actions: Array = cfg.get("actions", [])

	for a in actions:
		if h.is_done():
			break
		steps.append({"action": a, "result": h.apply(a), "turn": h.battle.turn})

	if bool(cfg.get("auto", false)) or (actions.is_empty() and bool(cfg.get("default_auto", false))):
		var guard := 0
		while not h.is_done() and guard < max_turns:
			guard += 1
			var acts := h.legal_actions()
			var pick := _pick(acts)
			steps.append({"action": pick, "result": h.apply(pick), "turn": h.battle.turn})

	var out := {
		"scenario": {"seed": h.seed, "board": cfg.get("board", null)},
		"steps": steps,
		"final": h.observe(),
		"summary": h.summary(),
	}
	if not h.is_done():
		out["legal_actions"] = h.legal_actions()
	return out


func _pick(actions: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1
	for a in actions:
		if a.get("type") != "play" or a.get("word") == null:
			continue
		if int(a.get("score", 0)) > best_score:
			best = a
			best_score = int(a.get("score", 0))
	if not best.is_empty():
		return best
	return {"type": "end_turn"}
