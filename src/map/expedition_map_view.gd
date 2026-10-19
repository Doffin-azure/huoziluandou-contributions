extends Control
class_name ExpeditionMapView
## Continuous painted terrain, native inked props and camera-facing actors.
signal cell_pressed(k: int)
signal cell_hovered(k: int)
signal walker_pressed
signal layout_changed

const PITCH := 45.0
const FOV := 25.0
const DEFAULT_DISTANCE := 10.7
const MIN_DISTANCE := 7.0
const MAX_DISTANCE := 34.0
const PAPER := JourneyStyle.TEXT
const GOLD := JourneyStyle.GOLD
const RED := JourneyStyle.RED
const WALK_SURFACES = preload("res://src/expedition/garden_asset_layout.gd")
const NODE_TIP := {"起":"起点", "大":"大赏：打开会立刻惊动首领", "中":"中赏", "小":"小赏", "休":"息灯亭：治疗／删字／修饰三选一，耗3步", "市":"青铜字摊", "谜":"问字龛：风险换资源", "敌":"巡守：看守周围散字", "险":"精英镇守", "巢":"首领巢穴"}

var expedition: Expedition
var viewport: SubViewport
var camera: Camera3D
var terrain: ExpeditionTerrain
var hover_cell := -1
var path_cells: Array = []
var following := true
var overview := false
var player_actor: Node3D
var boss_actor: Node3D
var boss_tween: Tween
var environment: Environment
var mist_volume: FogVolume
var _mist_paint: ShaderMaterial
var _factory: ExpeditionMapProps
var _style: ExpeditionFlatStyle
var _art: ExpeditionMapArt
var _garden_scenery: Node3D
var _outline_pending := false
var _outline_clock := 0.0
var _outline_generation := 0
var _outline_sweep_generation := 0
var _occlusion_dirty := true
var _world: Node3D
var _map_root: Node3D
var _entity_root: Node3D
var _marker_root: Node3D
var _overlay: MapOverlay
var _display: TextureRect
var _cell_nodes: Dictionary = {}
var _cell_states: Dictionary = {}
var _barriers: Array = []
var _occlusion: Dictionary = {}
var _foregrounds: Array[Node3D] = []
var _map_id := ""
var _shown_player := -1
var _shown_boss := -1
var _player_tween: Tween
var _walking_surfaces: Array[Dictionary] = []
var _look := Vector3(6, 0, 4)
var _look_target := Vector3(6, 0, 4)
var _distance := DEFAULT_DISTANCE
var _distance_target := DEFAULT_DISTANCE
var _panning := false
var _last_pointer := Vector2.ZERO
var _camera_dirty := true
var _clock := 0.0


func _init() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(320,240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_resize)
	mouse_exited.connect(func(): set_hover(-1))


func _ready() -> void:
	_factory = ExpeditionMapProps.new(PITCH)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.positional_shadow_atlas_size = 1024
	add_child(viewport)
	_display = TextureRect.new()
	_display.texture = viewport.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)
	_world = Node3D.new()
	viewport.add_child(_world)
	var world_environment := WorldEnvironment.new()
	var settings := Environment.new()
	var colors: ExpeditionFlatPalette = preload("res://assets/expedition/palettes/mochi_night.tres").duplicate(true)
	environment = settings
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = colors.background
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = preload("res://assets/expedition/sky/mochi_night.svg")
	var sky := Sky.new()
	sky.sky_material = panorama
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("345358")
	settings.ambient_light_energy = .20
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Match the title and reward pigments: preserve cinnabar/teal hues in
	# linear tonemapping, keeping the night value range in the lights instead.
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	settings.tonemap_exposure = 1.0
	settings.glow_enabled = true
	settings.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	settings.glow_intensity = .20
	settings.glow_strength = .7
	settings.glow_hdr_threshold = 1.15
	# The fog shader reads Expedition's explored/visible mask. Visible areas
	# clear completely; dense unknown banks sit above an opaque sight cover.
	settings.volumetric_fog_enabled = RenderingServer.get_current_rendering_method()=="forward_plus"
	settings.volumetric_fog_density = 0.0
	settings.volumetric_fog_length = 45.0
	settings.volumetric_fog_gi_inject = 0.0
	settings.volumetric_fog_temporal_reprojection_amount = .75
	world_environment.environment = settings
	_world.add_child(world_environment)
	for entry in [["fff1d9",.82,Vector3(-48,-32,0),true],["83a1b4",.18,Vector3(-25,145,0),false],["c6b18e",.06,Vector3(-22,25,0),false]]:
		var light := DirectionalLight3D.new()
		light.light_color = Color(entry[0])
		light.light_energy = entry[1]
		light.rotation_degrees = entry[2]
		light.shadow_enabled = entry[3]
		light.directional_shadow_max_distance = 45
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.shadow_bias = .06
		light.shadow_normal_bias = 1.5
		light.light_volumetric_fog_energy = .35
		_world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = FOV
	camera.near = 0.12
	camera.far = 80
	camera.current = true
	_world.add_child(camera)
	_style = ExpeditionFlatStyle.new(colors)
	_style.set_scene_lighting(true)
	_style.camera = camera
	_art = ExpeditionMapArt.new(_style,camera,settings)
	_factory.map_art = _art
	_overlay = MapOverlay.new()
	_overlay.view = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_resize()
	_apply_camera()
	if expedition != null: refresh(expedition)


