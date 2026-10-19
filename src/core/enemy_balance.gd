extends RefCounted
class_name EnemyBalance
## Excel -> 已校验 JSON -> 运行时资源副本。默认表与覆盖表均不改写原始 .tres。
const SCHEMA_PATH := "res://data/balance/schema.json"
const CONFIG_PATH := "res://data/balance/enemies.json"
static var schema: Dictionary = {}

static func row_key(row: Array, columns: Array) -> String:
	var parts: Array[String] = []
	for index in columns:
		var value: Variant = row[int(index)]
		# Godot 的 JSON 数字是 float；行动序号 1.0 与 Excel 的整数键 1 统一。
		parts.append(str(int(value)) if value is float and is_finite(value) and value == floor(value) else str(value))
	return "/".join(parts)

static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

static func validate_payload(payload: Variant) -> String:
	if not payload is Dictionary or payload.get("version") != schema.get("version"): return "配置版本不匹配"
	if not payload.get("tables") is Dictionary: return "缺少配置表"
	var tables: Dictionary = payload.tables
	if tables.size() != schema.sheets.size(): return "配置表数量不匹配"
	for spec in schema.sheets:
		if not tables.get(spec.name) is Array: return "缺少表：" + spec.name
		var expected := {}
		for row in spec.rows: expected[row_key(row, spec.key)] = row
		var seen := {}
		for row in tables[spec.name]:
			if not row is Array or row.size() != spec.columns.size(): return spec.name + "：列数错误"
			var key := row_key(row, spec.key)
			if not expected.has(key) or seen.has(key): return spec.name + "：未知或重复ID " + key
			seen[key] = true
			for index in row.size():
				var col: Dictionary = spec.columns[index]
				var value: Variant = row[index]
				var editable := bool(col.editable)
				if spec.has("editable_by_key"):
					editable = editable and spec.editable_by_key[key].any(func(i): return int(i) == index)
				if editable:
					if not (value is int or value is float): return spec.name + "：数值必须为整数 " + key
					if not is_finite(float(value)) or float(value) != floor(float(value)): return spec.name + "：数值必须为整数 " + key
					var low: int = int(expected[key][5]) if spec.name == "机制参数" else int(col.min)
					var high: int = int(expected[key][6]) if spec.name == "机制参数" else int(col.max)
					if value < low or value > high: return spec.name + "：数值超范围 " + key
				elif value != expected[key][index]: return spec.name + "：标识或说明列被改动 " + key
		if seen.size() != expected.size(): return spec.name + "：缺少记录"
	return ""

static func load_into(enemies: Dictionary, pollutions: Dictionary) -> String:
	var source: Variant = read_json(SCHEMA_PATH)
	if not source is Dictionary: return "无法读取怪物默认配置"
	schema = source
	var payload := {"version": schema.version, "tables": {}}
	for spec in schema.sheets: payload.tables[spec.name] = spec.rows
	var warning := ""
	if FileAccess.file_exists(CONFIG_PATH):
		var candidate: Variant = BattleBalance.enemy_payload()
		if candidate.is_empty(): candidate = read_json(CONFIG_PATH)
		warning = validate_payload(candidate)
		if warning.is_empty(): payload = candidate
		else: warning = "怪物配置未应用，使用默认数值：" + warning
	# 整表校验通过后才应用；缓存的源资源保持不变，重载不会叠加修改。
	for id in enemies: enemies[id] = enemies[id].duplicate(true)
	for id in pollutions: pollutions[id] = pollutions[id].duplicate(true)
	for row in payload.tables["怪物"]:
		var ed: EnemyData = enemies.get(row[0])
		if ed != null:
			ed.max_hp = int(row[3])
			ed.initial_block = int(row[4])
			ed.tuning = {}
	for row in payload.tables["行动"]:
		var ed: EnemyData = enemies.get(row[0])
		if ed == null or int(row[2]) > ed.moves.size(): continue
		var move: EnemyMoveData = ed.moves[int(row[2]) - 1]
		move.damage = int(row[5])
		move.hits = int(row[6])
		move.block = int(row[7])
		move.inject_count = int(row[8])
		move.inject_glyph = row[9]
		move.pollution_id = row[10]
		move.status_id = row[11]
		move.status_stacks = int(row[12])
		if move.mechanic_action == "corrode": move.kind = EnemyMoveData.Kind.INJECT
		if move.kind in [EnemyMoveData.Kind.ATTACK, EnemyMoveData.Kind.MULTI]:
			move.kind = EnemyMoveData.Kind.MULTI if move.hits > 1 else EnemyMoveData.Kind.ATTACK
	for row in payload.tables["机制参数"]:
		var ed: EnemyData = enemies.get(row[0])
		if ed != null: ed.tuning[row[2]] = int(row[4])
	for row in payload.tables["污染"]:
		var pd: PollutionData = pollutions.get(row[0])
		if pd != null:
			pd.hp_loss_on_play = int(row[2])
			pd.draw_penalty_on_play = int(row[3])
			pd.description = pollution_description(pd)
	for ed in enemies.values():
		ed.description = describe(ed)
	return warning

static func parameters(ed: EnemyData) -> Dictionary:
	var p: Dictionary = ed.tuning.duplicate()
	for move in ed.moves:
		if not move.mechanic_action.is_empty():
			p[move.mechanic_action + "_damage"] = move.damage
			if not p.has(move.mechanic_action + "_block"): p[move.mechanic_action + "_block"] = move.block
			p[move.mechanic_action + "_inject"] = move.inject_count
	return p

