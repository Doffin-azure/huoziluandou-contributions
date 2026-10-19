extends Control
## Perspective courtyard viewport. Picking and walking share GardenRoomLayout coordinates.
signal state_changed
signal walker_pressed
signal arrived
signal overview_changed
signal node_selected(id: String)
signal exit_selected(id: String)
const VISUAL = preload("res://src/map/garden_room_visual.gd")
const TRAVELER = preload("res://src/map/expedition_lantern_traveler.gd")
const POND = preload("res://src/map/expedition_pond_shape_tile.gd")
const BOUNDARY = preload("res://src/map/expedition_garden_boundary.gd")
const ATLAS = preload("res://src/map/garden_route_overview.gd")
const EXITS = preload("res://src/map/garden_route_exits.gd")
const CLUSTER_VISUAL = preload("res://src/map/garden_cluster_visual.gd")
var run: RefCounted
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var room_roots := {}
var cluster_roots := {}
var bridge_root: Node3D
var marker_root: Node3D
var walker: Node3D
var style: ExpeditionFlatStyle
var ground: ShaderMaterial
var environment: Environment
var water_paint: ShaderMaterial
var fog: ImageTexture
var _look := Vector3.ZERO
var _target := Vector3.ZERO
var _distance := 16.0
var _follow := true
var _pan := false
var _moving := false
var _route: Array = []
var _leg := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _loaded_act := 0
var _outline_tick := 0.0
var bridge_network: Node3D
var _gate_markers := {}
var _walk_steps := 0
var _gate_signature := ""
var _surface_patches: Array[Dictionary] = []
var _overview := false
var _overlay: Control
var _safe_area := Rect2()
var _zoom := 1.0
var _room_distance := 16.0
var _framed_room := ""
var _interaction_blocked := false
var authored_root: Node3D
var profile := {"build_count":0,"assembly_ms":0.0,"resume_ms":0.0,"fog_ms":0.0,"outline_ms":0.0}
var mobile_quality := OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--mobile-map")
var _last_camera := Vector3(INF,INF,INF)
var _last_distance := -1.0
var _last_safe := Rect2()
var _outlines_dirty := true
var _fog_signature := ""
var _selected_cell := Vector2i(-9999,-9999)
var _touches := {}
var _touch_start := Vector2.ZERO
var _touch_dragged := false
var _pinch_distance := 0.0
var _pinch_zoom := 1.0
var _mouse_start := Vector2.ZERO
var _mouse_dragged := false
var _mouse_down := false
var _active := true
var _label_hits := {}
var ui_exclusions: Array = []
var _selected_building := {}
var _building := false
var _planner_area := Rect2()
var selected_exit := ""
var _preview_path: Array = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	display.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(display)
	_overlay = Control.new()
	_overlay.set_script(preload("res://src/map/garden_room_map_overlay.gd"))
	_overlay.map_view = self
	_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_overlay)
	var palette: ExpeditionFlatPalette = preload("res://assets/expedition/palettes/mochi_night.tres").duplicate(true)
	palette.outline_pixels = 1.6
	world = Node3D.new(); viewport.add_child(world)
	var settings := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = palette.background.darkened(.48)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = palette.distant.lerp(palette.water,.28)
	environment.ambient_light_energy = .30 if run!=null and run.travel!=null else .24
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = not mobile_quality; environment.glow_intensity = .2
	settings.environment = environment; world.add_child(settings)
	for entry in [[palette.glyph_fill,.68,Vector3(-48,-32,0),true],[palette.distant,.22,Vector3(-25,145,0),false],[palette.garden_grass,.11,Vector3(-22,25,0),false]]:
		if mobile_quality and not entry[3]: continue
		var light := DirectionalLight3D.new()
		light.light_color = entry[0]; light.light_energy = entry[1]; light.rotation_degrees = entry[2]
		light.shadow_enabled = entry[3]
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if mobile_quality else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		light.directional_shadow_max_distance = 28 if mobile_quality else 40
		light.directional_shadow_blend_splits = true
		light.shadow_bias = .04
		light.shadow_normal_bias = 1.0
		light.shadow_blur = 1.2
		world.add_child(light)
	camera = Camera3D.new(); camera.fov = 35; camera.near = .05; camera.far = 150
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	world.add_child(camera)
	style = ExpeditionFlatStyle.new(palette); style.camera = camera; style.set_scene_lighting(true)
	preload("res://src/map/garden_mesh_library.gd").preload_common()
	ground = POND.ground_material(Vector2.ZERO)
	ground.set_shader_parameter("stone_grid_offset",Vector2.ONE*.5 if run!=null and run.layout.walk_step>=1 else Vector2.ZERO)
	ground.set_shader_parameter("fog_color",Color("08161a")); ground.set_shader_parameter("theme_tint",Color(0.91,0.98,0.91))
	ground.set_shader_parameter("clip_vision_bounds",true)
	resized.connect(_resize); _resize()
	get_window().size_changed.connect(_resize.call_deferred)
	if run!=null: refresh_run()