func _exit_tree() -> void:
	if _style!=null: _style.dispose()


func _resize() -> void:
	if viewport == null: return
	viewport.size = Vector2i(maxi(16,int(size.x)),maxi(16,int(size.y)))
	_camera_dirty = true
	if overview: show_overview()
	layout_changed.emit()


static func world_position(k: int, y := 0.0) -> Vector3:
	var rc := MapGen.rc(k)
	return Vector3(rc.y+0.5,y,rc.x+0.5)


func _on_surface(point: Vector3, lift := 0.0) -> Vector3:
	return Vector3(point.x,WALK_SURFACES.surface_height(_walking_surfaces,point)+lift,point.z)


func surface_position(k: int, lift := 0.0) -> Vector3:
	return _on_surface(world_position(k),lift)


func cell_center(k: int) -> Vector2:
	if camera == null: return Vector2.ZERO
	return camera.unproject_position(surface_position(k)) * size / Vector2(viewport.size)


func ground_at(point: Vector2) -> Vector3:
	if camera == null: return Vector3.INF
	var pixel := point * Vector2(viewport.size) / size.max(Vector2.ONE)
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	return WALK_SURFACES.ray_surface(_walking_surfaces,origin,direction)


func cell_at(point: Vector2) -> int:
	if not Rect2(Vector2.ZERO,size).has_point(point): return -1
	var hit := ground_at(point)
	if not hit.is_finite(): return -1
	var r := floori(hit.z)
	var c := floori(hit.x)
	return MapGen.kk(r,c) if MapGen.inb(r,c) else -1


func set_hover(k: int) -> void:
	if k == hover_cell: return
	hover_cell = k
	cell_hovered.emit(k)
	_update_markers()


func _get_tooltip(at_position: Vector2) -> String:
	if walker_at(at_position): return "查看行囊"
	return str(cell_info(pick_cell(at_position)).get("tip",""))


func walker_at(point: Vector2) -> bool:
	if player_actor==null or camera==null: return false
	var pixel := point*Vector2(viewport.size)/size.max(Vector2.ONE)
	var sprite: Sprite3D = player_actor.get_child(0)
	var height: float = player_actor.get_meta("card_height")
	var width: float = player_actor.get_meta("card_width")
	var center := camera.unproject_position(sprite.global_position)
	var top := camera.unproject_position(sprite.global_position+camera.global_basis.y*height*.5)
	var side := camera.unproject_position(sprite.global_position+camera.global_basis.x*width*.5)
	var rect := Rect2(Vector2(center.x-absf(side.x-center.x),top.y),Vector2(absf(side.x-center.x)*2,absf(center.y-top.y)*2))
	return rect.has_point(pixel) and _factory.opaque_at(sprite.texture,(pixel-rect.position)/rect.size)


func pick_cell(point: Vector2) -> int:
	var floor_cell := cell_at(point)
	if camera == null or not Rect2(Vector2.ZERO,size).has_point(point): return -1
	var pixel := point * Vector2(viewport.size) / size.max(Vector2.ONE)
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	var closest := INF
	var result := floor_cell
	# Keep the centre of every reachable ground cell available even when a roof
	# projects across it. Clicking the remaining structure selects its own foot.
	if floor_cell>=0 and expedition!=null and expedition.can_step(floor_cell):
		var floor_hit := ground_at(point)
		if floor_hit.distance_to(surface_position(floor_cell))<0.33: return floor_cell
	for k in _cell_nodes:
		var root: Node3D = _cell_nodes[k]
		if not root.has_meta("pick_height") or _occlusion.get(k,false): continue
		if root.has_meta("card_texture"):
			var height: float = root.get_meta("card_height")
			var width: float = root.get_meta("card_width")
			var foot := camera.unproject_position(root.position)
			var top := camera.unproject_position(root.position+camera.global_basis.y*height)
			var side := camera.unproject_position(root.position+camera.global_basis.x*width*0.5)
			var rect := Rect2(Vector2(foot.x-absf(side.x-foot.x),top.y),Vector2(absf(side.x-foot.x)*2,foot.y-top.y)).abs()
			if not rect.has_point(pixel): continue
			if not _factory.opaque_at(root.get_meta("card_texture"),(pixel-rect.position)/rect.size): continue
			var depth := camera.global_basis.z.dot(root.position-origin)/camera.global_basis.z.dot(direction)
			if depth>=0 and depth<closest:
				closest = depth
				result = k
			continue
		var dimensions: Vector3 = root.get_meta("pick_size",Vector3(.72,float(root.get_meta("pick_height")),.6))
		var offset: Vector3 = root.get_meta("pick_offset",Vector3.ZERO)
		var bounds := AABB(root.position+offset-Vector3(dimensions.x*.5,0,dimensions.z*.5),dimensions)
		var hit: Variant = bounds.intersects_ray(origin,direction)
		if hit is Vector3 and origin.distance_to(hit)<closest:
			closest = origin.distance_to(hit)
			result = k
	return result


