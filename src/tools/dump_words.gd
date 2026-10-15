extends Node
## 导出精确词效表（Markdown），用于策划案附录。
## 运行：godot --headless --path . res://src/tools/dump_words.tscn

const ORDER := ["防反", "连携", "流转", "蓄放", "热暴", "经济", "夺字", "淬炼", "空间", "彩蛋"]


func _ready() -> void:
	var groups: Dictionary = {}
	for w in Database.words.values():
		var g: String = w.group if not w.group.is_empty() else "其他"
		if not groups.has(g):
			groups[g] = []
		groups[g].append(w)

	for g in ORDER:
		if not groups.has(g):
			continue
		var list: Array = groups[g]
		list.sort_custom(func(a, b): return a.id < b.id)
		print("\n### %s（%d）\n" % [g, list.size()])
		print("| 词 | 组成 | 交互/目标 | 效果 |")
		print("|---|---|---|---|")
		for w in list:
			print("| **%s** | %s | %s | %s |" % [w.word, _join(w.glyphs), _target(w), _effects(w)])
	# 其他未列分组
	for g in groups.keys():
		if ORDER.has(g):
			continue
		print("\n### %s\n" % g)
		for w in groups[g]:
			print("| **%s** | %s | %s | %s |" % [w.word, _join(w.glyphs), _target(w), _effects(w)])
	get_tree().quit()


func _join(a: Array) -> String:
	var s := ""
	for g in a:
		s += str(g)
	return s


func _target(w: WordData) -> String:
	if not w.interaction.is_empty():
		match w.interaction:
			"reveal_pick_board": return "揭示 5 选 1 → 选盘面格"
			"choose_glyph_empower": return "选字袋 1 个字"
			"choose_battle_card_remove": return "选本场 1 张牌"
			"choose_fuse_pair": return "选 2 张相邻己方牌"
			"choose_same_pair": return "选 2 张相同己方字"
			"choose_row_pair": return "选同一行 2 格"
			"choose_glyph_gild": return "选 1 个字永久镀金"
			"choose_discard_place": return "选弃字堆 1 枚 → 选空格"
			"choose_line": return "选 1 行 / 1 列"
			"choose_merge_flow": return "揭示 1 + 选弃字 1 → 选 2 相邻空格"
			_: return w.interaction
	match w.requires_target:
		1: return "敌方"
		3: return "自身"
		5: return "盘面格"
		6: return "2×2 区域"
		7: return "空格"
		8: return "弃字堆"
		9: return "敌方字"
		_: return "—"


func _effects(w: WordData) -> String:
	if w.effects.is_empty():
		return w.effect_summary if not w.effect_summary.is_empty() else "（无）"
	var parts: Array = []
	for e in w.effects:
		parts.append(e.describe())
	return "；".join(parts)
