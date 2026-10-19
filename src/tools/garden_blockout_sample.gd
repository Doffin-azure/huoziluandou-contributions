extends Control
## F6: integer tiles and directed node progression. No save writes.
const PLAN = preload("res://src/expedition/garden_blockout_plan.gd")
const VISUAL = preload("res://src/map/garden_blockout_visual.gd")
const COMPACT = preload("res://src/expedition/garden_compact_assembly.gd")
const TRAVEL = preload("res://src/expedition/garden_forward_travel.gd")
const COLORS = VISUAL.COLORS
const CACHE_LIMIT := 49
const OUTPUT := "res://docs/art-concepts/2026-10-18-garden-compact"
@export var map_seed := 17
@export var compact_layout := true
var plan: RefCounted
var travel: RefCounted
var door_visual: Node3D
var notice := ""
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var landscape: Node3D
var walker: Node3D
var painter: RefCounted
var overlay: Control
var header: VBoxContainer
var heading: Label
var seed_input: SpinBox
var status: Label
var controls: HBoxContainer
var roots := {}
var pending: Array[Vector2i] = []
var wanted := {}
var used := {}
var tick := 0
var max_cached := 0
var max_active := 0
var build_ms := .0
var moving := false
var route: Array[Vector2i] = []
var position_cell := Vector2i.ZERO
var leg := .0
var from := Vector3.ZERO
var to := Vector3.ZERO
var visited := {}
var selected := "start"
var overview := false
var show_roofs := false
var look := Vector3.ZERO
var target := Vector3.ZERO
var follow := true
var zoom := 1.0
var dragging := false
var pressed := false
var drag_start := Vector2.ZERO
var dragged := false
var touch_points := {}
var pinch_distance := .0
var pinch_zoom := 1.0
var mobile_quality := OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--mobile-map")
var _stream_at := Vector2i(-9999,-9999)
var _last_look := Vector3(INF,INF,INF)
var _last_zoom := -1.0
var _atlas_hits := {}
var _atlas_transform := Transform2D.IDENTITY
var _generation := 0
var _atlas_focus := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT); mouse_filter = MOUSE_FILTER_STOP
	viewport = SubViewport.new(); viewport.own_world_3d = true; viewport.msaa_3d = Viewport.MSAA_2X; add_child(viewport)
	var display := TextureRect.new(); display.texture = viewport.get_texture(); display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.set_anchors_and_offsets_preset(PRESET_FULL_RECT); display.mouse_filter = MOUSE_FILTER_IGNORE; add_child(display)
	world = Node3D.new(); viewport.add_child(world)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color("0f2027")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color = Color("acb6b0"); environment.environment.ambient_light_energy = .55
	world.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52,-28,0); sun.light_color = Color("eee2c7"); sun.light_energy = .8; sun.shadow_enabled = false; world.add_child(sun)
	camera = Camera3D.new(); camera.fov = 35; camera.near = .05; camera.far = 80; world.add_child(camera)
	painter = VISUAL.new()
	walker = Node3D.new(); world.add_child(walker)
	var body := MeshInstance3D.new(); var capsule := CapsuleMesh.new(); capsule.radius = .20; capsule.height = .9
	body.mesh = capsule; body.position.y = .45
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color("d4c197"); paint.roughness = 1; body.material_override = paint; walker.add_child(body)
	var scarf := MeshInstance3D.new(); var collar := BoxMesh.new(); collar.size = Vector3(.45,.12,.26); scarf.mesh = collar; scarf.position = Vector3(0,.68,.04)
	var red := StandardMaterial3D.new(); red.albedo_color = Color("9c473b"); scarf.material_override = red; walker.add_child(scarf)
	overlay = Control.new(); overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT); overlay.mouse_filter = MOUSE_FILTER_IGNORE; overlay.draw.connect(_draw_overlay); add_child(overlay)
	_build_ui(); resized.connect(_resize); _resize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): map_seed = int(arg.trim_prefix("--seed="))
	select_seed(map_seed)
	if OS.get_cmdline_user_args().has("--capture"): capture.call_deferred()