func _exit_tree() -> void:
	if style!=null: style.dispose()


func _resize() -> void:
	if viewport==null: return
	# canvas_items scales logical UI coordinates. Render 3D at the actual pixel
	# density, then convert every projection / ray consistently at this boundary.
	var pixels := get_viewport().get_screen_transform().get_scale().abs()
	pixels = pixels.clamp(Vector2.ONE*.25,Vector2.ONE*2.5)
	var resolution := size*pixels
	if mobile_quality: resolution *= minf(1.0,720.0/maxf(1.0,resolution.y))
	viewport.size = Vector2i(resolution.ceil()).max(Vector2i(32,32))
	_last_camera = Vector3(INF,INF,INF)
	_update_framing()
	_update_camera()
	if _overlay!=null: _overlay.queue_redraw()


func set_safe_area(area: Rect2) -> void:
	if _safe_area.is_equal_approx(area): return
	_safe_area = area
	_update_framing()


func set_interaction_blocked(value: bool) -> void:
	_interaction_blocked = value
	if value: _pan = false


func safe_area() -> Rect2:
	return _safe_area.intersection(Rect2(Vector2.ZERO,size)) if _safe_area.has_area() else Rect2(Vector2(18,18),size-Vector2(36,82))


func set_planner_area(area: Rect2) -> void:
	_planner_area = area
	if _overlay!=null: _overlay.queue_redraw()


func overview_area() -> Rect2:
	return _planner_area if run!=null and run.travel!=null and _planner_area.has_area() else safe_area()


func screen_point(point: Vector3) -> Vector2:
	return camera.unproject_position(point)*size/Vector2(viewport.size)


func viewport_point(point: Vector2) -> Vector2:
	return point*Vector2(viewport.size)/size.max(Vector2.ONE)


func _update_framing() -> void:
	if run==null or camera==null or not run.layout.rooms.has(run.current_room): return
	var area := safe_area()
	if area.size.x<32 or area.size.y<32: return
	if run.travel!=null:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 20
		camera.far = 64
		_room_distance = 17.0*maxf(1.0,1.35/maxf(.5,size.x/size.y)); _distance = _room_distance*_zoom
		return
	var center := Vector3(0,.55,0)
	var back := _camera_back()
	var right := Vector3(back.z,0,-back.x).normalized()
	var up := back.cross(right)
	var tan_v := tan(deg_to_rad(camera.fov*.5))
	var tan_h := tan_v*size.x/maxf(1,size.y)
	var fit := 6.0
	var bounds := Rect2(-5,-4,10,8)
	var top := 2.0
	for x in [bounds.position.x,bounds.end.x]:
		for z in [bounds.position.y,bounds.end.y]:
			for y in [-.45,top]:
				var offset := Vector3(x,y,z)-center
				fit = maxf(fit,offset.dot(back)+absf(offset.dot(right))/(tan_h*area.size.x/size.x*.87))
				fit = maxf(fit,offset.dot(back)+absf(offset.dot(up))/(tan_v*area.size.y/size.y*.87))
	_room_distance = fit
	_distance = _room_distance*_zoom


