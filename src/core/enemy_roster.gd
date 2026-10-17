extends RefCounted
class_name EnemyRoster
## 精选20怪，初稿生命与伤害原值；机制实现见 EnemyMechanics。
const DEFINITIONS := [
	{"id": "paper_shell", "name": "纸壳兵", "glyph": "纸", "hp": 32, "block": 8, "act": 1, "elite": false, "boss": false, "mechanic": "shell",
	 "desc": "补盾不攻击，也不是每次+8；当前盾已达8时不再增加。没有额外减伤、反伤或新甲片。",
	 "moves": [["刺击", "", 6, 1, 0], ["补纸", "refill8", 0, 1, 0]]},
	{"id": "needle_bee", "name": "连针蜂", "glyph": "连", "hp": 34, "block": 0, "act": 1, "elite": false, "boss": false, "mechanic": "bee",
	 "desc": "三段小伤与单段重击交替。新版御只减下一次伤害2，不逐段生效；反单字在整次敌攻击结束后反击6一次，不逐段触发。提前建立的跨战防御力才逐段减1。",
	 "moves": [["连针", "", 3, 3, 0], ["蓄势", "wait", 0, 1, 0], ["重刺", "", 10, 1, 0]]},
	{"id": "tilting_inkwell", "name": "倾砚", "glyph": "倾", "hp": 34, "block": 0, "act": 1, "elite": false, "boss": false, "mechanic": "tilt",
	 "desc": "方向与旋转区域提前显示。重力只压缩该方向的空隙，不打乱相对顺序；固定字不移动，旋转遇固定字时整次跳过。没有额外的重击加成。",
	 "moves": [["左倾", "gravity", 0, 1, 0], ["溅墨", "", 7, 1, 0], ["旋砚", "rotate", 0, 1, 0], ["溅墨", "", 7, 1, 0]]},
	{"id": "fold_moth", "name": "折页蛾", "glyph": "折", "hp": 32, "block": 0, "act": 1, "elite": false, "boss": false, "mechanic": "fold",
	 "desc": "折页前标记一枚非固定己方原实体。该字成功组词、单打或被玩家效果移出盘面，折页为5；未处理为8。通过组词解除时，额外对怪物造成3机制伤害。仅换位置不解除；原实体组词后因额外使用留盘也算完成。",
	 "moves": [["折页", "fold", 8, 1, 0], ["扑击", "", 7, 1, 0]]},
	{"id": "blank_child", "name": "留白童", "glyph": "留", "hp": 36, "block": 0, "act": 1, "elite": false, "boss": false, "mechanic": "blank",
	 "desc": "留白攻击前只检查一次：空格≥3，怪物受到3机制伤害；空格＜3，怪物获得4护盾。随后正常攻击6，不额外封格或减补字。",
	 "moves": [["留白", "blank", 6, 1, 0], ["扑击", "", 8, 1, 0]]},
	{"id": "corrosion_beetle", "name": "墨蚀蠹", "glyph": "墨", "hp": 38, "block": 0, "act": 1, "elite": false, "boss": false, "mechanic": "corrosion",
	 "desc": "只向空格注入指定字形；该怪制造且仍在盘上的蚀最多3枚，满额不再补，不进入永久字袋。玩家可以单打蚀、净化、分流或借它组成心蚀。指定字形注入属于新增机制，不能直接沿用通用随机注字当作完成。",
	 "moves": [["蛀咬", "", 6, 1, 0], ["注蚀", "corrode", 0, 1, 0]]},
	{"id": "glutton", "name": "饕餮", "glyph": "饕", "hp": 52, "block": 0, "act": 2, "elite": false, "boss": false, "mechanic": "glutton",
	 "desc": "腹中最多3枚己方原实体，移出当前循环但完整保存；吞取前展示目标，腹满或无弃字不吞、不加盾。玩家一次出字造成任一段实际生命伤害≥10，或一个词实际消耗≥3枚材料，吐一枚至袋顶；每次出字最多吐一枚。战斗结束全部归还。",
	 "moves": [["啃咬", "", 10, 1, 0], ["吞字", "swallow", 0, 1, 0], ["腹击", "belly", 10, 1, 0]]},
	{"id": "furnace_beast", "name": "炉腹兽", "glyph": "炉", "hp": 44, "block": 0, "act": 2, "elite": false, "boss": false, "mechanic": "furnace",
	 "desc": "每次攻击后升热2，并向盘面空格注入1枚带灼热污染的【热】；可组成热流、电热等词，单打或组词打出时失去1生命，净化免除污染代价。攻击前热度≥8则伤害+4；攻击后的升热不追溯增强本次伤害，溢热仍按正常规则生成字袋污染。",
	 "moves": [["炉息", "heat6", 6, 1, 0], ["喷焰", "heat8", 8, 1, 0]]},
	{"id": "charge_badger", "name": "余电獾", "glyph": "余", "hp": 48, "block": 0, "act": 2, "elite": false, "boss": false, "mechanic": "charge",
	 "desc": "只统计放弧前这一玩家阶段：实际储能消费减去对应这些消费的实际退款≥2，放弧前移除怪物最多6普通盾，攻击降为6；不足2则攻击10。阶段外旧消费的退款不反扣当前任务，储能正常获得不抵消消费。",
	 "moves": [["聚电", "", 0, 1, 6], ["放弧", "arc", 10, 1, 0], ["扑击", "", 10, 1, 0]]},
	{"id": "ink_creditor", "name": "赊墨商", "glyph": "赊", "hp": 48, "block": 0, "act": 2, "elite": false, "boss": false, "mechanic": "credit",
	 "desc": "催账前一阶段内，第一次成功支付折扣后大于0的通用费用，取得收讫印。催账前有印则移除怪物最多8普通盾，催账降至6。临时资金、合资储能和金币支付均有效；失败、取消、折后0费均无效。每次挂账重置旧印。",
	 "moves": [["挂账", "", 0, 1, 8], ["催账", "bill", 10, 1, 0], ["扑击", "", 8, 1, 0]]},
	{"id": "double_slip", "name": "双面简", "glyph": "双", "hp": 50, "block": 0, "act": 2, "elite": false, "boss": false, "mechanic": "pair",
	 "desc": "标记同一行两枚非固定己方实体A、B和原坐标。玩家阶段内使两者完整互换原坐标，或用一个词同时使用两者，即完成，怪物受5机制伤害，合简降至7；仅将其中一枚单打／移出盘面，合简为9，无奖励；未完成则12。完整解优先于离盘降级，不能因组词消耗目标而误判为9。无合法目标时翻签得4盾，合简固定9。",
	 "moves": [["翻签", "flip", 0, 1, 0], ["合简", "pair", 12, 1, 0], ["扑击", "", 9, 1, 0]]},
	{"id": "nest_moth", "name": "铸巢蛾", "glyph": "铸", "hp": 52, "block": 0, "act": 2, "elite": false, "boss": false, "mechanic": "nest",
	 "desc": "结巢获得6盾，并往空格注入1枚蔓生【连】；每枚未净化的连在下个玩家回合结束复制1枚，同源盘面最多4枚，可单打或组成连击、心连心清理。净化停止复制。啄字前阶段内，真实己方原实体通过补字或回收进入盘面再成功组词，移除最多6普通盾，啄字降至7；临时生成、纯移动和重连返还不计。",
	 "moves": [["结巢", "seed_nest", 0, 1, 6], ["啄字", "nest", 11, 1, 0], ["扑击", "", 9, 1, 0]]},
	{"id": "bomb_press", "name": "爆印机", "glyph": "爆", "hp": 48, "block": 0, "act": 2, "elite": false, "boss": false, "mechanic": "bomb",
	 "desc": "两格选在同一2×2内，提前显示；标记绑定坐标，不跟随原字。引爆只摧毁仍在标记格的非固定字：己方原实体进弃字，敌方／临时字移除；防爆生效时原实体改回字袋，每救回1枚得1持久盾。叠层按一个格位处理，但其中原实体逐枚按规则回收。",
	 "moves": [["布印", "bomb_mark", 0, 1, 0], ["引爆", "bomb", 8, 1, 0]]},
	{"id": "copy_master", "name": "拓印师", "glyph": "拓", "hp": 62, "block": 0, "act": 2, "elite": true, "boss": false, "mechanic": "copy",
	 "desc": "拓读取其前一个玩家阶段最后成功的多字词，按固定优先级执行：攻击类→攻击10；防御类→得盾8；补字／空间类→向空格注1枚堵塞【重】（可组重击、重力，打出后下次正常补字-1）；经济类→得盾6；其余或没出词→得盾3。同一词多类取前者；不复制玩家实际爆发数值。单字不改记录。",
	 "moves": [["笔击", "", 10, 1, 0], ["拓", "copy", 0, 1, 0], ["笔击", "", 10, 1, 0]]},
	{"id": "seal_officer", "name": "钤印官", "glyph": "钤", "hp": 60, "block": 0, "act": 2, "elite": true, "boss": false, "mechanic": "seal",
	 "desc": "印区按坐标固定，朱批伤害=8+2×区域内剩余占用格数，最高16；只检查一次，不改变字的归属。流速补回的新字也算占格；区域内原地旋转不减少占格。新一次标记替换旧区域。",
	 "moves": [["钤印", "seal_mark", 0, 1, 0], ["朱批", "seal", 8, 1, 0], ["笔击", "", 10, 1, 0]]},
	{"id": "wheel_master", "name": "轮印师", "glyph": "轮", "hp": 66, "block": 0, "act": 2, "elite": true, "boss": false, "mechanic": "wheel",
	 "desc": "压印前阶段内，同一枚己方原实体参加两次成功多字词，即造成8机制伤害、压印降至8。只看原实体身份；相同字形的新复制不替代。合击中共享原实体参加两个实际结算词可完成；词效重演不增加次数。每题一次。",
	 "moves": [["轮铸", "", 0, 1, 8], ["压印", "wheel", 14, 1, 0], ["双印", "", 5, 2, 0]]},
	{"id": "leech", "name": "漏电水蛭", "glyph": "漏", "hp": 52, "block": 0, "act": 2, "elite": true, "boss": false, "mechanic": "leech",
	 "desc": "只有该次攻击实际扣到玩家生命，才偷最多2储能；偷到每1点使怪物得2盾，盾最高8。满盾仍能偷，但不超盾上限；没储能不改扣生命。心力挡住致命伤导致实际生命未减少时，不偷能。",
	 "moves": [["汲电", "leech", 8, 1, 0], ["汲电", "leech", 10, 1, 0]]},
	{"id": "proof_boss", "name": "对校官", "glyph": "对", "hp": 88, "block": 0, "act": 1, "elite": false, "boss": true, "mechanic": "proof",
	 "desc": "转阶段：生命≤当前生命上限50%，初始半血线44。 朱批前标记两枚不同的非固定己方原实体。红签：成词、单打或离盘解除；蓝签：以上方式或移动到另一格解除。每枚未解除签使朱批+2，所以最高12／14。每枚通过成词解除的签，额外造成3机制伤害。只出一签时最高只+2；无目标则基础攻击。",
	 "moves": [["校勘", "proof_shield", 0, 1, 6], ["朱批", "proof", 8, 1, 0], ["双批", "boss_multi", 6, 2, 0]]},
	{"id": "rail_boss", "name": "铅轨机", "glyph": "铅", "hp": 124, "block": 0, "act": 2, "elite": false, "boss": true, "mechanic": "rail",
	 "desc": "转阶段：生命≤当前生命上限50%，初始半血线62。 压轨前标记一行最多3／4枚非固定己方原实体。结算时每枚仍留在原行，攻击+2，最高16／20；回袋、消耗、暂存或移到其他行算撤离。原格补入新字不算旧实体残留；同一原实体成词后因额外使用留在原行仍受计数。全部撤离则压轨攻击后再移除Boss最多8普通盾。空题不发拆盾奖励。",
	 "moves": [["压轨", "rail", 10, 1, 0], ["铅铸", "rail_shield", 0, 1, 8], ["双铸", "boss_multi", 6, 2, 0]]},
	{"id": "compiler_boss", "name": "万词编纂者", "glyph": "万", "hp": 168, "block": 0, "act": 3, "elite": false, "boss": true, "mechanic": "compiler",
	 "desc": "转阶段：生命≤当前生命上限50%，初始半血线84。 异文要求当前阶段出2种不同多字词；重文要求当前阶段同一个多字词主动成功出2次。完成当前题：Boss先受6机制伤害，再攻击8／10；未完成：攻击12／14，随后得6／8盾。每题一次，计数阶段间清空。连击这个词只登记“连击”，重演上词不等于再提交上词。",
	 "moves": [["异文审校", "different", 12, 1, 0], ["重文校印", "repeat", 12, 1, 0], ["收卷", "boss_multi", 6, 3, 0]]},
]
const NORMAL := {1: ["paper_shell", "needle_bee", "tilting_inkwell", "fold_moth", "blank_child", "corrosion_beetle"],
2: ["glutton", "furnace_beast", "charge_badger", "ink_creditor", "double_slip", "nest_moth", "bomb_press"],
3: ["glutton", "furnace_beast", "charge_badger", "ink_creditor", "double_slip", "nest_moth", "bomb_press"]}
# 初稿无一幕精英：保留原有铁画；三幕复用二幕机制，不暗加倍率。
const ELITES := {1: ["iron_seal"], 2: ["copy_master", "seal_officer", "wheel_master", "leech"], 3: ["copy_master", "seal_officer", "wheel_master", "leech"]}
const BOSSES := {1: "proof_boss", 2: "rail_boss", 3: "compiler_boss"}