func _build_ui() -> void:
	header = VBoxContainer.new(); header.position = Vector2(20,16); header.mouse_filter = MOUSE_FILTER_STOP; add_child(header)
	heading = Label.new(); heading.text = "园林 · 正厅与侧室组合"; heading.add_theme_font_override("font",Ink.serif); heading.add_theme_font_size_override("font_size",24); header.add_child(heading)
	status = Label.new(); status.add_theme_font_size_override("font_size",15); status.add_theme_color_override("font_color",Color("bdc6b6")); header.add_child(status)
	controls = HBoxContainer.new(); controls.add_theme_constant_override("separation",8); add_child(controls)
	seed_input = SpinBox.new(); seed_input.min_value = 0; seed_input.max_value = 2147483647; seed_input.step = 1; seed_input.custom_minimum_size = Vector2(145,48); controls.add_child(seed_input)
	_button("生成种子",func():select_seed(int(seed_input.value)))
	_button("下一种子",func():select_seed(plan.seed_value+1))
	_button("庭园总览",func():set_overview(not overview))
	_button("回到行者",recenter)
	_button("侧室组合",focus_compound)
	_button("对比平行排布",func():compact_layout = not compact_layout; select_seed(map_seed))
	var roofs := CheckButton.new(); roofs.text = "屋顶占位"; roofs.custom_minimum_size.y = 48; roofs.toggled.connect(func(value):show_roofs = value; _update_roofs()); controls.add_child(roofs)
	var theme := Theme.new(); theme.default_font = Ink.serif; theme.default_font_size = 16
	var background := StyleBoxFlat.new(); background.bg_color = Color("142b31"); background.border_color = Color("627366"); background.set_border_width_all(1); background.content_margin_left = 12; background.content_margin_right = 12
	theme.set_stylebox("normal","Button",background); var hover := background.duplicate(); hover.bg_color = Color("34483e"); theme.set_stylebox("hover","Button",hover)
	theme.set_color("font_color","Button",Color("d6c49e")); controls.theme = theme
	theme.set_color("font_color","Label",Color("dfc99c")); theme.set_color("font_color","CheckButton",Color("d6c49e"))
	theme.set_stylebox("normal","LineEdit",background); theme.set_color("font_color","LineEdit",Color("dfc99c"))
	header.theme = theme


func _button(text: String, action: Callable) -> void:
	var button := Button.new(); button.text = text; button.custom_minimum_size.y = 48; button.pressed.connect(action); controls.add_child(button)


func _resize() -> void:
	if viewport==null: return
	var pixels := size*get_viewport().get_screen_transform().get_scale().abs()
	if mobile_quality: pixels *= minf(1,720.0/maxf(1,pixels.y))
	viewport.size = Vector2i(pixels.ceil()).max(Vector2i(32,32))
	if controls!=null:
		controls.position = Vector2(20,size.y-68)
		controls.scale = Vector2.ONE*minf(1,(size.x-40)/maxf(1,controls.get_combined_minimum_size().x))
	_last_look = Vector3(INF,INF,INF); _camera(); if overlay!=null: overlay.queue_redraw()


func select_seed(value: int) -> void:
	_generation += 1; map_seed = value; seed_input.value = value
	heading.text = "园林 · 正厅与侧室组合" if compact_layout else "园林 · 原平行排布（对照）"
	plan = PLAN.generate(value)
	if compact_layout:
		plan = COMPACT.fit(plan)
		if plan.assembly.has("error"): status.text = str(plan.assembly.error); return
	var report: Dictionary = plan.validate()
	if not report.ok: status.text = "生成冲突："+str(report.errors); push_error(status.text); return
	travel = TRAVEL.new(plan); notice = ""
	for root: Node3D in roots.values(): root.free()
	roots.clear(); pending.clear(); used.clear(); wanted.clear(); max_cached = 0; max_active = 0; build_ms = 0
	if landscape!=null: landscape.free()
	landscape = painter.surroundings(plan); world.add_child(landscape)
	position_cell = plan.nodes.start.at; walker.position = _point(position_cell)
	look = walker.position; target = look; follow = true; zoom = 1; moving = false; route.clear()
	visited = {"start":true}; selected = "start"; _stream_at = Vector2i(-9999,-9999); _atlas_focus = Rect2()
	_stream(position_cell); _camera(); _status(); overlay.queue_redraw()
	print("[BlockoutSample] ",report)


