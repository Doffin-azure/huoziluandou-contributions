extends "res://tests/monster_regression.gd"

func cast(b: BattleState, text: String, target: Dictionary = {}) -> Dictionary:
	var path: Array = []
	for x in text.length():
		put(b, text[x], x)
		path.append(Vector2i(x, 0))
	return b.try_play(path, target)

func clear_board(b: BattleState) -> void:
	for i in b.board.cells.size(): b.board.cells[i] = null

func _ready() -> void:
	var saved := GameState.deck.duplicate()
	var b := make("paper_shell")
	var card := CharInstance.new(Database.get_character_by_glyph("击"))
	var other := CharInstance.new(card.data)
	GameState.deck.assign([card, other])
	var before := GameState.gold
	var r := cast(b, "投资", {"gild_uid": -1})
	check(not r.ok and GameState.gold == before and b.board.fill_count() == 2, "无效目标不吞字、不扣费")
	GameState.gold = 2
	r = cast(b, "投资", {"gild_uid": card.uid})
	check(not r.ok and not card.gilded and GameState.gold == 2, "金币不足不吞字、不镀金")
	GameState.gold = 20
	r = cast(b, "投资", {"gild_uid": card.uid})
	check(r.ok and GameState.gold == 17 and card.gilded and not other.gilded, "花3金币只强化指定实体")
	r = cast(b, "精金", {"gild_uid": card.uid})
	check(not r.ok and GameState.gold == 17, "已镀金实体不可重复选择")
	clear_board(b)
	b.enemies[0].hp = 1000
	b.enemies[0].max_hp = 1000
	b.board.set_cell(0, 0, card)
	card.temporary_uses = 1
	b.try_play([Vector2i.ZERO])
	check(GameState.gold == 18 and b.board.get_cell(0, 0) == card, "使用复制层的单字同样+1金币")
	put(b, "破", 1)
	b.try_play([Vector2i.ZERO, Vector2i.RIGHT])
	check(GameState.gold == 19, "组词每个镀金实体只结算1次")
	b.board.set_cell(0, 0, card)
	card.word_only = true
	b.try_play([Vector2i.ZERO])
	check(GameState.gold == 19, "只弃字不触发镀金")
	card.word_only = false
	clear_board(b)
	card.fusion.append("破")
	b.board.set_cell(0, 0, card)
	b.try_play([Vector2i.ZERO])
	check(GameState.gold == 20, "融合单格即使贡献多个字形也只+1金币")
	card.fusion.clear()
	var next := make("paper_shell")
	next.start(GameState.make_battle_deck(), [Database.get_enemy("paper_shell")], 123)
	check(card.gilded and not other.gilded, "进入下一战镀金仍绑定同一实体")
	var settled := GameState.gold
	GameState.settle_victory_economy()
	GameState.settle_victory_economy()
	check(GameState.gold == settled, "胜利没有投资返还与复利增长")
	b = make("paper_shell")
	before = GameState.gold
	cast(b, "资金")
	b.begin_player_turn(false)
	check(GameState.gold == before + 5, "资金直接增加普通金币，过回合不清空")
	check(EffectUtil.pay(b, 3) and GameState.gold == before + 2, "费用直接支付普通金币")
	for word in Database.words.values():
		for eff in word.effects:
			check(not eff.handler in ["temp_funds", "invest_equity", "equity_interest", "compound_equity", "reinvest", "permanent_gold_growth", "alchemy", "pure_gold"], "生效词库不含旧经济handler：" + word.word)
	var encounter := MapNodeData.new()
	encounter.enemies.append(Database.get_enemy("proof_boss"))
	GameState.start_new_run("v03")
	get_viewport().size = Vector2i(1440, 900)
	var screen = load("res://src/screens/battle_screen.gd").new()
	screen.setup({"node": encounter, "seed": 7})
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	for i in 4: await get_tree().process_frame
	var tile := CharInstance.new(Database.get_character_by_glyph("连"))
	tile.gilded = true
	tile.pollutions.append("replicate")
	tile.temporary_uses = 2
	screen.battle.board.set_cell(0, 0, tile)
	screen._board_view.rebuild()
	check(not screen._bubble.frame_details.visible, "未点击时不显示字框效果")
	screen._board_view._on_tile_hovered(Vector2i.ZERO)
	check(not screen._bubble.frame_details.visible, "悬停特殊字不显示说明")
	screen._board_view._on_tile_pressed(Vector2i.ZERO)
	check(screen._bubble.frame_details.text.contains("镀金") and screen._bubble.frame_details.text.contains("蔓生") and screen._bubble.frame_details.text.contains("额外使用"), "左侧同时解释同一字的镀金、污染、叠层")
	check(screen._gold_strip.entries.size() == 1, "钱包只有普通金币")
	var view: TileView = screen._board_view.tiles[0]
	view.set_selected(false)
	check(view._sel_border.visible and view._sel_border.get_theme_stylebox("panel").border_color == Palette.GOLD_DK, "2D镀金呈金框")
	view.set_selected(true, 0)
	check(view._sel_border.get_theme_stylebox("panel").border_color == Palette.VERMILION and view._order.visible, "选中呈红框与顺序号")
	view.set_selected(false)
	var pres = screen._board_view._presentation
	pres._sync_tiles()
	check(pres.actors[0].border.visible and pres.actors[0].border.get_child(0).material_override == pres._gold, "3D镀金金框与2D一致")
	view.set_selected(true, 0)
	pres._sync_tiles()
	check(pres.actors[0].border.get_child(0).material_override == pres._red, "3D选中红框优先，左侧仍说明镀金状态")
	# Actual picker: cancellation is inert, chosen UID gilds only the chosen duplicate.
	clear_board(screen.battle)
	put(screen.battle, "精", 0)
	put(screen.battle, "金", 1)
	before = GameState.gold
	screen._open_gild_picker([Vector2i.ZERO, Vector2i.RIGHT])
	var picker: ChoiceOverlay
	for child in screen.get_children():
		if child is ChoiceOverlay: picker = child
	check(picker != null and screen._modal_count == 1, "镀金打开实体UID选字器")
	picker.chose.emit(GameState.deck.size())
	picker.queue_free()
	for i in 3: await get_tree().process_frame
	check(GameState.gold == before and not GameState.deck[0].gilded and screen.battle.board.fill_count() == 2, "取消选字保留金币和施词字")
	var original_children: int = screen._bubble._column.get_child_count()
	for i in 10: screen._bubble.set_idle("操作提示")
	check(screen._bubble._column.get_child_count() == original_children, "反复更新出词预览不累积说明控件")
	screen._board_view.clear_selection()
	check(not screen._bubble.frame_details.visible and screen._bubble.frame_details.text.is_empty(), "清除选择同时收起说明")
	clear_board(screen.battle)
	screen.battle.board.set_cell(0, 0, tile)
	var plain := put(screen.battle, "击", 1)
	var gold_only := put(screen.battle, "击", 2)
	gold_only.gilded = true
	screen._board_view.rebuild()
	screen._board_view._on_tile_pressed(Vector2i.ZERO)
	screen._board_view._dragging = false
	var clicked_details: String = screen._bubble.frame_details.text
	screen._board_view._on_tile_hovered(Vector2i(2, 0))
	check(screen._bubble.frame_details.text == clicked_details, "悬停其他字不会替换已点击字的说明")
	screen._board_view._on_tile_pressed(Vector2i(2, 0))
	screen._board_view._dragging = false
	check(screen._bubble.frame_details.visible and screen._bubble.frame_details.text.contains("镀金") and not screen._bubble.frame_details.text.contains("蔓生") and not screen._bubble.frame_details.text.contains("额外使用"), "点击仅镀金的字只显示镀金效果")
	screen._board_view._on_tile_pressed(Vector2i.RIGHT)
	screen._board_view._dragging = false
	check(not screen._bubble.frame_details.visible and screen._bubble.frame_details.text.is_empty(), "点击普通字不显示任何额外字框说明")
	check(not screen._bubble._column.get_children().any(func(c): return c is Label and "9种" in c.text), "左侧没有全部类型图例")
	if "--shot" in OS.get_cmdline_user_args():
		screen.battle.board.set_cell(0, 0, tile)
		screen._board_view.rebuild()
		screen._inspect_tile(Vector2i.ZERO)
		for i in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/private/tmp/huozi-economy-ui.png")
	screen.queue_free()
	GameState.deck = saved
	print("[economy_gild_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