func cell_info(k: int) -> Dictionary:
	if expedition == null or k < 0 or k >= MapGen.N: return {}
	var ex := expedition
	var known := ex.explored.has(k)
	var node: Dictionary = ex.m.node.get(k,{})
	var mc := ex.mech_at(k)
	var text := ""
	var tip := ""
	if not known:
		if ex.is_beacon(k):
			text = "◇"
			tip = "隔雾信标：" + str(NODE_TIP.get(node.get("t",""),""))
	elif ex.m.ink[k] != 0:
		tip = "建筑基座：不可通行" if ex.m.has("layout") and ex.m.layout.terrain_base[k]==2 else "墨池：不可通行"
	elif ex.m.obst.has(k):
		text = "障"
		tip = "墨障：花%d墨冲开，墨不够以血冲开" % Expedition.BARRIER_INK
	elif not mc.is_empty():
		text = str(mc.g)
		tip = ("关着 · " if mc.kind == "gate" and ex.gate_shut(k,ex.t) else "") + str(mc.desc)
		if mc.kind == "wire" and not ex.mover_live(k,ex.t): tip = "没电 · " + tip
		if mc.kind == "hoist" and ex.used.has(k): tip += " · 已使用"
	elif not node.is_empty():
		text = str(node.get("t",""))
		tip = str(NODE_TIP.get(text,text))
		if ex.taken.has(k) and text in ["休","谜","大","中","小"]: tip += " · 已使用"
	elif ex.m.glyph.has(k) and not ex.taken.has(k):
		text = str(ex.m.glyph[k])
		var guard := ex.guard_of(k)
		tip = "散字【%s】" % text + ("：被%s看守" % guard if not guard.is_empty() else "：走过去拾取")
	if known and ex.sealed(k) and not ex.taken.has(k): tip += " · 伏兵封印"
	var amb := ex.ambush_index_at(k)
	if amb >= 0 and ex.fight.get("kind","") == "ambush" and int(ex.fight.amb) == amb:
		text = "伏"
		tip = "伏兵从这里杀出来了"
	elif amb >= 0 and ex.amb_done.has(amb):
		text = "✕"
		tip = "已击退的伏兵"
	elif known and ex.revealed_amb_at(k):
		text = "伏"
		tip = "伏兵在这里"
	return {"text":text,"tip":tip,"known":known}


func refresh(ex: Expedition, boss_steps: Array = []) -> void:
	expedition = ex
	if not is_node_ready(): return
	var identity := str(hash([ex.run_seed,ex.act,ex.m.tn,ex.m.ink,ex.m.get("seed",0),ex.m.get("generation_version","legacy")]))
	if identity != _map_id:
		_map_id = identity
		_rebuild_world()
	terrain.update_fog(ex)
	if _garden_scenery!=null: _garden_scenery.sync(ex)
	_sync_entities()
	_sync_actors(boss_steps)
	path_cells = ex.boss_path()
	_update_markers()
	_outline_pending = true
	_outline_generation += 1
	_occlusion_dirty = true
	_overlay.queue_redraw()


