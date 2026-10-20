extends Control
var checks := 0
var failures := 0
var screen: Control

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames() -> void:
	for i in 4: await get_tree().process_frame

func idle() -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while screen._busy and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.01).timeout
	check(not screen._busy, "play finishes and unlocks")

func select_pair(row: int) -> void:
	screen._board_view._on_tile_pressed(Vector2i(0, row))
	screen._board_view._on_tile_pressed(Vector2i(1, row))

func _ready() -> void:
	get_window().size = Vector2i(1280,720)
	for reduced in [true, false]:
		for glyph in ["右", "左"]:
			GameState.start_new_run("v03")
			Settings.reduced_motion = reduced
			Settings.drag_release_play = false
			screen = load("res://src/screens/battle_screen.gd").new()
			add_child(screen)
			screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await frames()
			await idle()
			var b: BattleState = screen.battle
			b.enemies[0].hp = 999
			b.enemies[0].max_hp = 999
			b.bag.clear(); b.discard.clear()
			for i in b.board.cells.size(): b.board.cells[i] = CharInstance.new(Database.get_character_by_glyph("防"))
			for row in [0,1]:
				b.board.set_cell(0,row,CharInstance.new(Database.get_character_by_glyph(glyph)))
				b.board.set_cell(1,row,CharInstance.new(Database.get_character_by_glyph("击")))
			if glyph == "右":
				# Extra-use letters stay on the same cells, exercising consecutive uses of identical entities.
				b.board.get_xy(Vector2i(0,0)).temporary_uses = 1
				b.board.get_xy(Vector2i(1,0)).temporary_uses = 1
			var first_marker := b.board.get_xy(Vector2i(0,3))
			var second_marker := b.board.get_xy(Vector2i(0,2))
			screen._refresh_all()
			select_pair(0)
			screen._on_primary()
			check(screen._board_view.pick_mode == "row" and screen._row_choice.is_empty(), "first directional strike requires explicit row selection")
			screen._board_view._on_tile_pressed(Vector2i(0,3))
			check(not screen._row_choice.is_empty() and int(screen._ready_action.target.row) == 3, "row click creates a choice for the current play")
			screen._on_primary()
			await idle()
			check(screen._row_choice.is_empty() and screen._ready_action.is_empty(), "resolved play discards row choice and ready action")
			var dest := 1 if glyph == "右" else 3
			check(b.board.get_xy(Vector2i(dest,3)) == first_marker, "first strike moves the selected row")
			select_pair(0 if glyph == "右" else 1)
			var hp: int = b.enemies[0].hp
			screen._on_primary()
			check(screen._board_view.pick_mode == "row" and screen._board_view.pick_anchor == Vector2i(-1,-1) and screen._ready_action.is_empty() and screen._confirm_btn.disabled, "second same-name strike starts with no selected row")
			screen._on_primary()
			check(b.enemies[0].hp == hp and b.board.get_xy(Vector2i(0,2)) == second_marker, "confirm without a new row does not deal damage or move any row")
			screen._board_view._on_tile_pressed(Vector2i(0,2))
			screen._on_primary()
			await idle()
			check(b.board.get_xy(Vector2i(dest,2)) == second_marker and b.board.get_xy(Vector2i(dest,3)) == first_marker, "second strike uses a newly selected different row")
			# Even a stale target dictionary supplied by a previous UI action cannot bypass row choice.
			b.board.set_cell(0,0,CharInstance.new(Database.get_character_by_glyph(glyph)))
			b.board.set_cell(1,0,CharInstance.new(Database.get_character_by_glyph("击")))
			screen._refresh_all()
			hp = b.enemies[0].hp
			screen._on_commit([Vector2i(0,0),Vector2i(1,0)], {"row":2})
			check(screen._board_view.pick_mode == "row" and screen._ready_action.is_empty() and b.enemies[0].hp == hp, "stale row payload cannot execute a fresh strike")
			screen._board_view._on_tile_pressed(Vector2i(0,3))
			# Replaced entities at the same coordinates are a fresh play, too.
			b.board.set_cell(0,0,CharInstance.new(Database.get_character_by_glyph(glyph)))
			screen._on_primary()
			check(screen._board_view.pick_mode == "row" and screen._ready_action.is_empty() and b.enemies[0].hp == hp, "row choice is bound to source entities, not reused coordinates")
			screen._on_clear_cancel()
			check(screen._row_choice.is_empty(), "cancel discards row choice")
			screen.free()
			await frames()
	print("[repeated_row_target_test] PASS=%d FAIL=%d" % [checks-failures, failures])
	get_tree().quit(1 if failures else 0)
