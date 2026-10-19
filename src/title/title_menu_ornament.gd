extends Control
## Real buttons keep their focus/input semantics; this layer paints their frame.
var buttons: Array[Button] = []
var highlighted: Button


func setup(items: Array[Button]) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	buttons = items
	for button in buttons:
		button.mouse_entered.connect(func(): highlighted = button; queue_redraw())
		button.focus_entered.connect(func(): highlighted = button; queue_redraw())
		button.mouse_exited.connect(func(): highlighted = null; queue_redraw())
	queue_redraw()


func _diamond(at: Vector2, radius: float, color: Color, fill := false) -> void:
	var shape := PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius,0),at+Vector2(0,radius),at+Vector2(-radius,0),at+Vector2(0,-radius)])
	if fill: draw_colored_polygon(shape,color)
	else: draw_polyline(shape,color,1.2,true)


func _draw() -> void:
	if buttons.is_empty() or not is_instance_valid(buttons[0]): return
	var gold := Color("b18a50"); var pale := Color("ead2a0")
	var columns := {}
	for button in buttons:
		var box := Rect2(button.get_global_rect().position-global_position,button.size)
		var key := roundi(box.position.x)
		if not columns.has(key): columns[key] = Vector2(box.position.y-18,box.end.y+18)
		else: columns[key].y = box.end.y+18
	for key: int in columns:
		var x := float(key)-19; var ends: Vector2 = columns[key]
		draw_line(Vector2(x,ends.x),Vector2(x,ends.y),gold*.72,1,true)
		draw_line(Vector2(x-4,ends.x+12),Vector2(x-4,ends.y-12),gold*.40,1,true)
		_diamond(Vector2(x,ends.x),5,gold); _diamond(Vector2(x,ends.y),5,gold)
	for button in buttons:
		var box := Rect2(button.get_global_rect().position-global_position,button.size)
		var x := box.position.x-19
		var active: bool = button==highlighted or button.has_focus() or highlighted==null and button==buttons[0]
		var at := Vector2(x,box.get_center().y)
		_diamond(at,9,gold); _diamond(at,4,pale,active)
		if not active: continue
		var frame := PackedVector2Array([Vector2(x+12,box.position.y+3),Vector2(box.end.x-13,box.position.y+3),Vector2(box.end.x,box.get_center().y),Vector2(box.end.x-13,box.end.y-3),Vector2(x+12,box.end.y-3),Vector2(x,box.get_center().y),Vector2(x+12,box.position.y+3)])
		draw_colored_polygon(frame,Color(.21,.065,.05,.82))
		draw_polyline(frame,Color("c69156"),1.3,true)
		_diamond(at,11,Color("bc4c35")); _diamond(at,4,Color("f6d29a"),true)
