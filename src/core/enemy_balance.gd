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
		var candidate: Variant = read_json(CONFIG_PATH)
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
			pd.description = ("留在盘面的敌方字按制造怪物说明的等待回合、复制数量和盘面上限蔓生。单打、组词消耗或净化可停止复制。" if pd.id == "replicate" else "") + "单打或组词打出时失去%d生命，下次正常补字减少%d枚。净化可免除污染代价。" % [pd.hp_loss_on_play, pd.draw_penalty_on_play]
	for ed in enemies.values():
		if not ed.mechanic.is_empty(): ed.description = describe(ed)
	return warning

static func describe(ed: EnemyData) -> String:
	var p: Dictionary = ed.tuning.duplicate()
	for move in ed.moves:
		if not move.mechanic_action.is_empty():
			p[move.mechanic_action + "_damage"] = move.damage
			p[move.mechanic_action + "_block"] = move.block
			p[move.mechanic_action + "_inject"] = move.inject_count
	var template := ""
	match ed.mechanic:
		"shell": template = "补纸将普通护盾补至{shield_target}，已达目标时不再增加。"
		"fold": template = "提前标记一枚己方原实体。单打、成词或移出盘面可解签，使折页伤害由{fold_damage}降至{resolved_damage}；通过成词解签另造成{reward}机制伤害。纯移动不解签。"
		"blank": template = "留白攻击前空格至少{empty_required}，怪物受到{reward}机制伤害；否则获得{shield_gain}盾。随后攻击{blank_damage}。"
		"corrosion": template = "注蚀向空格注入{corrode_inject}枚刺痛【蚀】，同源盘面最多{inject_cap}枚。可单打、净化或组成心蚀；打出代价见污染说明，不进入永久字袋。"
		"glutton": template = "最多吞{stomach_capacity}枚弃字中的己方原实体，每次成功吞字得{swallow_block}盾。一次出字单段生命伤害达到{release_hit}，或一词消耗至少{release_material}枚材料，吐回一枚至袋顶。每次出字最多吐一枚，战后全部归还。"
		"furnace": template = "每次攻击前热度至少{heat_threshold}，本次伤害增加{heat_bonus}。炉息后注入{heat6_inject}枚、喷焰后注入{heat8_inject}枚灼热【热】，再升热{heat_gain}。可组热流、电热；打出代价见污染说明。"
		"charge": template = "本玩家阶段实际净储能消费至少{energy_required}，放弧前拆除最多{break_block}普通盾，伤害由{arc_damage}降至{resolved_damage}。退款抵扣对应消费，正常获得储能不抵扣。"
		"credit": template = "本阶段首次成功支付正数通用费用即获得收讫印；催账前有印拆除最多{break_block}普通盾，伤害由{bill_damage}降至{resolved_damage}。折后零费、失败、取消不计。"
		"pair": template = "同一行两枚标记原实体完整互换原坐标，或同词使用两者，奖励{reward}机制伤害，合简降至{resolved_damage}。只处理其中一枚降至{partial_damage}，未处理为{pair_damage}。空题得{empty_block}盾，伤害固定{partial_damage}。"
		"nest": template = "结巢得{seed_nest_block}盾并向空格注入{seed_nest_inject}枚蔓生【连】。每枚新连等待{replicate_delay}个玩家回合后，每回合结束复制{replicate_count}枚，同源盘面最多{inject_cap}枚；单打、组词或净化可停止复制。啄字前阶段内真实己方原实体补入再成词，拆{break_block}盾，啄字由{nest_damage}降至{resolved_damage}。"
		"bomb": template = "布印将盾补至{mark_block}并预告两格。引爆攻击{bomb_damage}，摧毁仍在标记格的非固定字。己方原实体进弃字，敌方与临时字移除；防爆使己方实体改回袋，每救回一枚得{protect_block}持久盾。"
		"copy": template = "拓只读上一玩家阶段最后成功多字词。按攻击、防御、空间、经济顺序取首类：攻击{attack_damage}、得盾{defense_block}、塞{copy_inject}枚堵塞【重】、得盾{economy_block}；其他或无词得盾{other_block}。单字不改记录。重可组重击、重力，打出代价见污染说明。"
		"seal": template = "预告固定印区坐标；朱批基础{seal_damage}伤，每个仍占用格增加{occupied_bonus}伤。只检查一次，不改变字的归属。"
		"wheel": template = "同一枚己方原实体在本阶段成功参与{required_uses}次多字词，奖励{reward}机制伤害，压印由{wheel_damage}降至{resolved_damage}。复制新实体、词效重演不计，每阶段奖励一次。"
		"leech": template = "攻击实际扣到生命才偷最多{steal}储能；每点转{shield_per_energy}盾，护盾上限{shield_cap}。满盾仍可偷，没储能不额外扣血。"
		"proof": template = "生命不高于上限{phase_percent}%进入二阶段。朱批标记最多{target_count}枚红蓝签原实体；红签成词、单打或离盘解除，蓝签也可移动解除。每个未解签增加{unresolved_bonus}伤，成词解签奖励{reward}机制伤害。朱批基础{proof_damage}，二阶段{phase2_damage}。"
		"rail": template = "生命不高于上限{phase_percent}%进入二阶段。压轨标记一行最多{target_count}枚，二阶段{phase2_target_count}枚。每个原实体仍留原行增加{unresolved_bonus}伤。基础{rail_damage}伤，二阶段{phase2_damage}；全部撤离则攻击后拆{clear_break}普通盾，空题不奖励。"
		"compiler": template = "生命不高于上限{phase_percent}%进入二阶段。异文要求{distinct_required}种不同多字词，重文要求同词主动成功{repeat_required}次。完成奖励{reward}机制伤害，随后攻击{resolved_damage}／{phase2_resolved_damage}。未完成攻击{different_damage}／{phase2_damage}并得盾{fail_block}／{phase2_fail_block}。每阶段独立计数，词效重演不计。"
	return template.format(p) if not template.is_empty() else ed.description