func _rebuild_world() -> void:
	# Method tweeners retain their bound actor. Stop them before replacing the
	# world, otherwise a fast act/theme switch can call a freed actor next frame.
	if _player_tween!=null: _player_tween.kill()
	if boss_tween!=null: boss_tween.kill()
	_player_tween = null
	boss_tween = null
	_style.reset_geometry_tracking()
	_art.reset_material_tracking()
	_walking_surfaces = WALK_SURFACES.surface_patches(expedition.m)
	if _map_root != null:
		_world.remove_child(_map_root)
		_map_root.queue_free()
	_map_root = Node3D.new()
	_world.add_child(_map_root)
	_cell_nodes.clear()
	_cell_states.clear()
	_occlusion.clear()
	_foregrounds.clear()
	_garden_scenery = null
	_barriers = expedition.m.obst.keys()
	terrain = ExpeditionTerrain.new()
	_map_root.add_child(terrain)
	terrain.build(expedition.m,_factory)
	_art.ground_material = terrain.ground_material
	mist_volume = FogVolume.new()
	mist_volume.name = "ExplorationFog"
	mist_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	mist_volume.size = Vector3(20,3.4,16)
	mist_volume.position = Vector3(6,.70,4)
	_mist_paint = ShaderMaterial.new()
	_mist_paint.shader = preload("res://src/shaders/expedition_low_mist.gdshader")
	_mist_paint.set_shader_parameter("fog_mask",terrain.fog_texture)
	_mist_paint.set_shader_parameter("clip_vision_bounds",true)
	_mist_paint.set_shader_parameter("mist_color",_style.palette.mist)
	mist_volume.material = _mist_paint
	_map_root.add_child(mist_volume)
	_entity_root = Node3D.new()
	_map_root.add_child(_entity_root)
	_marker_root = Node3D.new()
	_map_root.add_child(_marker_root)
	player_actor = _factory.actor(_map_root,0,0.70)
	player_actor.name = "LanternWalker"
	player_actor.position = surface_position(expedition.pos)
	# The walker stands just ahead of a facility sharing its logical foot cell.
	(player_actor.get_child(0) as Sprite3D).position += Vector3(0,sin(deg_to_rad(PITCH)),cos(deg_to_rad(PITCH)))*0.025
	var lantern_glow := _factory.glow(player_actor,0.62,Color(0.95,0.62,0.19,0.27))
	lantern_glow.position += Vector3(0.19,0.003,0.02)
	var walker_lamp := OmniLight3D.new()
	walker_lamp.position = Vector3(.18,.35,.12)
	walker_lamp.light_color = Color("ffbd78")
	walker_lamp.light_energy = .70
	walker_lamp.omni_range = 1.15
	walker_lamp.light_volumetric_fog_energy = .65
	player_actor.add_child(walker_lamp)
	boss_actor = _factory.actor(_map_root,3,1.05)
	boss_actor.name = "RoamingBoss"
	boss_actor.position = surface_position(expedition.boss)
	_shown_player = expedition.pos
	_shown_boss = expedition.boss
	_make_scenery()
	following = true
	overview = false
	_distance = DEFAULT_DISTANCE
	_distance_target = DEFAULT_DISTANCE
	_look = world_position(expedition.pos)
	_look_target = _look
	_apply_camera()


func _sync_entities() -> void:
	var ex := expedition
	for k in MapGen.N:
		var amb := ex.ambush_index_at(k)
		var signature := str([ex.explored.has(k),ex.taken.has(k),ex.used.get(k,0),ex.m.obst.has(k),ex.sealed(k),ex.m.glyph.get(k,""),ex.gate_shut(k,ex.t),ex.mover_live(k,ex.t),cell_info(k).text])
		if _cell_states.get(k,"") == signature:
			if _cell_nodes.has(k): _shade_cell(_cell_nodes[k],ex.visible.has(k))
			continue
		_cell_states[k] = signature
		_occlusion.erase(k)
		if _cell_nodes.has(k):
			var old: Node3D = _cell_nodes[k]
			_entity_root.remove_child(old)
			old.queue_free()
			_cell_nodes.erase(k)
		var marker_only := not ex.explored.has(k)
		if marker_only: continue
		var holder := Node3D.new()
		holder.position = surface_position(k)
		holder.set_meta("k",k)
		_entity_root.add_child(holder)
		_cell_nodes[k] = holder
		if ex.m.ink[k] != 0:
			# Isolated worn stelae stand on exposed plinths, never floating in ink.
			if not ex.m.has("layout") and k%7==0:
				_art.box(holder,Vector3(0,-.19,0),Vector3(.64,.40,.55),"architecture",.35)
				_art.tomb(holder,k%4,.43)
				holder.set_meta("tall",true)
				holder.set_meta("visual_height",.85)
			_shade_cell(holder,ex.visible.has(k))
			continue
		var node: Dictionary = ex.m.node.get(k,{})
		var type := str(node.get("t",""))
		var taken := ex.taken.has(k)
		var mc := ex.mech_at(k)
		if not type.is_empty() or ex.m.glyph.has(k) or not mc.is_empty() or ex.m.obst.has(k): holder.set_meta("pick_height",0.45)
		if not mc.is_empty(): _factory.mechanism(holder,mc,int(ex.used.get(k,0))>0,ex.gate_shut(k,ex.t) or not ex.mover_live(k,ex.t))
		if ex.m.obst.has(k):
			_factory.barrier(holder,false)
		elif k in _barriers:
			_factory.barrier(holder,true)
		else:
			if type in ["小","中","大"]: _factory.chest(holder,{"小":0,"中":1,"大":2}[type],taken)
			elif type in ["起","休","市","谜","巢"]:
				_factory.facility(holder,type,taken,node.get("mount_offset",Vector3.ZERO),float(node.get("mount_turn",0)))
			elif type in ["敌","险"] and not taken: _factory.actor(holder,1 if type=="敌" else 2,0.72 if type=="敌" else 0.88)
			if ex.m.glyph.has(k) and not taken: _factory.glyph(holder,str(ex.m.glyph[k]),not ex.guard_of(k).is_empty())
			# Sparse decoration stays in the corner of genuinely empty floor cells.
			if not ex.m.has("layout") and type.is_empty() and mc.is_empty() and not ex.m.glyph.has(k) and k%17==5:
				var decor := Node3D.new()
				decor.position = Vector3(-.31,0,-.29)
				holder.add_child(decor)
				_art.tomb(decor,k%4,.28)
		if ex.sealed(k) and not taken and (not node.is_empty() or ex.m.glyph.has(k)):
			_factory.label(holder,"封",Vector3(0.26,0.50,0.22),RED,38,0.006)
		if amb >= 0 and ex.amb_done.has(amb):
			_factory.label(holder,"✕",Vector3(0,0.05,0),RED.darkened(0.2),40,0.008)
		elif str(cell_info(k).text) == "伏":
			_factory.label(holder,"伏",Vector3(0,0.67,0),RED,40,0.008)
		_shade_cell(holder,ex.visible.has(k))