static func describe(ed: EnemyData) -> String:
	var p := parameters(ed)
	var template := ""
	match ed.mechanic:
		"bee": template = "连针为多段攻击，蓄势后重刺。每段伤害和段数见当前意图。"
		"tilt": template = "左倾让每行字向左靠拢；旋砚将中央2×2顺时针旋转。固定字不移动，旋转区域有固定字时整次跳过。"
		"shell": template = "补纸将临时格挡补到{shield_target}，已经达到时不再增加。"
		"fold": template = "标记1字。打出或移出盘面可解签，仅移动无效。折页伤害：未解{fold_damage}，解签后{resolved_damage}；组词解签再对怪物造成{reward}伤害。"
		"blank": template = "攻击前有至少{empty_required}个空格，怪物受到{reward}伤害；否则获得{shield_gain}格挡。随后攻击{blank_damage}。"
		"corrosion": template = "塞入{corrode_inject}枚刺痛【蚀】，同源最多{inject_cap}枚。可单打、组【心蚀】用掉，或净化污染。"
		"glutton": template = "从弃字堆吞入至多{stomach_capacity}枚原字，每吞1字获得{swallow_block}格挡，腹击伤害+1，最多+{belly_bonus_cap}。打出时单段使它掉血至少{release_hit}，或一个词用掉至少{release_material}字，吐回1字到袋顶；战后归还全部。"
		"furnace": template = "攻击前热度达到{heat_threshold}时，伤害+{heat_bonus}。炉息塞{heat6_inject}枚、喷焰塞{heat8_inject}枚灼热【热】，攻击后热度+{heat_gain}。"
		"charge": template = "本回合实际消耗储能减去对应退款达到{energy_required}时，放弧降至{resolved_damage}伤害，并拆除怪物{break_block}格挡；否则造成{arc_damage}伤害。"
		"credit": template = "本回合成功支付过非零费用时，催账降至{resolved_damage}伤害，并拆除怪物{break_block}格挡；否则造成{bill_damage}伤害。合资代付也算，免费或失败不算。"
		"pair": template = "标记2字。互换两字原位，或在同一词中使用两字：怪物受{reward}伤害，合简降至{resolved_damage}。未完成上述条件时，有字离盘则为{partial_damage}，否则为{pair_damage}；无目标时为{partial_damage}。"
		"nest": template = "结巢获得{seed_nest_block}格挡，塞入{seed_nest_inject}枚蔓生【连】。本回合让己方原字补入盘面后再组词，啄字降至{resolved_damage}伤害，并拆除{break_block}格挡。蔓生同源最多{inject_cap}枚，复制规则见蔓生词条。"
		"bomb": template = "预告2格。引爆造成{bomb_damage}伤害，并摧毁标记格内未固定的字；把字移走可避开。防爆生效时，己方原字改为回袋，每字获得{protect_block}持久盾。"
		"copy": template = "按上一个词的类型行动：攻击类造成{attack_damage}伤害；防御类获得{defense_block}格挡；空间类塞{copy_inject}枚堵塞【重】；经济类获得{economy_block}格挡。其他或无词时获得{other_block}格挡，单字不改记录。"
		"seal": template = "预告印区。朱批造成{seal_damage}伤害，区域内每有1字再+{occupied_bonus}。清空印区可避免加伤。"
		"wheel": template = "本回合让同一枚己方原字参与{required_uses}次组词，怪物受{reward}伤害，压印降至{resolved_damage}；否则造成{wheel_damage}伤害。临时复制和效果重演不计。"
		"leech": template = "攻击使你掉血后，偷取至多{steal}储能；每点转为{shield_per_energy}格挡，格挡最多{shield_cap}。满盾仍会偷储能。"
		"proof": template = "标记红蓝签。红签须打出或离盘；蓝签还可移动解除。每枚未解签使朱批伤害+{unresolved_bonus}；组词解签对怪物造成{reward}伤害。生命≤{phase_percent}%进入二阶段。"
		"rail": template = "标记一行至多{target_count}字，二阶段为{phase2_target_count}字。每枚仍在原行的标记字使压轨伤害+{unresolved_bonus}；全部撤离后，攻击结束拆除{clear_break}格挡。生命≤{phase_percent}%进入二阶段。"
		"compiler": template = "异文要求{distinct_required}种不同词，重文要求同词打出{repeat_required}次。完成后怪物受{reward}伤害，本次攻击降至{resolved_damage}，二阶段为{phase2_resolved_damage}。未完成时攻击后获{fail_block}格挡，二阶段{phase2_fail_block}。重演不计次数；生命≤{phase_percent}%进入二阶段。"
	if not template.is_empty(): return template.format(p)
	if not ed.description.is_empty(): return BattleText.clean(ed.description)
	var moves: Array[String] = []
	for move in ed.moves: moves.append(move.title + "：" + BattleText.enemy_move(move))
	return "按顺序循环行动：\n" + "\n".join(moves)


static func pollution_description(data: PollutionData, settings: Dictionary = {}) -> String:
	var lines: Array[String] = []
	if data.id == "replicate":
		if settings.has("replicate_count"):
			lines.append("等待%d回合后，每回合结束复制%d字；同源最多%d枚，没有空格时不复制。" % [maxi(1, int(settings.get("replicate_delay", 1))), int(settings.replicate_count), int(settings.get("inject_cap", 4))])
		else:
			lines.append("留在盘面会复制；数量和等待回合取决于制造它的怪物。")
		lines.append("用掉此字或净化可阻止复制。")
	if data.hp_loss_on_play > 0: lines.append("单打或组词使用此字时，失去%d生命。" % data.hp_loss_on_play)
	if data.draw_penalty_on_play > 0: lines.append("使用此字后，下次正常补字减少%d枚。" % data.draw_penalty_on_play)
	if data.id == "scorch": lines.append("敌人塞入的字用后消失；溢热生成的【热】本场循环，战后移除。")
	if data.id != "replicate": lines.append("净化可移除此污染。")
	return "".join(lines)