func refresh_run() -> void:
	if _building or world==null or run==null or not run.generation_error.is_empty(): return
	if _loaded_act!=GameState.act_index:
		_building = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var began := Time.get_ticks_usec()
		_loaded_act = GameState.act_index
		_fog_signature = ""
		_selected_cell = Vector2i(-9999,-9999)
		_selected_building.clear()
		for node in room_roots.values(): node.queue_free()
		room_roots.clear()
		for node in cluster_roots.values(): node.queue_free()
		cluster_roots.clear()
		if authored_root!=null: world.remove_child(authored_root); authored_root.queue_free(); authored_root = null
		if bridge_root!=null: world.remove_child(bridge_root); bridge_root.queue_free()
		if marker_root!=null: marker_root.queue_free()
		marker_root = Node3D.new(); world.add_child(marker_root); _gate_markers.clear(); _gate_signature = ""
		style.reset_geometry_tracking()
		await _build_landscape()
		if walker!=null: walker.queue_free()
		walker = TRAVELER.new(); world.add_child(walker); walker.scale = Vector3.ONE*(.40 if run.travel!=null else .25); walker.setup(style)
		walker.position = world_point(run.position)
		_look = walker.position+(Vector3.UP*.55 if run.travel!=null else Vector3.ZERO); _target = _look; _follow = true; _distance = 16
		_update_framing(); _outlines_dirty = true
		_update_camera()
		var outline_began := Time.get_ticks_usec()
		for i in 300:
			if style.refresh_outlines(10.0 if run.travel!=null else 2.0): break
			await get_tree().process_frame
		profile["outline_warmup_ms"] = (Time.get_ticks_usec()-outline_began)/1000.0
		_update_fog()
		if authored_root!=null:
			authored_root.refresh(run,run.layout.point(run.position)); _budget_lights()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
		profile.build_count += 1; profile.assembly_ms = (Time.get_ticks_usec()-began)/1000.0
		_building = false
		state_changed.emit.call_deferred()
	_update_fog()
	if not _moving and walker!=null: walker.position = world_point(run.position)
	var player: Vector2 = run.layout.point(run.position)
	if not run.layout.site.is_empty():
		authored_root.refresh(run,player)
		_budget_lights()
		_update_gate_markers(); _update_camera(); _overlay.queue_redraw()
		return
	for cluster: Dictionary in run.layout.clusters:
		var near: bool = cluster.bounds.grow(16).has_point(player)
		var known: bool = cluster.members.any(func(id): return run.visited_rooms.has(id))
		if not near or not known:
			if cluster_roots.has(cluster.id): cluster_roots[cluster.id].queue_free(); cluster_roots.erase(cluster.id)
			continue
		if not cluster_roots.has(cluster.id):
			var visual := CLUSTER_VISUAL.new(); world.add_child(visual)
			visual.build(cluster,run.layout,style); cluster_roots[cluster.id] = visual
		cluster_roots[cluster.id].update_fog(fog,run.layout.bounds)
		cluster_roots[cluster.id].refresh(run,player)
	for id: String in run.layout.rooms:
		var template: Dictionary = run.layout.rooms[id]
		# 加载和卸载使用不同阈值，避免在边界附近反复 free / rebuild。
		var load_radius := 36.0 if room_roots.has(id) else 28.0
		var close := player.distance_to(template.bounds.get_center())<load_radius
		var seen: bool = run.visited_rooms.has(id)
		var preview: bool = run.next_rooms().has(id)
		if not close or (not seen and not preview):
			if room_roots.has(id): room_roots[id].queue_free(); room_roots.erase(id)
			continue
		if not room_roots.has(id):
			var visual := VISUAL.new()
			var transform: Transform2D = template.transform
			visual.position = Vector3(transform.origin.x,0,transform.origin.y)
			visual.rotation.y = -transform.get_rotation()
			world.add_child(visual)
			visual.build(template,style,camera,environment,ground)
			room_roots[id] = visual
		room_roots[id].visible = true
		room_roots[id].update_state(seen,run.resolved.has(id),id==run.current_room)
		room_roots[id].sync_camera(camera)
	if bridge_network!=null: bridge_network.refresh(player,run)
	_update_gate_markers()
	_update_camera()
	_overlay.queue_redraw()


func _build_landscape() -> void:
	_surface_patches.clear()
	for room: Dictionary in run.layout.rooms.values():
		for prop: Dictionary in room.props:
			var at: Vector2 = room.transform*Vector2(prop.at.x,prop.at.z)
			var patches: Array = []
			if prop.asset=="covered_walk": patches = preload("res://src/expedition/garden_asset_layout.gd").floor_patches("covered_walk")
			else:
				for floor_patch in preload("res://src/expedition/room_interior_assets.gd").floor_patches(prop):
					patches.append({"rect":Rect2(floor_patch.rect.position*prop.scale,floor_patch.rect.size*prop.scale),"height":floor_patch.y*prop.scale,"gradient":Vector2.ZERO})
			for patch in patches:
				patch["origin"] = Vector3(at.x,0,at.y)
				patch["basis"] = Basis(Vector3.UP,-room.transform.get_rotation()+prop.turn)
				_surface_patches.append(patch)
	bridge_root = Node3D.new(); bridge_root.name = "ContinuousGarden"; world.add_child(bridge_root)
	water_paint = ShaderMaterial.new()
	water_paint.shader = preload("res://src/shaders/expedition_water.gdshader")
	var white := Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
	water_paint.set_shader_parameter("fog_mask",ImageTexture.create_from_image(white))
	water_paint.set_shader_parameter("water_tint",Color("102b32"))
	water_paint.set_shader_parameter("fog_color",Color("0a151d"))
	water_paint.set_shader_parameter("clip_vision_bounds",true)
	# The visual water extends beyond the navigable garden; its edge must never
	# form a diagonal cut across the window when viewing the entrance courtyard.
	_plane(bridge_root,run.layout.bounds.grow(80),preload("res://src/expedition/garden_bridge_plan.gd").WATER_Y,water_paint)
	if not run.layout.site.is_empty():
		authored_root = preload("res://src/map/garden_compact_visual.gd").new() if run.layout.compact!=null else preload("res://src/map/authored_garden_visual.gd").new()
		world.add_child(authored_root)
		await authored_root.build(run.layout,style,camera,environment,ground,true)
		bridge_network = null
		return
	bridge_network = preload("res://src/map/garden_bridge_network.gd").new()
	bridge_root.add_child(bridge_network)
	bridge_network.setup(run.layout,run.graph,style,ground)
	_surface_patches.append_array(bridge_network.surface_patches)