func _point(cell: Vector2i) -> Vector3: return Vector3(cell.x,0,cell.y)


func _stream(cell: Vector2i) -> void:
	var center: Vector2i = PLAN.chunk_at(Vector2(cell))
	if center==_stream_at: return
	_stream_at = center; wanted.clear(); tick += 1
	for x in range(center.x-2,center.x+3):
		for y in range(center.y-2,center.y+3):
			var key := Vector2i(x,y)
			if plan.chunks.has(key): wanted[key] = true; used[key] = tick
	pending.clear()
	for key: Vector2i in wanted:
		if not roots.has(key): pending.append(key)
	pending.sort_custom(func(a,b):return a.distance_squared_to(center)<b.distance_squared_to(center))
	for key: Vector2i in roots: roots[key].visible = wanted.has(key)
	_evict()
	_update_doors()


func _update_doors() -> void:
	if door_visual!=null: door_visual.free()
	door_visual = painter.gates(travel,wanted); world.add_child(door_visual)


func _assemble() -> void:
	var began := Time.get_ticks_usec(); var built := 0
	while not pending.is_empty() and built<3 and Time.get_ticks_usec()-began<4000:
		var key: Vector2i = pending.pop_front()
		if roots.has(key) or not wanted.has(key): continue
		if roots.size()>=CACHE_LIMIT: _evict(CACHE_LIMIT-1)
		var root: Node3D = painter.chunk(plan,key); world.add_child(root); roots[key] = root; built += 1
	build_ms += (Time.get_ticks_usec()-began)/1000.0
	if built>0: _evict(); _update_roofs(); _status()
	max_cached = maxi(max_cached,roots.size()); max_active = maxi(max_active,wanted.size())


func _evict(limit := CACHE_LIMIT) -> void:
	while roots.size()>limit:
		var candidate := Vector2i(-9999,-9999); var oldest := 2147483647
		for key: Vector2i in roots:
			if not wanted.has(key) and int(used.get(key,0))<oldest: candidate = key; oldest = int(used.get(key,0))
		if candidate.x==-9999: break
		roots[candidate].free(); roots.erase(candidate); used.erase(candidate)


func _update_roofs() -> void:
	for root: Node3D in roots.values():
		root.get_node("RoofProxies").visible = show_roofs
		for roof in root.get_meta("roof_items",[]): roof.node.visible = not roof.rect.grow(.6).has_point(Vector2(walker.position.x,walker.position.z))


func _status() -> void:
	if plan==null: return
	var packing := "占地减少 %d%% · 原连接保留" % roundi(float(plan.assembly.get("area_reduction",0))*100) if plan.layout_mode=="compact" else "原平行排布"
	var counts := "全园 %d 个候选节点" % plan.nodes.size()
	if overview and _atlas_focus.has_area():
		var local_count: int = plan.nodes.values().filter(func(n):return _atlas_focus.has_point(Vector2(n.at))).size()
		counts = "本庭院 %d 节点 / 全园 %d 节点（编号沿用全园）" % [local_count,plan.nodes.size()]
	var next_labels: Array[String] = []
	for id: String in travel.next_nodes: next_labels.append("%02d%s" % [plan.nodes[id].number,PLAN.GLYPHS[plan.nodes[id].kind]])
	var progress := "当前 %02d%s · 可选去向：%s" % [plan.nodes[travel.current_node].number,PLAN.LABELS[plan.nodes[travel.current_node].kind],"、".join(next_labels) if not next_labels.is_empty() else "已到终庭"]
	status.text = "种子 %d · %s · %s\n%s\n%s" % [plan.seed_value,counts,packing,progress,notice if not notice.is_empty() else "点击石砖逐格走；单向推进，过门关闭来路。样板不结算遭遇。"]