static func save_enemies() -> void:
	for spec in DEFINITIONS:
		var ed := EnemyData.new()
		ed.id = spec.id
		ed.name = spec.name
		ed.glyph = spec.glyph
		ed.max_hp = spec.hp
		ed.initial_block = spec.block
		ed.act = spec.act
		ed.mechanic = spec.mechanic
		ed.description = spec.desc
		ed.is_boss = spec.boss
		ed.is_elite = spec.elite
		for item in spec.moves:
			var mv := EnemyMoveData.new()
			mv.title = item[0]
			mv.mechanic_action = item[1]
			mv.damage = item[2]
			mv.hits = item[3]
			mv.block = item[4]
			mv.kind = EnemyMoveData.Kind.SPECIAL
			if mv.block > 0: mv.kind = EnemyMoveData.Kind.BLOCK
			if mv.damage > 0: mv.kind = EnemyMoveData.Kind.MULTI if mv.hits > 1 else EnemyMoveData.Kind.ATTACK
			mv.description = "循环行动：" + " → ".join(spec.moves.map(func(m): return m[0]))
			ed.moves.append(mv)
		assert(ResourceSaver.save(ed, "res://resources/enemies/%s.tres" % ed.id) == OK)

static func save_acts() -> void:
	for act_i in [1, 2, 3]:
		var act := ActData.new()
		act.index = act_i
		act.title = ["第一幕 · 起步", "第二幕 · 成型", "第三幕 · 兑现"][act_i - 1]
		var types := [MapNodeData.Type.BATTLE, MapNodeData.Type.BATTLE, MapNodeData.Type.EVENT, MapNodeData.Type.BATTLE, MapNodeData.Type.SHOP, MapNodeData.Type.FORK, MapNodeData.Type.REST, MapNodeData.Type.BOSS]
		var titles := ["初试", "第二条线", "途中小憩", "机制之敌", "市集", "岔路", "休整", "幕末首领"]
		var slot := 0
		for index in 8:
			var node := MapNodeData.new()
			node.order = index + 1
			node.type = types[index]
			node.title = titles[index]
			var pool: Array = []
			if node.type == MapNodeData.Type.BATTLE:
				for j in NORMAL[act_i].size():
					if mini(2, j / 2) == slot: pool.append(NORMAL[act_i][j])
				slot += 1
			elif node.type == MapNodeData.Type.FORK:
				pool = ELITES[act_i]
				node.is_optional_branch = true
			elif node.type == MapNodeData.Type.BOSS: pool = [BOSSES[act_i]]
			for id in pool: node.enemy_pool.append(load("res://resources/enemies/%s.tres" % id))
			if not node.enemy_pool.is_empty(): node.enemies = [node.enemy_pool[0]]
			act.nodes.append(node)
		assert(ResourceSaver.save(act, "res://resources/acts/act_%d.tres" % act_i) == OK)