func _shade_cell(holder: Node3D, lit: bool) -> void:
	if holder.has_meta("in_sight") and holder.get_meta("in_sight")==lit: return
	holder.set_meta("in_sight",lit)
	_art.shade(holder,1.0 if lit else .48)


func _sync_actors(boss_steps: Array) -> void:
	if expedition.pos != _shown_player:
		if _player_tween != null: _player_tween.kill()
		_player_tween = create_tween()
		_player_tween.tween_method(_move_on_surface.bind(player_actor,player_actor.position,surface_position(expedition.pos)),0.0,1.0,0.18).set_trans(Tween.TRANS_SINE)
		_shown_player = expedition.pos
		following = true
		overview = false
		_distance_target = minf(_distance_target,DEFAULT_DISTANCE*1.5)
	if expedition.boss != _shown_boss:
		if boss_tween != null: boss_tween.kill()
		boss_tween = create_tween()
		var steps := boss_steps.duplicate()
		if steps.is_empty(): steps.append(expedition.boss)
		var previous := boss_actor.position
		for k in steps:
			var next := surface_position(k)
			boss_tween.tween_method(_move_on_surface.bind(boss_actor,previous,next),0.0,1.0,0.14).set_trans(Tween.TRANS_SINE)
			previous = next
		_shown_boss = expedition.boss
	_factory.tint_tree(boss_actor,Color.WHITE if expedition.awake() else Color("9ca89e"))
	# Match the gameplay reveal rule: hidden while asleep, shown once stirred,
	# and removed immediately after the boss fight is won.
	boss_actor.visible = expedition.boss_revealed()
	if boss_actor.visible and not expedition.visible.has(expedition.boss): _factory.tint_tree(boss_actor,Color(.48,.48,.48))


func _move_on_surface(amount: float, actor: Node3D, from: Vector3, to: Vector3) -> void:
	actor.position = _on_surface(from.lerp(to,amount))


func _make_scenery() -> void:
	_garden_scenery = load("res://src/map/expedition_garden_scenery.gd").new()
	_map_root.add_child(_garden_scenery)
	_garden_scenery.setup(expedition,_art)
	_foregrounds.append_array(_garden_scenery.fade_roots)
	if expedition.m.has("layout"): return
	# Hand-placed presentation coordinates do not consume the expedition RNG.
	# Different world depths provide real parallax when following or dragging.
	for item in [[-1.25,-1.6,.95],[3.7,-2.0,.80],[9.0,-2.2,.95],[13.4,-.7,1.0],[-1.2,4.5,.72],[13.3,5.2,.80],[-1.1,9.3,1.12],[12.9,9.7,1.2]]:
		var decor := Node3D.new()
		decor.position = Vector3(item[0],0,item[1])
		_map_root.add_child(decor)
		_support_scenery(decor,Vector2(.95,.78))
		_art.tree(decor,item[2])
		if float(item[1])<0: _art.shade(decor,.74)
		if float(item[1]) > 8:
			decor.set_meta("height",2.15*float(item[2]))
			_foregrounds.append(decor)
	for i in 8:
		var grave := Node3D.new()
		grave.position = Vector3(-1.15 if i<4 else 13.15,0,.6+(i%4)*1.8)
		_map_root.add_child(grave)
		_support_scenery(grave,Vector2(.75,.65))
		_art.tomb(grave,i%4,.50)
		grave.rotation_degrees.y = -12 if i%2 else 9
	for x in [1.0,11.0]:
		var gate := Node3D.new()
		gate.position = Vector3(x,0,-1.35)
		_map_root.add_child(gate)
		_support_scenery(gate,Vector2(1.8,1.15))
		_art.facility(gate,"巢",false,false)
		_art.shade(gate,.68)
	for x in [-.7,12.7]:
		var lamp := Node3D.new()
		lamp.position = Vector3(x,0,8.75)
		_map_root.add_child(lamp)
		_support_scenery(lamp,Vector2(.60,.60))
		_art.lamp(lamp,.68)
		lamp.set_meta("height",1.15)
		_foregrounds.append(lamp)
	var fire := Node3D.new()
	fire.position = Vector3(12.7,0,7.35)
	_map_root.add_child(fire)
	_support_scenery(fire,Vector2(.64,.64))
	_art.fire(fire,.80)