func _process(delta: float) -> void:
	if plan==null: return
	_assemble()
	if moving:
		leg = minf(1,leg+delta/.22); walker.position = from.lerp(to,leg)
		if leg>=1:
			var before: String = travel.current_node; var was_departed: bool = travel.departed
			var next_cell: Vector2i = route.pop_front()
			if not travel.step(position_cell,next_cell):
				walker.position = _point(position_cell); route.clear(); moving = false; _status(); return
			position_cell = next_cell
			var id := str(plan.cells.get(position_cell,""))
			if not id.is_empty(): visited[id] = true
			if before!=travel.current_node or was_departed!=travel.departed:
				if before!=travel.current_node: selected = travel.current_node
				_update_doors(); _status()
			_stream(position_cell); _update_roofs()
			if route.is_empty(): moving = false; _status()
			else: from = walker.position; to = _point(route[0]); leg = 0
		if not overview and follow: _deadzone()
		if overview: overlay.queue_redraw()
	if look.distance_squared_to(target)>.000001: look = look.lerp(target,1-exp(-delta/.18))
	if not overview: _camera()
	if moving: overlay.queue_redraw()


func _camera() -> void:
	if camera==null or size.y<1: return
	if look.is_equal_approx(_last_look) and is_equal_approx(zoom,_last_zoom): return
	_last_look = look; _last_zoom = zoom
	var pitch := deg_to_rad(52); var yaw := deg_to_rad(12)
	var back := Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
	var distance := 19.0*zoom*maxf(1,1.25/maxf(.5,size.x/size.y))
	camera.position = look+Vector3.UP*.35+back*distance; camera.look_at(look+Vector3.UP*.35,Vector3.UP)
	if overlay!=null: overlay.queue_redraw()


func project(point: Vector3) -> Vector2: return camera.unproject_position(point)*size/Vector2(viewport.size)


func ground_at(pixel: Vector2) -> Vector3:
	var at := pixel*Vector2(viewport.size)/size.max(Vector2.ONE)
	var origin := camera.project_ray_origin(at); var ray := camera.project_ray_normal(at)
	return origin-ray*origin.y/ray.y if ray.y<-.001 else origin


func _deadzone() -> void:
	var area := Rect2(Vector2(20,96),size-Vector2(40,180)); var half := area.size*Vector2(.4,.36)*.5
	var at := project(_point(position_cell)+Vector3.UP*.45)
	var desired := at.clamp(area.get_center()-half,area.get_center()+half)
	if at.distance_to(desired)>.5:
		var correction := ground_at(at)-ground_at(desired); target = look+Vector3(correction.x,0,correction.z)


func walk_to(cell: Vector2i) -> bool:
	if moving: return false
	var path: Array[Vector2i] = travel.path(position_cell,cell)
	if path.size()<2:
		if plan.cells.has(cell) and cell!=position_cell:
			notice = "只能前往可选的下一节点；来路已关门，不能回头补走支路。"; _status()
		return false
	notice = ""; _status()
	route = path.slice(1); from = walker.position; to = _point(route[0]); leg = 0; moving = true; follow = true
	overlay.queue_redraw(); return true


func recenter() -> void:
	set_overview(false); follow = true; target = _point(position_cell); zoom = 1


func set_overview(value: bool) -> void:
	overview = value; _atlas_focus = Rect2(); viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if value else SubViewport.UPDATE_ALWAYS
	_status(); overlay.queue_redraw()


