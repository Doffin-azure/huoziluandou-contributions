extends RefCounted
## Readable route atlas, independently fitted to the available screen area.
## It uses the actual room/corridor coordinates, without shrinking 3D ink to pixels.
const GLYPHS := {"start":"始","battle":"战","elite":"镇","boss":"渊","event":"问","rest":"息","shop":"市","treasure":"藏"}


static func _anchor(run: RefCounted, room: Dictionary) -> Vector2:
	return room.stand if not run.layout.site.is_empty() else room.bounds.get_center()


static func _extent(run: RefCounted, room: Dictionary, scale_value: float) -> Vector2:
	if run.layout.compact!=null: return Vector2(room.bounds.size)*scale_value
	return Vector2(38,34) if not run.layout.site.is_empty() else (Vector2(room.bounds.size)*scale_value).max(Vector2(35,30))


static func transform_for(run: RefCounted, area: Rect2) -> Transform2D:
	var bounds: Rect2 = run.layout.rooms[run.graph.start].bounds
	for room: Dictionary in run.layout.rooms.values(): bounds = bounds.merge(room.bounds)
	if not run.layout.site.is_empty(): bounds = run.layout.bounds
	bounds = bounds.grow(2)
	var scale_value := minf(area.size.x/bounds.size.x,area.size.y/bounds.size.y)
	return Transform2D(0,Vector2.ONE*scale_value,0,area.get_center()-bounds.get_center()*scale_value)


static func map_area(safe: Rect2) -> Rect2:
	return Rect2(safe.position+Vector2(24,58),safe.size-Vector2(48,110))


static func known_rooms(run: RefCounted) -> Dictionary:
	if run.layout.compact!=null: return run.graph.rooms.duplicate()
	var known: Dictionary = run.visited_rooms.duplicate()
	var frontier: Array = [run.current_room]
	for depth in 2:
		var next: Array = []
		for id: String in frontier:
			for target: String in run.graph.rooms[id].next:
				if not run.sealed.has(target): known[target] = true; next.append(target)
		frontier = next
	return known