func _support_scenery(root: Node3D, footprint: Vector2) -> void:
	if terrain.land_at(floori(root.position.z),floori(root.position.x)): return
	_art.box(root,Vector3(0,-.29,0),Vector3(footprint.x,.58,footprint.y),"architecture",.4)


func _clear_markers() -> void:
	if _marker_root == null: return
	for child in _marker_root.get_children():
		_marker_root.remove_child(child)
		child.queue_free()


func _update_markers() -> void:
	if expedition == null or _marker_root == null: return
	_clear_markers()
	# The wire is a connection overlay, with the same exploration clipping
	# as pursuit marks; only its two terminal tiles trigger transport.
	for k in expedition.m.mech:
		var mc: Dictionary = expedition.m.mech[k]
		if mc.kind != "wire": continue
		var points: Array = [k]
		points.append_array(mc.get("path",[]))
		points.append(mc.to)
		var tint := Color("697594") if expedition.mover_live(k,expedition.t) else Color("3c3e4a")
		for i in range(1,points.size()):
			if expedition.explored.has(points[i-1]) and expedition.explored.has(points[i]):
				var start := world_position(points[i-1])
				var end := world_position(points[i])
				for j in 4: _surface_rod(start.lerp(end,j/4.0),start.lerp(end,(j+1)/4.0),.012,_factory.plain(tint,true),.018)
		break
	for k in MapGen.N:
		if expedition.can_step(k): _corners(k,GOLD,0.10)
	if hover_cell >= 0:
		_corners(hover_cell,PAPER if expedition.can_step(hover_cell) else Color("748c82"),0.035)
		if expedition.explored.has(hover_cell) and not expedition.taken.has(hover_cell) and str(expedition.m.node.get(hover_cell,{}).get("t","")) in ["敌","险"]:
			for n in MapGen.nbrs(hover_cell):
				if expedition.explored.has(n): _corners(n,RED,0.16)
	for i in path_cells.size():
		if not expedition.explored.has(path_cells[i]): continue
		var p := surface_position(path_cells[i],0.045)
		_factory.cylinder(_marker_root,p,0.037,0.009,_factory.plain(RED,true))
		if i == 0 or not expedition.explored.has(path_cells[i-1]): continue
		var a := surface_position(path_cells[i-1],0.045)
		for j in 4:
			_surface_rod(a.lerp(p,j/4.0),a.lerp(p,(j+0.52)/4.0),0.008,_factory.plain(RED,true),.045)
	_factory.cylinder(_marker_root,surface_position(expedition.pos,0.025),0.24,0.005,_factory.plain(Color(0.84,0.72,0.43,0.22),true))


func _corners(k: int, color: Color, inset: float) -> void:
	var p := world_position(k)
	var material := _factory.plain(color,true)
	for x in [-1.,1.]:
		for z in [-1.,1.]:
			var corner := p+Vector3(x*(0.5-inset),0,z*(0.5-inset))
			_surface_rod(corner,corner-Vector3(x*0.13,0,0),0.009,material)
			_surface_rod(corner,corner-Vector3(0,0,z*0.13),0.009,material)


func _surface_rod(a: Vector3, b: Vector3, width: float, material: Material, lift := .035) -> void:
	_factory.rod(_marker_root,_on_surface(a,lift),_on_surface(b,lift),width,material)


func recenter() -> void:
	following = true
	overview = false
	_distance_target = DEFAULT_DISTANCE
	if expedition != null: _look_target = world_position(expedition.pos)
	_camera_dirty = true


func show_overview() -> void:
	if camera == null: return
	following = false
	overview = true
	_look_target = Vector3(6,0,4)
	_distance_target = _overview_distance()
	_camera_dirty = true


