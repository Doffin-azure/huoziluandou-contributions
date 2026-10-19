extends Node
## 庭院事件抽屉回归：目录选项进入真实 UI，删字阶段保留事件上下文，完成后回到地图。
const RUN = preload("res://src/expedition/room_run_state.gd")
const EFFECTS = preload("res://src/core/event_effects.gd")
var failures: Array = []
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var run = RUN.new()
	run.reset({"seed": 17})
	run.autosave = false
	var event_id := ""
	for id: String in run.graph.rooms:
		if run.graph.rooms[id].kind == "event":
			event_id = id
			break
	check(not event_id.is_empty(), "生成的事件房")
	run.position = run.layout.rooms[event_id].stand_cell
	run.visited_rooms[event_id] = true
	run._arrive(event_id)
	check(run.phase == "event", "抵达事件房进入事件阶段")
	check((run.event_data.get("acts", []) as Array).has(GameState.act_index), "抽取的事件属于当前幕")
	check(run.seen_events.has(str(run.event_data.get("id", ""))), "抽取后记入已出现事件")
	Router.goto(RUN.MAP_SCREEN)
	await frames(6)
	var screen: Control = Router.current
	# 地图装配可能跨帧完成；装配期间 refresh() 会暂时不下发抽屉内容。
	for _i in 180:
		if screen.map_view != null and not screen.map_view._building: break
		await frames(1)
	await frames(8)
	var texts := _texts(screen.choices_box)
	check(texts.has(str(run.event_data.get("title", ""))), "抽屉显示事件标题")
	check(texts.has(str(run.event_data.get("body", ""))), "抽屉显示事件正文")
	var buttons := _buttons(screen.choices_box)
	check(buttons.size() == 3, "事件固定渲染三个选项")
	var primary: Array = run.legal_actions().filter(func(action): return bool(action.get("primary", false)))
	check(primary.size() == 1, "合法动作保留主选项标记")

	# 强制切到删字事件，验证 event_choose 仍保留事件上下文。
	run.event_data = EFFECTS.get_event("old_bookshop").duplicate(true)
	screen.refresh()
	await frames(3)
	buttons = _buttons(screen.choices_box)
	check(buttons[0].text.begins_with("撕下一页"), "删字选项进入抽屉")
	buttons[0].pressed.emit()
	await frames(4)
	check(run.phase == "event_choose", "删字选项进入待选阶段")
	texts = _texts(screen.choices_box)
	check(texts.any(func(text): return str(text).contains("旧书肆")), "待选阶段保留事件标题")
	check(texts.any(func(text): return str(text).contains("还需 1 枚")), "待选阶段显示剩余删字数")
	var observed: Dictionary = run.observe()
	check(str(observed.get("event", {}).get("id", "")) == "old_bookshop", "observe 在待选阶段保留事件 ID")
	check(int(observed.get("event", {}).get("pending_removal", {}).get("remaining", 0)) == 1, "observe 暴露剩余删字数")
	buttons = _buttons(screen.choices_box)
	check(not buttons.is_empty(), "待选阶段渲染可选字")
	var deck_before: int = GameState.deck_size()
	buttons[0].pressed.emit()
	await frames(4)
	check(run.phase == "map" and run.resolved.has(event_id), "删字完成后回到地图并标记房间已解决")
	check(GameState.deck_size() == deck_before - 1, "删字只删除一枚")
	print("[RoomEventUI] checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func _texts(box: Control) -> Array:
	var out: Array = []
	for child in box.get_children():
		if child is Label:
			out.append(child.text)
	return out


func _buttons(box: Control) -> Array:
	var out: Array = []
	for child in box.get_children():
		if child is Button:
			out.append(child)
	return out


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame
