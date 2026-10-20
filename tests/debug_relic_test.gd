extends Control

const Tools = preload("res://src/debug/relic_tools.gd")
var passed := 0
var failed := 0
var events := 0

class TestScreen extends Control:
	var battle: BattleState
	func _refresh_all() -> void:
		pass


func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error(message)


func encoded(b: BattleState) -> PackedByteArray:
	var state := {}
	for field in SaveManager.STATE_FIELDS:
		state[field] = GameState.get(field)
	return var_to_bytes(SaveCodec.new().pack({"state": state, "battle": b}))


func _ready() -> void:
	DebugCommands.install()
	var ex := Expedition.start(37)
	GameState.add_relic("slab")
	GameState.bind_relic("slab", GameState.deck[0].id())
	var enemy: EnemyData = Database.enemies.values()[0]
	var b := BattleState.new(Database.rules.duplicate())
	b.start(GameState.make_battle_deck(), [enemy], 19)
	var screen := TestScreen.new()
	screen.battle = b
	add_child(screen)
	Router.current = screen
	EventBus.log_message.connect(func(_text): events += 1)
	EventBus.deck_changed.connect(func(): events += 1)
	EventBus.turn_ended.connect(func(_turn): events += 1)
	EventBus.damage_dealt.connect(func(_player, _amount): events += 1)
	EventBus.word_played.connect(func(_word, _text): events += 1)
	EventBus.character_played.connect(func(_ch): events += 1)
	var before := encoded(b)
	var deck_ref := GameState.deck
	var rng_ref := GameState.rng
	var uid := CharInstance._next_uid
	var save_path := "user://debug_relic_test.save"
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string("遗物测试存档哨兵")
	file.close()
	var disk_before := FileAccess.get_file_as_bytes(save_path)
	SaveManager.save_path = save_path
	SaveManager.enabled = true
	SaveManager._active = true
	var out := DebugCommands.execute("/relic-test")
	for line in out:
		print(line)
	check(out.size() == 16 and out[0].contains("15/15"), "全部 15 件遗物效果自检通过")
	check(encoded(b) == before, "全量自检不修改冒险、当前战斗和 RNG 状态")
	check(is_same(GameState.deck, deck_ref) and GameState.rng == rng_ref and GameState.expedition == ex, "保留原始对象引用")
	check(CharInstance._next_uid == uid, "不消耗实体 uid")
	check(events == 0 and not EventBus.is_blocking_signals(), "测试事件不泄漏到界面，信号状态恢复")
	check(not SaveManager._queued and SaveManager._active, "不请求或清除自动存档")
	check(FileAccess.get_file_as_bytes(save_path) == disk_before, "磁盘存档原样保留")
	SaveManager.enabled = false
	SaveManager._active = false
	DirAccess.remove_absolute(save_path)
	for id in Relics.DEFS:
		var single := DebugCommands.execute("relic-test " + Relics.name_of(id))
		check(single.size() == 2 and single[0].contains("1/1"), "按中文名单测 " + id)
	check(encoded(b) == before and events == 0, "重复自检仍保持隔离")
	var board_size := Database.rules.board_size
	Database.rules.board_size = 6
	check(DebugCommands.execute("/relic-test all")[0].contains("15/15"), "自检使用固定规则，不受当前调试参数影响")
	check(Database.rules.board_size == 6, "自检不重置当前调试规则")
	Database.rules.board_size = board_size
	EventBus.set_block_signals(true)
	DebugCommands.execute("/relic-test strike")
	check(EventBus.is_blocking_signals(), "保留调用前已阻塞的信号状态")
	EventBus.set_block_signals(false)
	check(DebugCommands.execute("/relic-test unknown")[0].contains("未知遗物"), "未知遗物错误提示")
	check(DebugCommands.execute("/relic-test strike extra")[0].contains("用法"), "多余参数提示")
	check(Tools.status(b).any(func(line): return line.contains("本场实际遗物")), "状态区分持有与本场")
	check(Tools.bind([])[0].contains("用法"), "绑定缺参数提示")
	check(Tools.bind(["nothing", "击"])[0].contains("未知遗物"), "绑定未知遗物提示")
	check(Tools.bind(["strike", "击"])[0].contains("不需要"), "拒绝非绑定类遗物")
	check(Tools.bind(["fertilizer", "击"])[0].contains("尚未拥有"), "拒绝未持有遗物")
	GameState.deck = [CharInstance.new(Database.get_character_by_glyph("击")), CharInstance.new(Database.get_character_by_glyph("击"))]
	GameState.relics = []
	GameState.relic_binds = {}
	DebugCommands.execute("/relic slab")
	DebugCommands.execute("/relic fertilizer")
	check(GameState.relic_binds.size() == 2 and GameState.relic_binds.slab != GameState.relic_binds.fertilizer, "领取时为两件遗物自动选择不同实体")
	var old_bind: int = GameState.relic_binds.slab
	var battle_bind: int = b.relic_binds.slab
	check(Tools.bind(["slab", "#" + str(GameState.relic_binds.fertilizer)])[0].contains("找不到"), "拒绝绑定被占用的指定实体")
	check(GameState.relic_binds.slab == old_bind, "绑定失败保留旧绑定")
	check(Tools.bind(["slab", "#oops"])[0].contains("必须是整数"), "非法 uid 提示")
	var extra := CharInstance.new(Database.get_character_by_glyph("火"))
	GameState.deck.append(extra)
	check(DebugCommands.execute("/relic-bind 压字石 火")[0].contains("下一场"), "支持中文遗物名与字形换绑")
	check(GameState.relic_binds.slab == extra.uid and b.relic_binds.slab == battle_bind, "换绑不重放本场开局效果")
	check(Tools.bind(["slab", "#" + str(extra.uid)])[0].contains("绑定【火】"), "允许指定同一实体幂等绑字")
	check(DebugCommands.execute("/help").any(func(line): return line.contains("/relic-test")), "帮助中显示新命令")
	Router.current = null
	print("[debug_relic_test] PASS=%d FAIL=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
