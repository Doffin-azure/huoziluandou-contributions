extends ScreenBase
## Horizontal branching scroll, using the saved event/shop/battle controller.
const RUN = preload("res://src/expedition/room_run_state.gd")
const VIEW = preload("res://src/map/node_route_view.gd")
const LABELS := {"start":"起点", "battle":"战斗", "elite":"精英", "boss":"首领", "event":"奇遇", "shop":"字肆", "treasure":"宝藏", "rest":"休息"}
var run: RefCounted
var loaded_act := 0
var map_view: Control
var _stats: Label
var _act_title: Label
var _progress: Label
var _detail_title: Label
var _detail: Label
var _action: Button
var _plan_button: Button
var _selected := ""
var _routing := false
var _receipt_open := false


func build(root: Control) -> void:
	run = GameState.room_run
	if run==null: run = RUN.start()
	run.use_node_map()
	loaded_act = GameState.act_index
	var page := JourneyStyle.page(root)
	var header := Ink.hbox(18)
	var act: ActData = Database.get_act(GameState.act_index)
	_act_title = JourneyStyle.label(act.title if act!=null else "炼字狱", "Heading")
	header.add_child(_act_title)
	header.add_child(Ink.expander())
	_stats = JourneyStyle.label("", "Stat"); header.add_child(_stats)
	header.add_child(_button("字袋",_open_deck))
	header.add_child(_button("菜单",func(): PauseMenu.open()))
	page.add_child(header)
	var strip := Ink.hbox(12)
	_progress = JourneyStyle.label("", "Muted")
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL; strip.add_child(_progress)
	strip.add_child(_button("当前",func(): map_view.focus_current()))
	strip.add_child(_button("全图",func(): map_view.show_overview()))
	strip.add_child(_button("清除预选",_clear_plan))
	page.add_child(strip)
	map_view = VIEW.new(); map_view.run = run
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.node_selected.connect(_select_node); page.add_child(map_view)
	var legend := HFlowContainer.new(); legend.add_theme_constant_override("h_separation",20)
	for entry in [["战 · 战斗",JourneyStyle.TEXT],["精 · 精英",JourneyStyle.RED],["？ · 奇遇",JourneyStyle.TEXT],["商 · 字肆",JourneyStyle.GOLD],["藏 · 宝藏",JourneyStyle.GOLD],["息 · 休息",JourneyStyle.TEXT],["狱 · 首领",JourneyStyle.RED]]:
		legend.add_child(JourneyStyle.label(entry[0],"Muted",entry[1]))
	page.add_child(legend)
	var panel := Ink.panel("PanelInset")
	var row := Ink.hbox(22); panel.add_child(row)
	var text := Ink.vbox(4); text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title = JourneyStyle.label("","Subheading",JourneyStyle.GOLD)
	_detail = JourneyStyle.label("","Muted",JourneyStyle.TEXT)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.y = 42*JourneyStyle.touch_scale(self)
	text.add_child(_detail_title); text.add_child(_detail); row.add_child(text)
	var actions := Ink.vbox(6)
	_action = _button("选择下一站",_confirm_selected,true)
	_plan_button = _button("预选此节点",_plan_selected)
	actions.add_child(_action); actions.add_child(_plan_button); row.add_child(actions)
	page.add_child(panel)
	EventBus.gold_changed.connect(_on_gold); EventBus.hp_changed.connect(_on_hp)
	_selected = run.current_room
	refresh()


func _button(caption: String, callback: Callable, primary := false) -> Button:
	var button := JourneyStyle.button(caption,callback,primary)
	button.custom_minimum_size.y = 48*JourneyStyle.touch_scale(self)
	return button


func suspend_session() -> void:
	hide(); process_mode = Node.PROCESS_MODE_DISABLED


func resume_session() -> void:
	show(); process_mode = Node.PROCESS_MODE_INHERIT; _routing = false
	if loaded_act!=GameState.act_index:
		loaded_act = GameState.act_index; _selected = run.current_room
		map_view.show_overview()
	refresh()


func refresh() -> void:
	if _routing: return
	_update_stats()
	if run.phase=="battle": return
	var node_screen: String = {"reward":"reward_screen.gd", "event":"event_screen.gd", "event_choose":"event_screen.gd",
		"event_board":"event_board_screen.gd", "shop":"shop_screen.gd", "shop_choose":"shop_screen.gd",
		"rest":"rest_screen.gd", "rest_choose":"rest_screen.gd"}.get(run.phase,"")
	if not node_screen.is_empty():
		_routing = true
		goto.call_deferred("res://src/screens/"+node_screen,{"room_run":true,"node":run.node})
		return
	if not run.graph.rooms.has(_selected): _selected = run.current_room
	map_view.selected = _selected; map_view.refresh()
	_progress.text = "已行 %d / %d 站 · %d 个候选节点   /   向右择路，点击查看，拖动浏览" % [maxi(0,run.visited_rooms.size()-1),int(run.layout.rooms[run.graph.boss].column)+1,run.graph.rooms.size()]
	if not run.planned_route.is_empty(): _progress.text = "预选 %d 站 · 本幕 %d 个候选节点 · 预选可随时修改，前进后不能回头" % [run.planned_route.size(),run.graph.rooms.size()]
	_update_detail()
	if run.phase=="treasure" and not _receipt_open: _treasure_receipt.call_deferred()


func _on_gold(_amount: int) -> void: _update_stats()
func _on_hp(_hp: int, _max_hp: int) -> void: _update_stats()


func _update_stats() -> void:
	if is_instance_valid(_stats): _stats.text = "气血 %d / %d    金币 %d" % [GameState.player_hp,GameState.player_max_hp,GameState.gold]
	if is_instance_valid(_act_title):
		var act := Database.get_act(GameState.act_index)
		_act_title.text = act.title if act!=null else "炼字狱"


