extends Control
const EventScreen := preload("res://src/screens/event_screen.gd")
var _screen: Control
var _pass := 0
var _fail := 0
var _capture := false


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_run.call_deferred()


func _ok(condition: bool, description: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ ", description)
	else:
		_fail += 1
		push_error(description)


func _frames(count := 8) -> void:
	for index in count: await get_tree().process_frame


func _seed_for(index: int) -> int:
	var rng := RandomNumberGenerator.new()
	for seed_value in 100:
		rng.seed = seed_value
		if rng.randi_range(0, EventScreen.EVENTS.size() - 1) == index: return seed_value
	return 0


func _open(index: int) -> void:
	GameState.start_new_run("v03")
	GameState.rng.seed = _seed_for(index)
	var expected := RandomNumberGenerator.new()
	expected.seed = _seed_for(index)
	expected.randi_range(0, EventScreen.EVENTS.size() - 1)
	Router.goto("res://src/screens/event_screen.gd")
	await _frames()
	_screen = Router.current
	_ok(_screen._event.id == EventScreen.EVENTS[index].id and GameState.rng.state == expected.state, "事件抽取仍消耗一次随机数，插图加载不改变结果")


func _shot(name: String) -> void:
	if not _capture: return
	await _frames(4)
	RenderingServer.force_draw(false)
	_ok(get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % name) == OK, "保存实际渲染 " + name)


func _check_layout() -> void:
	var scale := float(get_window().size.y) / _screen.size.y
	_ok(_screen._buttons.all(func(button): return button.size.y * scale >= 47.9), "所有选择保留至少 48 屏幕像素点击高度")
	_ok(not _screen._art.get_global_rect().intersects(_screen._copy.get_global_rect()), "插图不与正文或选择按钮相交")
	_ok(_screen._choice_labels.all(func(label): return label.size.x > 0 and label.get_global_rect().end.x <= _screen.get_global_rect().end.x), "完整选项文案没有越出窗口右边缘")
	if not _screen._vertical:
		_ok(_screen._buttons[-1].get_global_rect().end.y <= _screen.get_global_rect().end.y, "横屏三个选项直接可见，不被插图挤出屏幕")


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames(12)
	Router.host = self
	if _capture:
		var stage := StudyStage.new()
		add_child(stage)
		Router.study_stage = stage
	for index in EventScreen.EVENTS.size():
		await _open(index)
		var data: Dictionary = EventScreen.EVENTS[index]
		_ok(_screen._art.texture != null and _screen._art.texture.resource_path == data.illustration, data.title + " 加载自己的插图")
		var image: Image = _screen._art.texture.get_image()
		_ok(image.get_pixel(0, 0).a < 0.01 and image.get_width() >= 1024, data.title + " 保留原始透明边缘与高清尺寸")
		_ok(_screen._art.mouse_filter == Control.MOUSE_FILTER_IGNORE and _screen._art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "插图保持完整比例，也不阻挡点击")
		_ok(_screen._choice_labels.size() == data.options.size() and _screen._choice_labels[0].text == data.options[0].text, "事件取舍沿用完整原始规则文案")
		_check_layout()
		await _shot("event-%s-desktop" % data.id)
	get_window().size = Vector2i(844, 390)
	await _frames(12)
	for index in EventScreen.EVENTS.size():
		await _open(index)
		_check_layout()
		await _shot("event-%s-phone" % _screen._event.id)
	get_window().size = Vector2i(540, 900)
	await _frames(12)
	await _open(2)
	_ok(_screen._vertical and _screen._copy.position.y > _screen._art.position.y, "窄竖屏改为插图在上、选择在下")
	_check_layout()
	_ok(_screen._page.get_global_rect().end.y >= _screen._buttons[-1].get_global_rect().end.y, "竖屏滚动内容覆盖最后一个选择")
	await _shot("event-bookshop-portrait")
	# 真实选项收益，防止表现改动重复执行或改变推进节点。
	await _open(0)
	var gold: int = GameState.gold
	var node_index: int = GameState.node_index
	_screen._choose(1)
	_screen._choose(1)
	_ok(GameState.gold == gold + 18 and GameState.node_index == node_index + 1, "墨池金币选项只结算一次，并推进一个节点")
	await _open(0)
	var hp: int = GameState.player_hp
	var deck: int = GameState.deck_size()
	_screen._choose(0)
	_ok(GameState.player_hp == hp - 8 and GameState.deck_size() == deck + 1, "墨池取字仍扣 8 生命并获得一枚字")
	await _open(1)
	hp = GameState.player_hp
	gold = GameState.gold
	_screen._choose(1)
	_ok(GameState.player_hp == hp - 5 and GameState.gold == gold + 25, "断碑敲角仍扣 5 生命并获得 25 金币")
	await _open(1)
	deck = GameState.deck_size()
	_screen._choose(0)
	var added: CharInstance = GameState.deck[-1]
	_ok(GameState.deck_size() == deck + 1 and added.data.rarity >= 2, "断碑残字仍获得符合规则的稀有字")
	await _open(2)
	GameState.player_hp = 25
	_screen._choose(1)
	_ok(GameState.player_hp == 43, "书肆诵读仍回复 18 气血")
	await _open(2)
	node_index = GameState.node_index
	deck = GameState.deck_size()
	_screen._choose(0)
	await _frames()
	var picker: CollectionOverlay
	for child in _screen.get_children():
		if child is CollectionOverlay: picker = child
	_ok(picker != null and _screen._buttons.all(func(button): return button.disabled), "撕页选字期间禁用其他事件选项")
	picker._close()
	await _frames()
	_ok(not _screen._done and _screen._buttons.all(func(button): return not button.disabled) and GameState.deck_size() == deck and GameState.node_index == node_index, "取消撕页恢复选择，不消费字或推进节点")
	_screen._choose(0)
	await _frames()
	for child in _screen.get_children():
		if child is CollectionOverlay: picker = child
	var character: CharacterData = Database.get_character(GameState.deck[0].data.id)
	picker._on_card_clicked(character)
	_screen._on_removed(character)
	_ok(GameState.deck_size() == deck - 1 and GameState.node_index == node_index + 1, "撕页只删除一枚字，重复回调不重复推进")
	await _frames()
	_ok(Router.current_path.ends_with("map_screen.gd"), "事件选择完成后返回地图")
	print("[event_art_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