static func draw(canvas: Control, run: RefCounted, safe: Rect2) -> void:
	if run.layout.compact!=null: _draw_compact(canvas,run,safe); return
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("0b171d"))
	var area := map_area(safe)
	if area.size.x<1 or area.size.y<1: return
	var transform := transform_for(run,area)
	var known := known_rooms(run)
	var reachable: Array = run.next_rooms()
	canvas.draw_string(Ink.serif,safe.position+Vector2(24,30),"庭园舆图",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("c9b58c"))
	canvas.draw_line(safe.position+Vector2(24,43),Vector2(safe.end.x-24,safe.position.y+43),Color("34434a"),1,true)
	if not run.layout.site.is_empty():
		var outline := Rect2(transform*run.layout.bounds.position,run.layout.bounds.size*transform.x.length())
		canvas.draw_rect(outline,Color("1e302b")); canvas.draw_rect(outline,Color("5e6b53"),false,1.5)
		var pond := PackedVector2Array()
		for raw in run.layout.site.pond_polygon: pond.append(transform*Vector2(float(raw[0]),float(raw[1])))
		canvas.draw_colored_polygon(pond,Color("153b43")); canvas.draw_polyline(pond,Color("4a746b"),1.5,true)
		for raw: Dictionary in run.layout.site.buildings:
			var box := preload("res://src/expedition/authored_garden_plan.gd").rect(raw.rect)
			canvas.draw_rect(Rect2(transform*box.position,box.size*transform.x.length()),Color("38483c"))
	for corridor: Dictionary in run.layout.corridors:
		var points := PackedVector2Array()
		for point: Vector2 in corridor.points: points.append(transform*point)
		var closed: bool = run.sealed.has(corridor.from) or run.sealed.has(corridor.to)
		var active: bool = run.visited_rooms.has(corridor.from) or run.visited_rooms.has(corridor.to)
		canvas.draw_polyline(points,Color("112127"),7,true)
		canvas.draw_polyline(points,Color("563535") if closed else (Color("a38e61") if active else Color("425456")),2.5,true)
	for id: String in run.graph.rooms:
		var room: Dictionary = run.layout.rooms[id]
		var at: Vector2 = transform*_anchor(run,room)
		var extent := _extent(run,room,transform.x.length())
		var box := Rect2(at-extent*.5,extent)
		var selected: bool = id==run.current_room
		var closed: bool = run.sealed.has(id)
		var visited: bool = run.visited_rooms.has(id)
		var fill := Color("532e2b") if selected else (Color("233a3e") if visited else Color("14262c"))
		var edge := Color("c4a16a") if selected or reachable.has(id) else Color("536b6b")
		if closed: fill = Color("211e23"); edge = Color("5d3b3b")
		canvas.draw_rect(Rect2(box.position+Vector2(0,3),box.size),Color("060f14"))
		canvas.draw_rect(box,fill)
		canvas.draw_rect(box,edge,false,2 if selected else 1)
		var glyph: String = GLYPHS[room.kind] if known.has(id) else "？"
		if closed: glyph = "封"
		var font_size := 23 if selected else 20
		var width := Ink.serif.get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		canvas.draw_string(Ink.serif,at+Vector2(-width*.5,7),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("d4c49f") if known.has(id) else Color("728582"))
		if selected or reachable.has(id):
			var label: String = run.LABELS[room.kind]+(" · 当前" if selected else "")
			var label_width := Ink.serif.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			canvas.draw_string(Ink.serif,at+Vector2(-label_width*.5,extent.y*.5+17),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c3aa7c"))
	canvas.draw_string(Ink.serif,Vector2(safe.position.x+24,safe.end.y-18),"点击可达庭院前往　·　滚轮向上／Esc 返回近景",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("8faaa7"))


static func _draw_compact(canvas: Control, run: RefCounted, safe: Rect2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("0b171d"))
	var area := map_area(safe)
	if area.size.x<1 or area.size.y<1: return
	var transform := transform_for(run,area); var scale_value := transform.x.length()
	var plan: RefCounted = run.layout.compact
	canvas.draw_string(Ink.serif,safe.position+Vector2(24,30),"庭园舆图 · 全园 %d 个候选节点 · 已过 %d 庭" % [run.graph.rooms.size(),run.resolved.size()],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("c9b58c"))
	canvas.draw_rect(Rect2(transform*run.layout.bounds.position,run.layout.bounds.size*scale_value),Color("15313a"))
	for bank: Dictionary in plan.banks:
		canvas.draw_rect(Rect2(transform*(Vector2(bank.rect.position)-Vector2.ONE*.5),Vector2(bank.rect.size)*scale_value),Color("293c33"))
	for cell: Vector2i in plan.cells:
		canvas.draw_rect(Rect2(transform*(Vector2(cell)-Vector2.ONE*.5),Vector2.ONE*scale_value),Color("5e6052"))
	for pond: Rect2i in plan.ponds:
		canvas.draw_rect(Rect2(transform*(Vector2(pond.position)-Vector2.ONE*.5),Vector2(pond.size)*scale_value),Color("15313a"))
	for wall: Dictionary in plan.walls: canvas.draw_line(transform*wall.a,transform*wall.b,Color("10212a"),maxf(1,scale_value*.12))
	var reachable: Array = run.next_rooms()
	var frontier: Array = run.plan_choices()
	var planned_edges := {}; var previous: String = run.current_room
	for id: String in run.planned_route:
		planned_edges[previous+">"+id] = true; previous = id
	for edge: Dictionary in plan.corridors:
		var chosen: bool = planned_edges.has(edge.from+">"+edge.to)
		if chosen:
			var line := PackedVector2Array()
			for cell: Vector2i in edge.floor: line.append(transform*Vector2(cell))
			if line.size()>1: canvas.draw_polyline(line,Color("e5b85f"),maxf(2,scale_value*.24),true)
		var outside: Array = edge.floor.filter(func(c):return str(plan.cells[c]).is_empty())
		if outside.size()<2: continue
		var index := outside.size()/2; var at := Vector2(outside[index]); var direction := Vector2(outside[index]-outside[index-1]).normalized()
		var across := Vector2(-direction.y,direction.x)
		var color := Color("f3ca73") if chosen else (Color("b99d62") if edge.from==run.current_room and reachable.has(edge.to) else Color("758473"))
		if run.sealed.has(edge.from) or run.sealed.has(edge.to): color = Color("704b43")
		canvas.draw_colored_polygon(PackedVector2Array([transform*(at+direction*.35),transform*(at-direction*.25-across*.25),transform*(at-direction*.25+across*.25)]),color)
	for gate: Dictionary in run.travel.gates:
		if gate.open: continue
		# Future encounters have locked exits until resolved. They are not dead
		# ends; only show the closures that constrain the current journey.
		if not gate.entries.any(func(entry):return run.visited_rooms.has(entry.owner) or run.sealed.has(entry.owner)): continue
		var middle: Vector2 = (Vector2(gate.a)+Vector2(gate.b))*.5; var normal := Vector2(gate.b-gate.a); var tangent := Vector2(-normal.y,normal.x)
		canvas.draw_line(transform*(middle-tangent*.43),transform*(middle+tangent*.43),Color("a36850"),maxf(1.5,scale_value*.13))
	for id: String in run.graph.rooms:
		var room: Dictionary = run.layout.rooms[id]; var box := Rect2(transform*room.bounds.position,room.bounds.size*scale_value)
		var current: bool = id==run.current_room; var closed: bool = run.sealed.has(id)
		canvas.draw_rect(box,Color("333d3b"))
		if closed or run.visited_rooms.has(id) and not current: canvas.draw_rect(box,Color(0,0,0,.28))
		if run.planned_route.has(id): canvas.draw_rect(box,Color(.85,.53,.16,.25)); canvas.draw_rect(box.grow(1),Color("e5b85f"),false,2)
		if current: canvas.draw_rect(box.grow(2),Color("eee0b4"),false,2)
		elif frontier.has(id): canvas.draw_rect(box.grow(2),Color("e8cb88"),false,2)
		elif reachable.has(id): canvas.draw_rect(box.grow(1),Color("ad986a"),false,1)
		var title: String = "%02d%s" % [room.number,GLYPHS[room.kind]]
		var font_size := clampi(roundi(scale_value*1.5),10,20)
		var width := Ink.serif.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var color: Color = preload("res://src/map/garden_blockout_visual.gd").COLORS[room.kind]
		canvas.draw_string(Ink.serif,box.get_center()+Vector2(-width*.5,font_size*.35),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color.darkened(.35) if closed else color.lightened(.28))
	canvas.draw_circle(transform*run.layout.point(run.position),4,Color("f0d3a0"))
	canvas.draw_string(Ink.serif,Vector2(safe.position.x+24,safe.end.y-33),"战 普通战　镇 精英　问 事件　息 休息　市 商店　藏 宝藏　渊 首领",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("aeb7a6"))
	canvas.draw_string(Ink.serif,Vector2(safe.position.x+24,safe.end.y-13),"点亮框逐段预选 → 确认前往 · 过门后不可回访 · Esc 返回庭院",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c4a66e"))


static func pick(run: RefCounted, position: Vector2, safe: Rect2) -> String:
	var area := map_area(safe)
	if area.size.x<1 or area.size.y<1: return ""
	var transform := transform_for(run,area)
	for id: String in run.graph.rooms:
		var room: Dictionary = run.layout.rooms[id]
		var at: Vector2 = transform*_anchor(run,room)
		var extent := _extent(run,room,transform.x.length())
		if Rect2(at-extent*.5,extent).grow(3).has_point(position): return id
	return ""