func _select_node(id: String) -> void:
	_selected = id; map_view.selected = id; map_view.queue_redraw(); _update_detail()


func _update_detail() -> void:
	var spec: Dictionary = run.graph.rooms[_selected]
	_detail_title.text = "%s · %s" % [run.layout.rooms[_selected].name,map_view._status(_selected)]
	_detail.text = _description(_selected)
	_action.disabled = false
	if run.phase=="encounter": _action.text = "进入战斗"
	elif run.phase=="act_end": _action.text = "完成此程" if GameState.act_index>=3 else "进入下一幕"
	elif run.phase in ["victory","defeat"]: _action.text = "返回标题"
	elif run.phase!="map": _action.text = "处理当前节点"; _action.disabled = true
	else:
		_action.text = "前往 · "+LABELS[spec.kind]
		_action.disabled = not run.next_rooms().has(_selected)
		if _action.disabled and not run.planned_route.is_empty():
			_action.text = "前往预选下一站"; _action.disabled = false
	_plan_button.disabled = run.phase!="map" or not (run.plan_choices().has(_selected) or run.planned_route.has(_selected) or run.next_rooms().has(_selected))
	_plan_button.text = "预选到此" if not run.planned_route.has(_selected) else "保留预选到此"


func _description(id: String) -> String:
	var kind: String = run.graph.rooms[id].kind
	var result: String = {"start":"沿连线选择下一站。整幕节点类型已展开；预选路线可随时修改，实际前进后不能回头。",
		"event":"途中奇遇：阅读故事并做出取舍，可能获得活字、金币或遗物，也可能付出代价。",
		"shop":"字肆：购买活字、删字、拓印、治疗与遗物。刷新货架需 5 金币。",
		"rest":"休息：回复气血、删去一枚字，或为一枚字镀金；只能选择一次。",
		"treasure":"宝藏：获得一件尚未拥有的遗物；普通遗物取尽后改为 30 金币。"}.get(kind,"")
	if kind in ["battle","elite","boss"]:
		var encounter: MapNodeData = run.battle_node(id)
		var enemy: EnemyData = encounter.enemies[0]
		var prize := "战后择字三选一，跳过获得 16 金币。"
		if kind=="elite": prize += " 另获一件遗物。"
		if kind=="boss" and GameState.act_index<3: prize += " 回血 30%，遗物二选一。"
		result = "%s · 气血 %d　%s" % [enemy.name,enemy.max_hp,prize]
	if run.phase=="act_end": return "本幕已完成。保留字袋、字匣、版面与遗物，继续下一幕。"
	if run.phase in ["victory","defeat"]: return "三幕已尽，炼字破狱。" if run.phase=="victory" else "此程止步，可以返回标题开始新的冒险。"
	var following: Array = run.graph.rooms[id].next.map(func(target):return LABELS[run.graph.rooms[target].kind])
	var unique: Array = []
	for label: String in following:
		if not unique.has(label): unique.append(label)
	if not unique.is_empty(): result += "\n后续："+" / ".join(unique)
	return result


func _confirm_selected() -> void:
	if _routing: return
	if run.phase=="encounter": _start_battle(); return
	if run.phase=="act_end":
		run.apply({"type":"next_act"}); loaded_act = GameState.act_index; _selected = run.current_room
		map_view.show_overview(); refresh(); return
	if run.phase in ["victory","defeat"]: goto("res://src/screens/title_screen.gd"); return
	if run.phase!="map": return
	var target: String = _selected if run.next_rooms().has(_selected) else (run.planned_route[0] if not run.planned_route.is_empty() else "")
	if target.is_empty(): return
	var result: Dictionary = run.apply({"type":"enter_room","room":target})
	_selected = run.current_room
	if not result.get("ok",false): _detail.text = str(result.get("reason","无法前往")); return
	if run.phase=="encounter": _start_battle()
	else: refresh()


func _start_battle() -> void:
	if not run.begin_live_battle(): return
	_routing = true
	goto("res://src/screens/battle_screen.gd",{"room_run":true,"node":run.node,"seed":run.battle_seed()})


func _plan_selected() -> void:
	var result: Dictionary = run.plan_room(_selected)
	if result.get("ok",false): refresh()


func _clear_plan() -> void:
	run.apply({"type":"clear_plan"}); refresh()


func _treasure_receipt() -> void:
	if run.phase!="treasure" or _receipt_open: return
	_receipt_open = true
	var receipt: Dictionary = run.contents[run.current_room].get("treasure",{})
	var id := str(receipt.get("relic",""))
	var overlay := ChoiceOverlay.new()
	overlay.setup({"title":"宝藏 · 碑间遗器", "body":("获得遗物「%s」\n%s" % [Relics.name_of(id),Relics.desc_of(id)]) if not id.is_empty() else "普通遗物已取尽，获得 30 金币。",
		"options":[{"text":"收下，继续前行","primary":true}]})
	overlay.chose.connect(func(_index):
		if not id.is_empty():
			RelicRewardFlow.bind_owned(self,id,func(_id):
				run.apply({"type":"treasure_ack"}); _receipt_open = false; refresh())
		else:
			run.apply({"type":"treasure_ack"}); _receipt_open = false; refresh())
	add_child(overlay)


func _open_deck() -> void:
	var counts := GameState.glyph_counts()
	var chars: Array = []
	for glyph: String in counts:
		var character := Database.get_character_by_glyph(glyph)
		if character!=null: chars.append(character)
	var overlay := CollectionOverlay.new()
	overlay.setup({"title":"字袋", "subtitle":"%d 枚实体字" % GameState.deck_size(), "characters":chars, "counts":counts})
	add_child(overlay)