func _plane(parent: Node3D, rect: Rect2, y: float, material: Material) -> void:
	var shape := PlaneMesh.new(); shape.size = rect.size
	var node := MeshInstance3D.new(); node.mesh = shape; node.material_override = material
	node.position = Vector3(rect.get_center().x,y,rect.get_center().y); parent.add_child(node)


func _update_fog() -> void:
	if run.travel!=null:
		if _fog_signature=="route-map-open": return
		_fog_signature = "route-map-open"
		var white := Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
		fog = ImageTexture.create_from_image(white)
		var box: Rect2 = run.layout.bounds
		for paint: ShaderMaterial in [ground,water_paint]:
			if paint==null: continue
			paint.set_shader_parameter("fog_mask",fog); paint.set_shader_parameter("vision_origin",box.position); paint.set_shader_parameter("vision_size",box.size)
		if authored_root!=null: authored_root.update_fog(fog,box)
		profile.fog_ms = 0.0
		return
	var signature := str([run.position,run.current_room,run.visited_rooms,run.choices,run.resolved,run.sealed])
	if signature==_fog_signature: return
	_fog_signature = signature
	var began := Time.get_ticks_usec()
	var bounds: Rect2 = run.layout.bounds
	var image := Image.create(ceili(bounds.size.x*2),ceili(bounds.size.y*2),false,Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for id: String in run.visited_rooms:
		var rect: Rect2 = run.layout.rooms[id].bounds.grow(4.0 if not run.layout.site.is_empty() else .65)
		var pixels := Rect2i(Vector2i(((rect.position-bounds.position)*2).floor()),Vector2i((rect.size*2).ceil()))
		image.fill_rect(pixels.intersection(Rect2i(Vector2i.ZERO,image.get_size())),Color(1,1 if id==run.current_room else .25,0))
	# Landscape is revealed around visited courts. The owned walking grid still
	# controls progression: planted ground and pond water never become shortcuts.
	var player: Vector2 = run.layout.point(run.position)
	for cluster: Dictionary in run.layout.clusters:
		var explored: Array = []
		for id in cluster.members:
			if run.visited_rooms.has(id): explored.append(run.layout.rooms[id].bounds.grow(4.0))
		if explored.is_empty(): continue
		var first := Vector2i(((cluster.bounds.position-bounds.position)*2).floor())
		var extent := Vector2i((cluster.bounds.size*2).ceil())
		for y in range(first.y,first.y+extent.y):
			for x in range(first.x,first.x+extent.x):
				if x<0 or y<0 or x>=image.get_width() or y>=image.get_height(): continue
				var point: Vector2 = bounds.position+Vector2(x,y)*.5
				if explored.any(func(rect): return rect.has_point(point)):
					var old := image.get_pixel(x,y)
					image.set_pixel(x,y,Color(1,maxf(old.g,1.0 if point.distance_to(player)<8 else .25),0))
	for cell: Vector2i in run.layout.cells:
		if not run.walkable(cell) or run.layout.cells[cell].edges.is_empty(): continue
		var p: Vector2 = run.layout.point(cell)
		var uv := Vector2i(((p-bounds.position)*2).floor())
		var visible := p.distance_to(run.layout.point(run.position))<12
		if uv.x>=0 and uv.y>=0 and uv.x<image.get_width() and uv.y<image.get_height(): image.set_pixelv(uv,Color(1,1 if visible else .25,0))
	if fog==null: fog = ImageTexture.create_from_image(image)
	else: fog.set_image(image)
	ground.set_shader_parameter("fog_mask",fog)
	ground.set_shader_parameter("vision_origin",bounds.position)
	ground.set_shader_parameter("vision_size",bounds.size)
	if water_paint!=null:
		water_paint.set_shader_parameter("fog_mask",fog)
		water_paint.set_shader_parameter("vision_origin",bounds.position)
		water_paint.set_shader_parameter("vision_size",bounds.size)
	for visual in cluster_roots.values(): visual.update_fog(fog,bounds)
	if authored_root!=null: authored_root.update_fog(fog,bounds)
	profile.fog_ms = (Time.get_ticks_usec()-began)/1000.0


func _update_gate_markers() -> void:
	if run.travel!=null: return # Compact doors are assembled from the controller's exact thresholds.
	var signature := str([run.choices,run.current_room,run.visited_rooms.size()])
	if signature==_gate_signature: return
	_gate_signature = signature
	for child in marker_root.get_children(): marker_root.remove_child(child); child.queue_free()
	# Sealed branch doors at BOTH ends, using the same state as navigation.
	for corridor: Dictionary in run.layout.corridors:
		if not run.sealed.has(corridor.from) and not run.sealed.has(corridor.to): continue
		for id: String in [corridor.from,corridor.to]:
			if run.sealed.has(id): continue
			if not run.visited_rooms.has(id): continue
			# The shared bridgehead remains open. Mark the first actually blocked
			# walking point on this branch, rather than sealing a shared room's only gate.
			var ordered: Array = corridor.points.duplicate()
			if id==corridor.to: ordered.reverse()
			var endpoint: Vector2 = ordered[-1]
			var direction := Vector2.RIGHT
			var found := false
			for i in range(ordered.size()-1):
				var a: Vector2 = ordered[i]; var b: Vector2 = ordered[i+1]
				var distance := a.distance_to(b)
				direction = (b-a).normalized()
				for step_index in range(ceili(distance/.25)+1):
					var p: Vector2 = a+direction*minf(distance,step_index*.25)
					if not run.walkable(run.layout.cell(p)):
						endpoint = p; found = true; break
				if found: break
			var seal_root := Node3D.new(); seal_root.position = Vector3(endpoint.x,0,endpoint.y)
			seal_root.rotation.y = atan2(direction.x,direction.y)
			marker_root.add_child(seal_root)
			var width := 1.28 if not run.layout.site.is_empty() else .79
			var bar := MeshInstance3D.new(); bar.mesh = TypeMeshes.beveled_box(Vector3(width,.66,.09),.012)
			var paint := StandardMaterial3D.new(); paint.albedo_color = Color("712c29")
			bar.material_override = paint; bar.position.y = .33; seal_root.add_child(bar)
			var marker := Label3D.new(); marker.text = "封"; marker.font = Ink.serif; marker.font_size = 64
			marker.modulate = Color("d8b579"); marker.position = Vector3(endpoint.x,.45,endpoint.y)+Vector3(0,0,.06)
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED; marker.no_depth_test = false
			marker_root.add_child(marker)


func walk_to_room(id: String) -> bool:
	if _moving or run.phase!="map" or not run.layout.rooms.has(id): return false
	return walk_to(run.layout.rooms[id].stand_cell)


func walk_to(target: Vector2i) -> bool:
	if _moving: return false
	_route = run.move_path(target)
	if _route.size()<2: return false
	preview_exit("")
	_selected_cell = target
	_route.pop_front(); _moving = true; _leg = 0
	_from = walker.position; _to = world_point(_route[0]); _follow = true; _set_overview(false)
	state_changed.emit()
	return true


func preview_exit(id: String) -> void:
	selected_exit = id; _preview_path.clear()
	if not id.is_empty() and run.next_rooms().has(id): _preview_path = run.move_path(run.layout.rooms[id].stand_cell)
	_overlay.queue_redraw()


func recenter() -> void:
	_follow = true; _zoom = 1.0; _set_overview(false)
	if walker!=null: _target = world_point(run.position)+Vector3.UP*.55
	_update_framing()

func show_overview() -> void:
	_set_overview(not _overview)


func _set_overview(value: bool) -> void:
	if value==_overview: return
	_overview = value
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if value else SubViewport.UPDATE_ALWAYS
	overview_changed.emit()
	_overlay.queue_redraw()


func world_point(cell: Vector2i) -> Vector3:
	var p: Vector2 = run.layout.point(cell)
	var height: float = preload("res://src/expedition/garden_asset_layout.gd").surface_height(_surface_patches,Vector3(p.x,0,p.y))
	return Vector3(p.x,height,p.y)


func _process(delta: float) -> void:
	preload("res://src/map/garden_mesh_library.gd").collect_preloads()
	if _building:
		_overlay.queue_redraw(); return
	if not _active or run==null or walker==null: return
	if _moving:
		_leg = minf(1,_leg+delta/(.22 if run.layout.walk_step>=1 else 1.0/12.0))
		walker.position = _from.lerp(_to,_leg)
		var direction := _to-_from
		if direction.length_squared()>.0001: walker.rotation.y = lerp_angle(walker.rotation.y,atan2(direction.x,direction.z),minf(1,delta*12))
		if _leg>=1:
			_walk_steps += 1
			var previous: String = run.current_room
			if not run.step(_route.pop_front()): _route.clear()
			if run.current_room!=previous: _set_overview(false); refresh_run(); state_changed.emit()
			elif _walk_steps%(3 if run.layout.walk_step>=1 else 12)==0: refresh_run()
			if _route.is_empty() or run.phase!="map":
				_moving = false; _route.clear(); run._save_if_enabled(); _update_fog(); state_changed.emit(); arrived.emit()
			else: _from = walker.position; _to = world_point(_route[0]); _leg = 0
	if _overview:
		_overlay.queue_redraw()
		return
	if bridge_network!=null: bridge_network.update_roofs(Vector2(walker.position.x,walker.position.z))
	if authored_root!=null: authored_root.update_occlusion(walker.position)
	# Idle frames, especially the first frame after rewards, must not invent a
	# new camera correction after the cached view has frozen its exact framing.
	if _follow and _moving: _follow_deadzone()
	if _look.distance_squared_to(_target)>.000001: _look = _look.lerp(_target,1-exp(-delta/.18))
	elif _look!=_target: _look = _target
	var changed := not _last_camera.is_equal_approx(_look) or not is_equal_approx(_last_distance,_distance)
	_update_camera()
	if run.layout.compact!=null and authored_root!=null:
		authored_root.update_view(Vector2(_look.x,_look.z),_follow)
		if authored_root.get_meta("lights_dirty",false):
			_budget_lights(); authored_root.set_meta("lights_dirty",false)
	_outline_tick += delta
	if _outline_tick>.12 and (changed or _outlines_dirty or style.outline_refresh_in_progress()):
		_outline_tick = 0
		for visual in room_roots.values(): visual.update_occlusion(walker.global_position,camera)
		var began := Time.get_ticks_usec()
		_outlines_dirty = not style.refresh_outlines(.8 if mobile_quality else 1.5)
		profile.outline_ms = (Time.get_ticks_usec()-began)/1000.0
	if changed or _moving: _overlay.queue_redraw()


func _follow_deadzone() -> void:
	var area := safe_area()
	var half := area.size*(Vector2(.24,.20) if run.travel!=null else Vector2(.4,.36))*.5
	var at := screen_point(walker.position+Vector3.UP*.55)
	var desired := at.clamp(area.get_center()-half,area.get_center()+half)
	if at.distance_to(desired)<.5: return
	# Derive the correction from the current target camera; do not accumulate
	# another offset while the previous smooth correction is still in flight.
	var shift := _ground_at(at)-_ground_at(desired)
	_target = _look+Vector3(shift.x,0,shift.z)


func _ground_at(pixel: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(viewport_point(pixel))
	var ray := camera.project_ray_normal(viewport_point(pixel))
	return origin-ray*origin.y/ray.y if ray.y<-.001 else origin


func set_active(value: bool) -> void:
	_active = value
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value and not _overview else SubViewport.UPDATE_DISABLED
	if not value:
		_touches.clear(); _mouse_down = false; _pan = false
		_target = _look # Do not resume a pre-battle interpolation after rewards.


func _budget_lights() -> void:
	var candidates: Array = []
	for lamp: OmniLight3D in world.find_children("*","OmniLight3D",true,false):
		lamp.shadow_enabled = false
		if lamp.visible and lamp.get_parent().is_visible_in_tree() and lamp.light_energy>.01: candidates.append(lamp)
	var player := world_point(run.position)
	candidates.sort_custom(func(a,b):return a.global_position.distance_squared_to(player)<b.global_position.distance_squared_to(player))
	for i in candidates.size(): candidates[i].visible = i<(2 if mobile_quality else 4)
	profile["active_local_lights"] = mini(candidates.size(),2 if mobile_quality else 4)


func _update_camera() -> void:
	if camera==null or size.y<1: return
	if _last_camera.is_equal_approx(_look) and is_equal_approx(_last_distance,_distance) and _last_safe.is_equal_approx(safe_area()): return
	_last_camera = _look; _last_distance = _distance; _last_safe = safe_area()
	var back := _camera_back()
	var right := Vector3(back.z,0,-back.x).normalized()
	var up := back.cross(right)
	var delta := size*.5-safe_area().get_center()
	var scale_value := camera.size/size.y if camera.projection==Camera3D.PROJECTION_ORTHOGONAL else 2*_distance*tan(deg_to_rad(camera.fov*.5))/size.y
	var aim := _look+(right*delta.x-up*delta.y)*scale_value
	camera.position = aim+back*_distance
	camera.look_at(aim,Vector3.UP)


func _camera_back() -> Vector3:
	# The route atlas keeps a high readable angle; close rooms use a lower,
	# lightly turned perspective so roofs have visible south-facing depth.
	var pitch := deg_to_rad(43.0 if run!=null and run.travel!=null else 34.0)
	var yaw := deg_to_rad(16.0 if run!=null and run.travel!=null else 16.0)
	return Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))