func _overview_distance() -> float:
	var old := camera.transform
	var fit := 12.0
	var angle := deg_to_rad(PITCH)
	var rect := Rect2(Vector2(22,40),Vector2(viewport.size)-Vector2(44,65))
	for attempt in 20:
		camera.position = Vector3(6,0,4)+Vector3(0,sin(angle),cos(angle))*fit
		camera.look_at(Vector3(6,0,4),Vector3.UP)
		var fits := true
		for x in [-0.25,12.25]:
			for z in [-0.25,8.25]:
				for y in [0.0,1.6]:
					if not rect.has_point(camera.unproject_position(Vector3(x,y,z))): fits = false
		if fits: break
		fit *= 1.05
	camera.transform = old
	return minf(fit,MAX_DISTANCE)


func zoom_by(factor: float, anchor: Vector2) -> void:
	var before := ground_at(anchor)
	_distance_target = clampf(_distance_target*factor,MIN_DISTANCE,MAX_DISTANCE)
	_distance = _distance_target
	_apply_camera()
	var after := ground_at(anchor)
	if before.is_finite() and after.is_finite():
		_look += before-after
		_look_target = _clamp_look(_look)
		_look = _look_target
	overview = false
	_apply_camera()


func pan_by(delta: Vector2) -> void:
	var a := ground_at(size*0.5)
	var b := ground_at(size*0.5+delta)
	if a.is_finite() and b.is_finite():
		following = false
		overview = false
		_look_target = _clamp_look(_look_target + a-b)
		_look = _look_target
		_apply_camera()


func _clamp_look(value: Vector3) -> Vector3:
	return Vector3(clampf(value.x,-0.3,12.3),0,clampf(value.z,-0.3,8.3))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			_last_pointer = event.position
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(0.88 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/0.88,event.position)
			set_hover(pick_cell(event.position))
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if walker_at(event.position):
				walker_pressed.emit()
				accept_event()
				return
			var k := pick_cell(event.position)
			if k >= 0: cell_pressed.emit(k)
			accept_event()
	elif event is InputEventMouseMotion:
		if _panning:
			pan_by(event.position-_last_pointer)
			_last_pointer = event.position
		set_hover(pick_cell(event.position))
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if walker_at(event.position) else Control.CURSOR_ARROW


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE and not event.pressed: _panning = false


func _process(delta: float) -> void:
	if camera == null: return
	_clock += delta
	if following and player_actor != null: _look_target = _clamp_look(player_actor.position)
	var changed := _look.distance_to(_look_target)>0.0001 or absf(_distance-_distance_target)>0.0001 or _camera_dirty
	if changed:
		_look = _look.lerp(_look_target,1.0-exp(-delta*11.0))
		_distance = lerpf(_distance,_distance_target,1.0-exp(-delta*11.0))
		_apply_camera()
	_outline_clock += delta
	if _outline_pending and (_outline_clock>.10 or _style.outline_refresh_in_progress()):
		if not _style.outline_refresh_in_progress(): _outline_sweep_generation = _outline_generation
		var completed := _style.refresh_outlines(2.0)
		_outline_pending = not completed or _outline_sweep_generation!=_outline_generation
		_outline_clock = 0.0
	var actors_moving := (_player_tween!=null and _player_tween.is_running()) or (boss_tween!=null and boss_tween.is_running())
	if expedition!=null and (_occlusion_dirty or actors_moving):
		_update_occlusion()
		_occlusion_dirty = false
		_overlay.queue_redraw()


func _apply_camera() -> void:
	if camera == null: return
	var angle := deg_to_rad(PITCH)
	camera.position = _look + Vector3(0,sin(angle),cos(angle))*_distance
	camera.look_at(_look,Vector3.UP)
	if _mist_paint!=null: _mist_paint.set_shader_parameter("camera_position",camera.position)
	_camera_dirty = false
	_outline_pending = true
	_outline_generation += 1
	_occlusion_dirty = true
	layout_changed.emit()