func focus_compound() -> void:
	if plan.layout_mode!="compact": return
	var compound: Dictionary = plan.assembly.compounds[0]
	for candidate: Dictionary in plan.assembly.compounds:
		if candidate.members.has(selected): compound = candidate; break
	set_overview(true)
	var box: Rect2 = plan.node_rect(plan.nodes[compound.members[0]])
	for id: String in compound.members: box = box.merge(plan.node_rect(plan.nodes[id]))
	_atlas_focus = box.grow(3); _status(); overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if plan==null: return
	if event is InputEventMouseButton and event.device!=-1:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: pressed = true; dragged = false; drag_start = event.position
			else:
				if pressed and not dragged: _tap(event.position)
				pressed = false
		elif event.button_index==MOUSE_BUTTON_MIDDLE: dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and not overview:
			zoom = clampf(zoom*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.7,1.35)
	elif event is InputEventMouseMotion and not overview:
		if dragging or pressed and event.position.distance_to(drag_start)>12:
			dragged = true; follow = false; target += ground_at(event.position-event.relative)-ground_at(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size()==1: drag_start = event.position; dragged = false
			elif touch_points.size()==2:
				pinch_distance = touch_points.values()[0].distance_to(touch_points.values()[1]); pinch_zoom = zoom; dragged = true
		else:
			if touch_points.size()==1 and not dragged: _tap(event.position)
			touch_points.erase(event.index)
	elif event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		if touch_points.size()==2 and not overview: zoom = clampf(pinch_zoom*pinch_distance/maxf(1,touch_points.values()[0].distance_to(touch_points.values()[1])),.7,1.35)
		elif not overview and event.position.distance_to(drag_start)>12:
			dragged = true; follow = false; target += ground_at(event.position-event.relative)-ground_at(event.position)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed: _release_mouse.call_deferred(event.button_index)
	if event is InputEventScreenTouch and not event.pressed: _release_touch.call_deferred(event.index)


func _release_mouse(button: int) -> void:
	if button==MOUSE_BUTTON_LEFT: pressed = false
	if button==MOUSE_BUTTON_MIDDLE: dragging = false


func _release_touch(index: int) -> void: touch_points.erase(index)


func _tap(at: Vector2) -> void:
	if overview:
		for id: String in _atlas_hits:
			if _atlas_hits[id].has_point(at): selected = id; _status(); walk_to(plan.nodes[id].at); overlay.queue_redraw(); return
		return
	var point := ground_at(at); var cell := Vector2i(roundi(point.x),roundi(point.z))
	var id := str(plan.cells.get(cell,""))
	if not id.is_empty(): selected = id; _status()
	walk_to(cell)


func _draw_overlay() -> void:
	if plan==null: return
	_atlas_hits.clear()
	if overview: _draw_atlas(); return
	if moving:
		var points := PackedVector2Array([project(walker.position+Vector3.UP*.05)])
		for c: Vector2i in route: points.append(project(_point(c)+Vector3.UP*.05))
		if points.size()>1: overlay.draw_polyline(points,Color("d7b875"),2,true)
		if not route.is_empty(): overlay.draw_circle(points[-1],7,Color("ecd599"),false,2,true)
	var occupied: Array[Rect2] = []
	for node: Dictionary in plan.nodes.values():
		var at := _point(node.at)
		if at.distance_to(walker.position)>11: continue
		var screen := project(at+Vector3.UP*1.5)
		if screen.x<24 or screen.x>size.x-160 or screen.y<120 or screen.y>size.y-120: continue
		var title: String = "%02d %s%s" % [node.number,PLAN.LABELS[node.kind]," · "+str(node.role) if node.has("role") else ""]
		var width := Ink.serif.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+20
		var box := Rect2(screen-Vector2(width*.5,32),Vector2(width,30))
		if occupied.any(func(other):return box.intersects(other)): continue
		occupied.append(box)
		overlay.draw_rect(box,Color(.04,.09,.11,.9)); overlay.draw_string(Ink.serif,box.position+Vector2(10,22),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,COLORS[node.kind])


func _draw_atlas() -> void:
	overlay.draw_rect(Rect2(Vector2.ZERO,size),Color("102129"))
	var area := Rect2(Vector2(26,126),size-Vector2(52,212)); var focus := _atlas_focus if _atlas_focus.has_area() else Rect2(Vector2(-.5,-.5),Vector2(plan.bounds.size)); var extent := focus.size
	var scale_value := minf(area.size.x/extent.x,area.size.y/extent.y)
	_atlas_transform = Transform2D(0,Vector2.ONE*scale_value,0,area.get_center()-focus.get_center()*scale_value)
	var transform := _atlas_transform
	overlay.draw_rect(Rect2(transform*focus.position,extent*scale_value),Color("1a3b43"))
	for bank: Dictionary in plan.banks:
		var region := Rect2(Vector2(bank.rect.position)-Vector2.ONE*.5,Vector2(bank.rect.size)).intersection(focus)
		if region.has_area(): overlay.draw_rect(Rect2(transform*region.position,region.size*scale_value),Color("324438"))
	for c: Vector2i in plan.cells:
		if focus.has_point(Vector2(c)): overlay.draw_rect(Rect2(transform*(Vector2(c)-Vector2.ONE*.5),Vector2.ONE*scale_value),Color("6b6b5b"))
	for rect: Rect2i in plan.ponds:
		var region := Rect2(Vector2(rect.position)-Vector2.ONE*.5,Vector2(rect.size)).intersection(focus)
		if region.has_area(): overlay.draw_rect(Rect2(transform*region.position,region.size*scale_value),Color("1a3b43"))
	for wall: Dictionary in plan.walls:
		if focus.has_point((wall.a+wall.b)*.5): overlay.draw_line(transform*wall.a,transform*wall.b,Color("15272c"),maxf(1,.13*scale_value))
	for gate: Dictionary in travel.gates:
		var middle: Vector2 = (Vector2(gate.a)+Vector2(gate.b))*.5
		if not focus.has_point(middle): continue
		var normal := Vector2(gate.b-gate.a); var tangent := Vector2(-normal.y,normal.x)
		if not gate.open:
			overlay.draw_line(transform*(middle-tangent*.43),transform*(middle+tangent*.43),Color("b7755b"),maxf(2,scale_value*.13))
		else:
			var direction := Vector2(gate.direction); var across := Vector2(-direction.y,direction.x)
			overlay.draw_colored_polygon(PackedVector2Array([transform*(middle+direction*.4),transform*(middle-direction*.25-across*.25),transform*(middle-direction*.25+across*.25)]),Color("ebc27b"))
	for node: Dictionary in plan.nodes.values():
		var rect: Rect2 = plan.node_rect(node); var box := Rect2(transform*rect.position,rect.size*scale_value)
		if not focus.has_point(Vector2(node.at)): continue
		_atlas_hits[node.id] = box.grow(3)
		if node.id==travel.current_node: overlay.draw_rect(box.grow(1),Color("ead29b"),false,2)
		elif travel.next_nodes.has(node.id): overlay.draw_rect(box.grow(1),Color("bb9757"),false,1.5)
		elif visited.has(node.id): overlay.draw_rect(box,Color(0,0,0,.22))
		var text: String = "%02d%s" % [node.number,PLAN.GLYPHS[node.kind]]
		var font_size := clampi(roundi(scale_value*1.6),11,18)
		var width := Ink.serif.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		overlay.draw_string(Ink.serif,box.get_center()+Vector2(-width*.5,font_size*.35),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,COLORS[node.kind])
		if _atlas_focus.has_area() and node.has("role"):
			var role_width := Ink.serif.get_string_size(node.role,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
			overlay.draw_string(Ink.serif,box.get_center()+Vector2(-role_width*.5,30),node.role,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("d8c69f"))
	if moving:
		var points := PackedVector2Array([transform*Vector2(walker.position.x,walker.position.z)])
		for c in route: points.append(transform*Vector2(c))
		if points.size()>1: overlay.draw_polyline(points,Color("edce86"),2,true)
	overlay.draw_circle(transform*Vector2(walker.position.x,walker.position.z),4,Color("f1ddb0"))


func ready_chunks() -> bool: return pending.is_empty()


func metrics() -> Dictionary:
	return {"seed":plan.seed_value,"nodes":plan.nodes.size(),"total_chunks":plan.chunks.size(),"active_chunks":wanted.size(),"cached_chunks":roots.size(),"max_cached_chunks":max_cached,"cache_limit":CACHE_LIMIT,"generation_ms":plan.generation_ms,"assembly_cpu_ms":build_ms,"viewport_pixels":[viewport.size.x,viewport.size.y],"geometry_only":true,"layout_mode":plan.layout_mode,"packing":plan.assembly}


func capture() -> void:
	get_window().size = Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var results: Array = []
	for value in [17,29,67]:
		select_seed(value)
		for i in 300:
			await get_tree().process_frame
			if ready_chunks(): break
		set_overview(true); await _snap("seed-%d-plan.png" % value)
		focus_compound(); await _snap("seed-%d-compound.png" % value)
		set_overview(false); await _snap("seed-%d-entry.png" % value)
		results.append(metrics())
		compact_layout = false; select_seed(value); set_overview(true); await _snap("seed-%d-parallel.png" % value)
		compact_layout = true
	var file := FileAccess.open(OUTPUT.path_join("blockout-capture.json"),FileAccess.WRITE); file.store_string(JSON.stringify(results,"  "))
	print("[BlockoutCapture] ",results); get_tree().quit()


func _snap(filename: String) -> void:
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(filename))