func _gui_input(event: InputEvent) -> void:
	if _interaction_blocked or not _active or run==null or walker==null: return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size()==1: _touch_start = event.position; _touch_dragged = false
			elif _touches.size()==2:
				var values: Array = _touches.values()
				_pinch_distance = values[0].distance_to(values[1]); _pinch_zoom = _zoom; _touch_dragged = true
		else:
			if _touches.size()==1 and not _touch_dragged: _tap(event.position)
			_touches.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size()==2:
			var values: Array = _touches.values()
			_zoom = clampf(_pinch_zoom*_pinch_distance/maxf(1,values[0].distance_to(values[1])),.72,1.4)
			_update_framing(); _overlay.queue_redraw()
		elif not _overview and event.position.distance_to(_touch_start)>12:
			_touch_dragged = true; _drag_map(event.position,event.relative)
		accept_event()
	elif event is InputEventMouseButton:
		if event.device==-1: return # Touch emulation is handled once above.
		if event.button_index==MOUSE_BUTTON_MIDDLE: _pan = event.pressed and not _overview
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if _overview:
				if run.travel==null and event.button_index==MOUSE_BUTTON_WHEEL_UP: recenter()
			else:
				_zoom = clampf(_zoom*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.72,1.4)
				_update_framing(); _overlay.queue_redraw()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: _mouse_down = true; _mouse_dragged = false; _mouse_start = event.position
			else:
				if _mouse_down and not _mouse_dragged: _tap(event.position)
				_mouse_down = false
	elif event is InputEventMouseMotion:
		if _pan or (_mouse_down and event.position.distance_to(_mouse_start)>12):
			_mouse_dragged = true
			if not _overview: _drag_map(event.position,event.relative)


