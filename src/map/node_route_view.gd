extends Control
## Screen-space route scroll: every future stop and connection stays visible.
signal node_selected(id: String)
const GLYPHS := {"start":"入", "battle":"战", "elite":"精", "event":"？", "shop":"商", "treasure":"藏", "rest":"息", "boss":"狱"}
const LABELS := {"start":"起点", "battle":"战斗", "elite":"精英", "event":"奇遇", "shop":"字肆", "treasure":"宝藏", "rest":"休息", "boss":"首领"}
var run: RefCounted
var selected := ""
var points := {}
var _offset := 0.0
var _overview := true
var _unit := 1.0
var _pitch := 100.0
var _span := 0.0
var _down := Vector2.ZERO
var _pressed := false
var _dragged := false
var _pointer := -1
var _hover := ""


func _ready() -> void:
	clip_contents = true
	custom_minimum_size.y = 220
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_layout)
	mouse_exited.connect(func(): _hover = ""; queue_redraw())
	_layout()


func refresh() -> void:
	_layout()


func show_overview() -> void:
	_overview = true; _offset = 0
	_layout()


func focus_current() -> void:
	_overview = false
	_layout()
	if points.has(run.current_room):
		_offset += points[run.current_room].x - size.x * .24
		_clamp_offset(); _layout()


func _layout() -> void:
	if run == null or size.x < 10: return
	_unit = JourneyStyle.touch_scale(self)
	var last := 0
	for data: Dictionary in run.layout.rooms.values(): last = maxi(last, int(data.column) + 1)
	var margin := 54.0 * _unit
	_pitch = maxf(68 * _unit, (size.x - margin * 2) / maxf(1, last)) if _overview else 116 * _unit
	_span = last * _pitch + margin * 2
	_clamp_offset()
	points.clear()
	var compact := _unit>1.1
	var top := (40.0 if compact else 64.0)*_unit
	# Reserve a clear corner for the floating actions, without a separate footer.
	var bottom := 104.0*_unit
	var height := maxf(120 * _unit, size.y - top - bottom)
	for id: String in run.graph.rooms:
		var data: Dictionary = run.layout.rooms[id]
		var spec: Dictionary = run.graph.rooms[id]
		var lane: float = clampf(float(data.lane), 0, 3)
		var jitter: float = float(spec.get("jitter",0)) if id not in [run.graph.start,run.graph.boss] else 0
		if compact: jitter *= .4
		points[id] = Vector2(margin + (data.column + 1) * _pitch - _offset, top + (lane + jitter) / 3 * height)
	queue_redraw()


func _clamp_offset() -> void:
	_offset = clampf(_offset, 0, maxf(0, _span - size.x))


func _hit(at: Vector2) -> String:
	var best := ""
	var nearest := 35.0 * _unit
	for id: String in points:
		var distance := at.distance_to(points[id])
		if distance < nearest: best = id; nearest = distance
	return best


func _get_tooltip(at_position: Vector2) -> String:
	var id := _hit(at_position)
	if id.is_empty(): return ""
	var status := _status(id)
	return LABELS[run.graph.rooms[id].kind]+(" · "+status if not status.is_empty() else "")


func _status(id: String) -> String:
	if id==run.current_room: return "当前"
	if run.visited_rooms.has(id): return "已过"
	if run.sealed.has(id): return "已放弃"
	if run.next_rooms().has(id): return "可前往"
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			_offset += (-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1) * 100 * _unit
			_clamp_offset(); _layout(); accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: _down = event.position; _pressed = true; _dragged = false
			else:
				if _pressed and not _dragged:
					var id := _hit(event.position)
					if not id.is_empty(): node_selected.emit(id)
				_pressed = false
			accept_event()
	elif event is InputEventMouseMotion:
		if _pressed:
			if event.position.distance_to(_down)>8*_unit: _dragged = true
			if _dragged: _offset -= event.relative.x; _clamp_offset(); _layout()
		else:
			var id := _hit(event.position)
			if id!=_hover: _hover = id; queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed and _pointer<0:
			_pointer = event.index; _down = event.position; _dragged = false
		elif not event.pressed and event.index==_pointer:
			if not _dragged:
				var id := _hit(event.position)
				if not id.is_empty(): node_selected.emit(id)
			_pointer = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index==_pointer:
		if event.position.distance_to(_down)>8*_unit: _dragged = true
		if _dragged: _offset -= event.relative.x; _clamp_offset(); _layout()
		accept_event()
	elif event is InputEventPanGesture:
		_offset += event.delta.x * 36 * _unit
		_clamp_offset(); _layout(); accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		_offset += 100 * _unit * (1 if event.is_action_pressed("ui_right") else -1)
		_clamp_offset(); _layout(); accept_event()
	elif event.is_action_pressed("ui_accept") and not selected.is_empty():
		node_selected.emit(selected); accept_event()