func _update_occlusion() -> void:
	var targets: Array[Vector2] = [cell_center(expedition.pos)-Vector2(0,25)]
	for k in MapGen.nbrs(expedition.pos):
		if expedition.can_step(k): targets.append(cell_center(k))
	for k in _cell_nodes:
		var root: Node3D = _cell_nodes[k]
		if not bool(root.get_meta("tall",false)): continue
		var origin: Vector3 = root.position+root.get_meta("pick_offset",Vector3.ZERO)
		var foot := camera.unproject_position(origin)
		var height: float = root.get_meta("card_height",root.get_meta("visual_height",1.4))
		var half_width := float(root.get_meta("card_width",root.get_meta("visual_width",1.3)))*0.5
		var top := camera.unproject_position(origin+(camera.global_basis.y*height if root.has_meta("card_height") else Vector3.UP*height))
		var edge := camera.unproject_position(origin+Vector3(half_width,0,0))
		var width := maxf(24.0,absf(edge.x-foot.x))
		var rect := Rect2(Vector2(foot.x-width,top.y),Vector2(width*2,foot.y-top.y)).abs()
		var occluded := false
		for point in targets:
			if rect.has_point(point): occluded = true
		if _occlusion.get(k,null) != occluded:
			_occlusion[k] = occluded
			_fade_tree(root,0.65 if occluded else 0.0)
	for root in _foregrounds:
		var origin: Vector3 = root.to_global(root.get_meta("occlusion_center",Vector3.ZERO))
		var foot := camera.unproject_position(origin)
		var height: float = root.get_meta("height",3.0)
		var top := camera.unproject_position(origin+camera.global_basis.y*height)
		var rect := Rect2(Vector2(foot.x-absf(foot.y-top.y)*0.52,top.y),Vector2(absf(foot.y-top.y)*1.04,foot.y-top.y)).abs()
		if root.has_meta("visual_width"):
			var edge := camera.unproject_position(origin+Vector3(float(root.get_meta("visual_width"))*.5,0,0))
			var half_width := absf(edge.x-foot.x)
			rect = Rect2(Vector2(foot.x-half_width,top.y),Vector2(half_width*2,foot.y-top.y)).abs()
		var occluded := false
		for point in targets:
			if rect.has_point(point): occluded = true
		var key := root.get_instance_id()
		if _occlusion.get(key,null)!=occluded:
			_occlusion[key] = occluded
			_fade_tree(root,float(root.get_meta("occlusion_fade",.76)) if occluded else 0.0)


func _fade_tree(node: Node, amount: float) -> void:
	if node.has_meta("ground_imprint"): return
	if node.has_meta("fade_roof_only"):
		_fade_roofs(node,amount)
		return
	if node is GeometryInstance3D: node.transparency = amount
	for child in node.get_children(): _fade_tree(child,amount)


func _fade_roofs(node: Node, amount: float) -> void:
	if node.has_meta("roof_occluder"): _fade_tree(node,amount)
	else:
		for child in node.get_children(): _fade_roofs(child,amount)


class MapOverlay extends Control:
	var view: ExpeditionMapView
	func _draw() -> void:
		if view == null or view.expedition == null or view.camera == null: return
		var ex := view.expedition
		for k in MapGen.N:
			if ex.explored.has(k): continue
			var p := view.cell_center(k)
			if not Rect2(Vector2(12,12),size-Vector2(24,24)).has_point(p): continue
			var hint := str(view.cell_info(k).text)
			if hint in ["伏","✕"]:
				draw_circle(p,12,Color("28131e"))
				draw_string(Ink.serif,p+Vector2(-8,6),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,18,RED)
				continue
			if not ex.is_beacon(k): continue
			draw_circle(p,13,Color(0.68,0.51,0.24,0.12))
			var diamond := PackedVector2Array([p+Vector2(0,-9),p+Vector2(7,0),p+Vector2(0,9),p+Vector2(-7,0),p+Vector2(0,-9)])
			draw_polyline(diamond,GOLD,1.5,true)
			var text: String = {"大":"赏","休":"休","市":"市"}.get(str(ex.m.node[k].t),"◇")
			draw_string(Ink.serif,p+Vector2(-7,25),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,PAPER)
		var boss_point := view.cell_center(ex.boss)
		var rect := Rect2(Vector2(24,45),size-Vector2(48,80))
		var boss_known := ex.boss_revealed()
		if boss_known and not rect.has_point(boss_point):
			var center := size*0.5
			var direction := (boss_point-center).normalized()
			var tx := absf((rect.end.x-center.x)/direction.x) if absf(direction.x)>0.001 else INF
			var edge_y := rect.end.y if direction.y>0 else rect.position.y
			var ty := absf((edge_y-center.y)/direction.y) if absf(direction.y)>0.001 else INF
			var edge := center+direction*minf(tx,ty)
			var arrow := PackedVector2Array([edge+direction*9,edge-direction*6+direction.orthogonal()*6,edge-direction*6-direction.orthogonal()*6])
			draw_colored_polygon(arrow,RED if ex.awake() else GOLD)
			var distance: int = MapGen.bfs(ex.boss_mask(),ex.boss)[ex.pos]
			var text := "%s · %s" % [ex.m.TH.boss,("%d步" % distance) if distance<MapGen.INF else "路断"]
			var text_width := Ink.serif.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			var text_at := Vector2(clampf(edge.x-text_width*0.5,8,size.x-text_width-8),edge.y+(-17 if edge.y>size.y*0.65 else 24))
			draw_string(Ink.serif,text_at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,PAPER)
		elif boss_known:
			var above := view.camera.unproject_position(view.boss_actor.position+Vector3(0,0.82,0))
			var text := "追" if ex.awake() else ("眠" if ex.stir==null else str(int(ex.rise)-ex.t))
			if ex.stun>0: text = "定"
			draw_circle(above+Vector2(0,-6),11,Color("5b2d28") if ex.awake() else Color("273d37"))
			draw_string(Ink.serif,above+Vector2(-7,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,PAPER)