func _drag_map(at: Vector2, relative: Vector2) -> void:
	_follow = false
	_target += _ground_at(at-relative)-_ground_at(at)


func _tap(at: Vector2) -> void:
	if _overview:
		var id: String = ATLAS.pick(run,at,overview_area())
		if run.travel!=null:
			if not id.is_empty(): node_selected.emit(id)
			return
		if id==run.current_room: recenter()
		elif run.next_rooms().has(id) or run.visited_rooms.has(id): walk_to_room(id)
		return
	for id: String in _label_hits:
		if _label_hits[id].has_point(at):
			if id!=run.current_room:
				if run.travel!=null: exit_selected.emit(id)
				else: walk_to_room(id)
			return
	var foot := screen_point(walker.position)
	var head := screen_point(walker.position+Vector3.UP*(1.4 if run.travel!=null else .95))
	if Rect2(foot,Vector2.ZERO).expand(head).grow(22).has_point(at): walker_pressed.emit(); return
	var hit := _ground_at(at)
	if hit.distance_to(walker.position)<.45: walker_pressed.emit(); return
	if run.travel!=null:
		var cell: Vector2i = run.layout.cell(Vector2(hit.x,hit.z))
		var owner: String = run.layout.compact.cells.get(cell,"")
		if not owner.is_empty() and owner!=run.current_room:
			if run.next_rooms().has(owner): exit_selected.emit(owner)
			return
		# Floor clicks are actual grid movement, including doors and shared
		# approaches. The forward-travel controller closes the door on crossing.
		# Sign clicks offer a preview; walking never requires opening the atlas.
	if authored_root!=null:
		for house in authored_root.houses:
			var title := str(house.node.get_meta("building_name",""))
			if not title.is_empty() and house.node.is_visible_in_tree() and house.bounds.has_point(Vector2(hit.x,hit.z)):
				_selected_building = {"name":title,"at":house.bounds.get_center()}; _overlay.queue_redraw(); break
	walk_to(run.layout.cell(Vector2(hit.x,hit.z)))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed: _release_touch.call_deferred(event.index)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: _release_mouse.call_deferred()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE and not event.pressed: _pan = false
	if _interaction_blocked: return
	if _overview and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		recenter()
		get_viewport().set_input_as_handled()