func _draw() -> void:
	if run==null or points.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),Color("10262f"))
	var margin := 22.0 * _unit
	for y in [(3.0 if _unit>1.1 else 18.0)*_unit,size.y-8.0*_unit]:
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(JourneyStyle.GOLD,.28),1,true)
	var last_column := -100
	for id: String in run.graph.rooms:
		var data: Dictionary = run.layout.rooms[id]
		if data.column==last_column or id==run.graph.start: continue
		last_column = data.column
		var x: float = points[id].x
		_text("首领" if id==run.graph.boss else "%02d" % (data.column+1),Vector2(x,(14 if _unit>1.1 else 32)*_unit),13,Color(JourneyStyle.GOLD,.5))
	for edge: Dictionary in run.graph.edges:
		var a: Vector2 = points[edge.from]
		var b: Vector2 = points[edge.to]
		var walked: bool = run.visited_rooms.has(edge.from) and run.visited_rooms.has(edge.to)
		var reachable: bool = edge.from==run.current_room and run.next_rooms().has(edge.to)
		var planned: bool = _planned_edge(edge.from,edge.to)
		var abandoned: bool = run.sealed.has(edge.from) or run.sealed.has(edge.to)
		var color := Color(JourneyStyle.GOLD,.46)
		if abandoned: color = Color(JourneyStyle.EDGE,.2)
		elif walked: color = JourneyStyle.RED
		elif planned: color = JourneyStyle.GOLD
		elif reachable: color = Color(JourneyStyle.GOLD,.9)
		var delta := b-a
		var trimmed_a := a+delta.normalized()*29*_unit
		var trimmed_b := b-delta.normalized()*29*_unit
		if walked or reachable or planned: draw_line(trimmed_a,trimmed_b,color,(2 if reachable or walked else 1.5)*_unit,true)
		else: draw_dashed_line(trimmed_a,trimmed_b,color,1.2*_unit,6*_unit,true)
		if reachable or planned:
			var middle := a.lerp(b,.55)
			var axis := delta.normalized()
			draw_polyline(PackedVector2Array([middle-axis.rotated(-.48)*7*_unit,middle,middle-axis.rotated(.48)*7*_unit]),color,1.5*_unit,true)
	for id: String in points: _draw_node(id)
	if _span>size.x+2:
		var width := (size.x-margin*2)*size.x/_span
		var x := margin+(size.x-margin*2-width)*_offset/maxf(1,_span-size.x)
		draw_line(Vector2(x,size.y-8),Vector2(x+width,size.y-8),Color(JourneyStyle.GOLD,.6),3,true)


func _planned_edge(from: String, to: String) -> bool:
	var index: int = run.planned_route.find(to)
	return index>=0 and (from==run.current_room if index==0 else from==run.planned_route[index-1])


func _draw_node(id: String) -> void:
	var center: Vector2 = points[id]
	var spec: Dictionary = run.graph.rooms[id]
	var current: bool = id==run.current_room
	var available: bool = run.next_rooms().has(id) or run.plan_choices().has(id)
	var past: bool = run.visited_rooms.has(id) and not current
	var abandoned: bool = run.sealed.has(id)
	var planned: bool = run.planned_route.has(id)
	var marked: bool = selected==id or _hover==id
	var radius: float = (27 if spec.kind=="boss" else 23)*_unit
	var ink := Color("152e35")
	var line := JourneyStyle.GOLD if current or available or planned else Color("7f8b7e")
	var text := JourneyStyle.TEXT
	if current: ink = Color("84382f"); line = JourneyStyle.GOLD
	elif past: ink = Color("3d3330"); line = JourneyStyle.RED
	elif abandoned: ink = Color("142930"); line = Color("35494b"); text = Color("66736e")
	elif spec.kind in ["elite","boss"]: ink = Color("3d2a2b"); line = Color("ba7360")
	if marked: line = JourneyStyle.TEXT
	var polygon := PackedVector2Array()
	var sides := 4 if spec.kind in ["elite","treasure"] else 8
	for i in sides: polygon.append(center+Vector2.from_angle(-PI*.5+TAU*i/sides)*radius)
	draw_colored_polygon(polygon,ink)
	polygon.append(polygon[0]); draw_polyline(polygon,line,(2 if current or marked else 1.3)*_unit,true)
	if current or planned or marked:
		draw_arc(center,radius+5*_unit,PI*.15,PI*.85,12,line,1.2*_unit,true)
		draw_arc(center,radius+5*_unit,PI*1.15,PI*1.85,12,line,1.2*_unit,true)
	_text(GLYPHS.get(spec.kind,"？"),center+Vector2(0,9*_unit),26,text)
	var caption: String = "当前" if current else ("已行" if past else LABELS[spec.kind])
	if current or marked and _unit<=1.1:
		_text(caption,center+Vector2(0,43*_unit),14,JourneyStyle.GOLD if current or available else text)
	if abandoned:
		draw_line(center+Vector2(-14,13)*_unit,center+Vector2(14,-13)*_unit,Color(JourneyStyle.EDGE,.8),1.5*_unit,true)


func _text(caption: String, at: Vector2, font_size: int, color: Color) -> void:
	var fs := roundi(font_size*_unit)
	var width := Ink.serif.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	draw_string(Ink.serif,at-Vector2(width*.5,0),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)