func _release_touch(index: int) -> void:
	_touches.erase(index)


func _release_mouse() -> void:
	_mouse_down = false


func draw_overlay(canvas: Control) -> void:
	if run==null or camera==null or run.generation_error!="": return
	if _building or walker==null:
		canvas.draw_rect(Rect2(Vector2.ZERO,size),Color("0b171b"))
		var progress: float = authored_root.progress if authored_root!=null else .0
		canvas.draw_string(Ink.serif,size*.5+Vector2(-75,0),"入园 · %d%%" % roundi(progress*100),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("c4af87"))
		return
	_label_hits.clear()
	if _overview:
		ATLAS.draw(canvas,run,overview_area()); return
	if _moving:
		var line := PackedVector2Array([screen_point(walker.position+Vector3.UP*.03)])
		for cell: Vector2i in _route: line.append(screen_point(world_point(cell)+Vector3.UP*.03))
		if line.size()>1: canvas.draw_polyline(line,Color(.77,.65,.39,.75),2,true)
	elif _preview_path.size()>1:
		var line := PackedVector2Array()
		for cell: Vector2i in _preview_path: line.append(screen_point(world_point(cell)+Vector3.UP*.04))
		canvas.draw_polyline(line,Color(.84,.68,.36,.82),3,true)
	if _selected_cell!=Vector2i(-9999,-9999):
		var position := world_point(_selected_cell)+Vector3.UP*.035
		var corners := PackedVector2Array()
		var half: float = run.layout.walk_step*.43
		for offset in [Vector3(-half,0,-half),Vector3(half,0,-half),Vector3(half,0,half),Vector3(-half,0,half),Vector3(-half,0,-half)]: corners.append(screen_point(position+offset))
		canvas.draw_polyline(corners,Color("bba16b"),2,true)
	var ids: Array = [run.current_room]+run.next_rooms()
	var exits := {}
	for option: Dictionary in EXITS.options(run): exits[option.id] = option
	var occupied: Array = ui_exclusions.duplicate()
	var foot := screen_point(walker.position)
	occupied.append(Rect2(foot-Vector2(23,75),Vector2(46,80)))
	for id: String in ids:
		var room: Dictionary = run.layout.rooms[id]
		var world_at := Vector3(room.stand.x,1.5,room.stand.y)
		if exits.has(id):
			var anchor: Vector2i = exits[id].anchor
			world_at = Vector3(anchor.x,.4,anchor.y)
		if camera.is_position_behind(world_at): continue
		var at := screen_point(world_at)
		if not Rect2(Vector2.ZERO,size).has_point(at): continue
		var title: String = room.role if run.travel!=null else room.name
		var subtitle: String = run.LABELS[room.kind]+(" · 已过" if run.resolved.has(id) else (" · 当前" if id==run.current_room else " · 可前往"))
		if run.travel!=null and id==run.current_room and run.phase=="map": subtitle = "点砖行走 · 出门后不回头"
		if exits.has(id):
			title = "%02d · %s" % [room.number,run.LABELS[room.kind]]
			subtitle = "后续："+EXITS.following(run,id)
			if not run.planned_route.is_empty() and run.planned_route[0]==id: title += " ◇"
		var width := clampf(Ink.serif.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x+24,112,240)
		width = maxf(width,minf(250,Ink.serif.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+24))
		var extent := Vector2(width,60)
		var box := Rect2()
		for offset in [Vector2(16,-70),Vector2(-width-16,-70),Vector2(-width*.5,-130),Vector2(16,10),Vector2(-width-16,10)]:
			var candidate := Rect2((at+offset).clamp(safe_area().position,safe_area().end-extent),extent)
			if not occupied.any(func(other): return candidate.intersects(other)):
				box = candidate; break
		if not box.has_area(): continue
		occupied.append(box.grow(4)); _label_hits[id] = box
		canvas.draw_line(at,box.get_center(),Color(.6,.5,.33,.6),1,true)
		canvas.draw_rect(box,Color(.025,.045,.05,.94))
		canvas.draw_line(box.position,box.position+Vector2(box.size.x,0),Color("a18150"),1.5,true)
		if id==selected_exit: canvas.draw_rect(box,Color("d3aa62"),false,2)
		canvas.draw_string(Ink.serif,box.position+Vector2(12,25),title,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("d8c99e"))
		canvas.draw_string(Ink.serif,box.position+Vector2(12,48),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ac9874"))
	if not _selected_building.is_empty() and not ids.any(func(id):return run.layout.rooms[id].name==_selected_building.name):
		var at: Vector2 = screen_point(Vector3(_selected_building.at.x,2.7,_selected_building.at.y))
		if safe_area().has_point(at):
			var text: String = _selected_building.name
			var width := Ink.serif.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x+24
			var box := Rect2((at-Vector2(width*.5,30)).clamp(safe_area().position,safe_area().end-Vector2(width,48)),Vector2(width,48))
			if not occupied.any(func(other):return box.intersects(other)):
				canvas.draw_rect(box,Color(.025,.045,.05,.94)); canvas.draw_string(Ink.serif,box.position+Vector2(12,30),text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("d8c99e"))
