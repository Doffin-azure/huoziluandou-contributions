extends Control
## Perspective picking, terrain joins, run-state isolation and actual GPU captures.
var _pass := 0
var _fail := 0
var _capture := false
var _record := false
var _out := ""


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_record = OS.get_cmdline_user_args().has("--record")
	_out = OS.get_environment("TEMP").path_join("huozi-map3d")
	var args := OS.get_cmdline_user_args()
	var output_index := args.find("--output-dir")
	if output_index>=0 and output_index+1<args.size(): _out = ProjectSettings.globalize_path(args[output_index+1])
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(180).timeout.connect(func(): push_error("地图3D测试超时"); get_tree().quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok: _pass += 1
	else:
		_fail += 1
		push_error(message)


func _frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func _settle(view: ExpeditionMapView) -> void:
	if view.following: view._look_target = view.world_position(view.expedition.pos)
	view._look = view._look_target
	view._distance = view._distance_target
	view._apply_camera()
	await _frames()


func _snapshot(ex: Expedition) -> String:
	return var_to_str([ex.rng.state,GameState.rng.state,CharInstance._next_uid,ex.pos,ex.t,ex.ink,ex.visible,ex.explored,ex.taken,ex.used,ex.boss,ex.tray,ex.plate])


func _capture_image(name: String) -> void:
	if not _capture and not _record: return
	RenderingServer.force_draw(false)
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"实机截图 " + name)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var ex := Expedition.start(12)
	ex.themes = ["墨池","熔铸坊","潮汐渠"]
	ex.load_act(1)
	var screen: Control = load("res://src/screens/expedition_map_screen.gd").new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(12)
	var view: ExpeditionMapView = screen._map_view
	_check(view.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(view.camera.fov,25.0),"手绘场景的弱透视相机与固定视场")
	_check(view._factory.actors.size()==8 and view._factory.props.size()==16 and view.terrain.shore_segments>0,"人物图集与实体岸壁加载")
	_check(not screen._event_panel.visible,"无事件时收起事件面板")
	_check(_shore_vertices_match(view.terrain),"圆角岸壁顶点与连续地面精确接合")
	await _inventory_interaction_checks(screen,view,ex)
	await _vision_fog_checks(view,ex)
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size = dimensions
		await _frames(8)
		view.show_overview()
		await _settle(view)
		var aligned := true
		for k in MapGen.N: aligned = aligned and view.cell_at(view.cell_center(k))==k
		_check(aligned,"透视总览96格射线命中 " + str(dimensions))
		view.recenter()
		await _settle(view)
		view.zoom_by(0.75,view.cell_center(ex.pos))
		view.pan_by(Vector2(75,22))
		var local_aligned := true
		for k in MapGen.N:
			var point := view.cell_center(k)
			if Rect2(Vector2.ZERO,view.size).has_point(point): local_aligned = local_aligned and view.cell_at(point)==k
		_check(local_aligned,"缩放拖动后可见地面命中 " + str(dimensions))
		_check(view.size.distance_to(screen.size)<1.0,"地图铺满整个画面 " + str(dimensions))
		screen._set_inventory_open(true)
		await _frames()
		_check(screen._actor_panel.get_global_rect().end.x<=screen.size.x+1 and screen._actor_panel.get_global_rect().end.y<=screen.size.y+1,"行囊弹层不越界 " + str(dimensions))
		if dimensions.x==1920: _capture_image("15-inventory-1920.png")
		screen._set_inventory_open(false)
	_check(view.cell_at(Vector2(-2,-2))==-1,"地图范围外不拾取")
	var before := _snapshot(ex)
	var terrain_id := view.terrain.get_instance_id()
	view.set_hover(ex.pos)
	view.zoom_by(1.1,view.size*0.5)
	view.pan_by(Vector2(-20,10))
	view.refresh(ex)
	_check(before==_snapshot(ex),"镜头、悬浮、刷新不消耗随机数和玩法状态")
	_check(view.terrain.get_instance_id()==terrain_id,"刷新不重建整张地形")
	_check(not view.following,"拖看暂停跟随")
	view.recenter()
	await _settle(view)
	_check(view.following and view._look.distance_to(view.world_position(ex.pos))<0.01,"回到行者恢复跟随")
	var a := view.camera.unproject_position(Vector3(5,0,2))
	var b := view.camera.unproject_position(Vector3(5,2.5,7))
	view.pan_by(Vector2(40,0))
	var da := view.camera.unproject_position(Vector3(5,0,2))-a
	var db := view.camera.unproject_position(Vector3(5,2.5,7))-b
	_check(absf(db.x-da.x)>1,"不同深度随镜头产生真实相对位移")
	get_window().size = Vector2i(1280,720)
	await _frames()
	view.recenter()
	await _settle(view)
	var destination := -1
	for k in MapGen.N:
		if ex.can_step(k) and not view.walker_at(view.cell_center(k)) and ex.mech_at(k).is_empty() and not ex.m.node.has(k) and not ex.m.obst.has(k) and not ex.m.get("terr",{}).has(k):
			destination = k
			break
	_check(destination>=0,"存在正常探索步")
	if destination>=0:
		var point := view.global_position + view.cell_center(destination)
		for pressed in [true,false]:
			var click := InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			get_viewport().push_input(click)
		await get_tree().create_timer(0.25).timeout
		_check(ex.pos==destination,"点击透视地面实际前进一步")
		_check(view.following,"移动后自动恢复跟随")
	screen._set_inventory_open(true)
	await _frames()
	var distance_before := view._distance_target
	var wheel := InputEventMouseButton.new()
	wheel.position = screen._actor_panel.get_global_rect().get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	get_viewport().push_input(wheel)
	await _frames()
	_check(is_equal_approx(distance_before,view._distance_target),"行囊滚轮不缩放地图")
	screen._set_inventory_open(false)
	ex.tray = ["火","回"]
	ex.push_panel({"kind":"forge","k":ex.pos})
	screen.refresh()
	await _frames()
	screen._on_tray(0)
	screen._on_tray(1)
	await _frames()
	_check(screen._event_panel.visible and screen._forge_sel==[0,1],"事件展开仍能选择两枚熔炉材料")
	_capture_image("16-forge-context-1280.png")
	ex.leave_panel()
	screen.refresh()
	await _settle(view)
	_capture_image("01-exploration-1280.png")
	for k in MapGen.N:
		ex.explored[k] = true
		ex.visible[k] = true
	screen.refresh()
	await _frames(8)
	view.following = false
	view._look_target = Vector3(6,0,4)
	await _settle(view)
	var facility_hit := false
	for k in view._cell_nodes:
		var node: Node3D = view._cell_nodes[k]
		if str(ex.m.node.get(k,{}).get("t",""))!="市": continue
		view._look_target = view.world_position(k)
		await _settle(view)
		var body := view.camera.unproject_position(node.position+Vector3.UP*float(node.get_meta("visual_height"))*.60+node.get_meta("pick_offset",Vector3(0,0,.12)))
		facility_hit = view.pick_cell(body)==k
		if not facility_hit: print("[FacilityPick] key=",k," result=",view.pick_cell(body)," floor=",view.cell_at(body)," offset=",node.get_meta("pick_offset")," occluded=",view._occlusion.get(k,false)," body=",body)
	_check(facility_hit,"点立体设施主体对应自身落脚格")
	_capture_image("02-local-1280.png")
	view.show_overview()
	await _settle(view)
	_capture_image("03-overview-1280.png")
	ex.stir = ex.t
	ex.rise = ex.t
	screen.refresh()
	await _frames()
	_check(view.path_cells==ex.boss_path(),"首领路线使用真实预测路径")
	_capture_image("04-chase-1280.png")
	for theme_name in MapGen.THEME_ORDER:
		ex.themes[0] = theme_name
		ex.load_act(1)
		screen.refresh()
		await _frames(2)
		_check(view.expedition.m.tn==theme_name and view.terrain.land_cells>0,"主题与机关接入 " + theme_name)
	ex.themes[0] = "墨池"
	ex.load_act(1)
	ex._resize_plate(4)
	for k in MapGen.N:
		ex.explored[k] = true
		ex.visible[k] = true
	screen.refresh()
	get_window().size = Vector2i(1920,1080)
	await _frames(8)
	view.following = false
	view._look_target = Vector3(6,0,4)
	await _settle(view)
	_capture_image("05-local-1920.png")
	_check(screen._plate_grid.get_child_count()==16,"扩展4×4版面仍可用")
	await _native_art_states(view,ex)
	view.show_overview()
	await _settle(view)
	_capture_image("08-overview-1920.png")
	await _night_art_checks(view,ex)
	if _record: await _record_camera(screen,view)
	screen.queue_free()
	await _frames()
	await _gallery()
	await _engraving_gallery()
	print("[expedition_map_view_test] PASS=%d FAIL=%d" % [_pass,_fail])
	get_tree().quit(1 if _fail else 0)


func _click_point(point: Vector2) -> void:
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		get_viewport().push_input(click)
	await _frames()


func _inventory_interaction_checks(screen: Control, view: ExpeditionMapView, ex: Expedition) -> void:
	_check(not screen._actor_panel.visible and not screen._plate_section.visible and not screen._log_box.visible,"地图没有常驻行囊、版面与日志")
	var original_tray := ex.tray.duplicate()
	ex.tray = ["火","回"]
	screen.refresh()
	await _frames()
	var before := _snapshot(ex)
	var sprite: Sprite3D = view.player_actor.get_child(0)
	var actor_point := view.camera.unproject_position(sprite.global_position)
	for y in [-12.0,0.0,12.0]:
		for x in [-8.0,0.0,8.0]:
			var candidate := actor_point+Vector2(x,y)
			if view.walker_at(candidate): actor_point = candidate; break
	_check(view.walker_at(actor_point),"人物立片透明像素拾取可用")
	await _click_point(view.global_position+actor_point)
	_check(screen._actor_panel.visible and screen._hp_bar.value==GameState.player_hp and screen._stat_label.text.contains(str(GameState.gold)),"点击人物展开生命、金币与字匣")
	_check(before==_snapshot(ex),"打开人物行囊不移动、不耗步、不耗随机数")
	_capture_image("14-inventory-1280.png")
	await _click_point(screen._tray_row.get_child(0).get_global_rect().get_center())
	_check(screen._sel==0 and ex.pos==view._shown_player,"字匣选择不穿透到地图")
	var outside := -1
	for k in MapGen.nbrs(ex.pos):
		var point := view.global_position+view.cell_center(k)
		if ex.can_step(k) and not view.walker_at(view.cell_center(k)) and not screen._actor_panel.get_global_rect().has_point(point): outside = k; break
	_check(outside>=0,"存在弹层外可走目标")
	if outside>=0: await _click_point(view.global_position+view.cell_center(outside))
	_check(not screen._actor_panel.visible and before==_snapshot(ex),"点弹层外先收起行囊，避免误走一步")
	screen._set_inventory_open(true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape)
	await _frames()
	_check(not screen._actor_panel.visible,"Esc收起人物弹层")
	screen._show_notice("拾得一枚字")
	await get_tree().create_timer(3.0).timeout
	_check(not screen._notice.visible,"短提示自动消失，不持久展示日志")
	ex.tray = original_tray
	screen.refresh()



func _fog_matches_rules(view: ExpeditionMapView, ex: Expedition) -> bool:
	var image := view.terrain.fog_texture.get_image()
	for k in MapGen.N:
		var rc := MapGen.rc(k)
		var pixel := image.get_pixel(rc.y,rc.x)
		if (pixel.r>.5)!=ex.explored.has(k) or (pixel.g>.5)!=ex.visible.has(k): return false
	return true


func _vision_fog_checks(view: ExpeditionMapView, ex: Expedition) -> void:
	var saved_pos := ex.pos
	var saved_visible := ex.visible.duplicate()
	var saved_explored := ex.explored.duplicate()
	var saved_active := ex.active.duplicate()
	var saved_seals := ex.seals.duplicate()
	var before := _snapshot(ex)
	_check(_fog_matches_rules(view,ex),"当前视野与历史探索逐格驱动迷雾")
	_check(view.terrain.sight_material.get_shader_parameter("fog_mask")==view.terrain.fog_texture,"不透明遮蔽层与体积雾使用同一玩法遮罩")
	var hidden_entities := true
	var unknown_beacon := -1
	for k in MapGen.N:
		if ex.explored.has(k): continue
		if view._cell_nodes.has(k): hidden_entities = false
		if ex.is_beacon(k): unknown_beacon = k
	_check(hidden_entities,"未探索物件不实例化，不透出建筑与散字")
	_check(unknown_beacon>=0 and view.cell_info(unknown_beacon).text=="◇","信标只显示隔雾引导，不显示未探索建筑")
	_check(not ex.explored.has(ex.boss) and not view.boss_actor.visible,"未发现的沉睡首领不泄露巢穴位置")
	var saved_stir = ex.stir
	var saved_rise = ex.rise
	var saved_boss_down := ex.boss_down
	ex.stir = ex.t
	ex.rise = ex.t + ex.buffer_steps()
	view.refresh(ex)
	_check(view.boss_actor.visible and not ex.awake(),"首领惊动后在缓冲期现身，与远程揭示规则一致")
	ex.boss_down = true
	view.refresh(ex)
	_check(not view.boss_actor.visible and view.path_cells.is_empty(),"首领战后继续探索时实体和追逐路线一同隐藏")
	ex.stir = saved_stir
	ex.rise = saved_rise
	ex.boss_down = saved_boss_down
	view.refresh(ex)
	view.show_overview()
	await _settle(view)
	_capture_image("11-initial-vision-overview-1280.png")
	var vision_count := ex.visible.size()
	ex.active["开灯"] = true
	ex.update_vision()
	view.refresh(ex)
	_check(ex.visible.size()>vision_count and _fog_matches_rules(view,ex),"开灯扩大真实视野并同步散雾")
	ex.seals.append("夜灯")
	ex.active["左右"] = true
	ex.update_vision()
	view.refresh(ex)
	_check(_fog_matches_rules(view,ex),"夜灯与十字视野复用原玩法规则")
	ex.active = saved_active.duplicate()
	ex.seals = saved_seals.duplicate()
	ex.visible = saved_visible.duplicate()
	ex.explored = saved_explored.duplicate()
	var destination := -1
	var farthest := 0
	var distance := MapGen.bfs(ex.boss_mask(),saved_pos)
	for k in MapGen.N:
		if distance[k]<MapGen.INF and distance[k]>farthest and ex.m.ink[k]==0:
			destination = k
			farthest = distance[k]
	_check(destination>=0,"存在远处视野检查位置")
	if destination>=0:
		ex.pos = destination
		ex.update_vision()
		view.refresh(ex)
		await get_tree().create_timer(.24).timeout
		_check(ex.explored.has(saved_pos) and not ex.visible.has(saved_pos) and _fog_matches_rules(view,ex),"离开后的旧区域保留探索记忆，不再维持当前视野")
		_check(view._cell_nodes.has(saved_pos) and not view._cell_nodes[saved_pos].get_meta("in_sight"),"视野外已知设施仍保留并暗化")
		view.show_overview()
		await _settle(view)
		_capture_image("12-moved-vision-overview-1280.png")
		view.recenter()
		await _settle(view)
		_capture_image("13-current-vision-local-1280.png")
	ex.pos = saved_pos
	ex.visible = saved_visible
	ex.explored = saved_explored
	ex.active = saved_active
	ex.seals = saved_seals
	view.refresh(ex)
	await get_tree().create_timer(.24).timeout
	view.recenter()
	await _settle(view)
	_check(before==_snapshot(ex),"迷雾检查还原探索状态且不消耗玩法随机数")


func _night_art_checks(view: ExpeditionMapView, ex: Expedition) -> void:
	var imprint := false
	for k in ex.m.glyph:
		if ex.taken.has(k) or ex.m.obst.has(k): continue
		var root: Node3D = view._cell_nodes[k]
		for child in root.get_children():
			if child.get_script()==ExpeditionMapArt.INLAY:
				imprint = child.floor_imprint and child.position.y<.04 and child.scale.x>1.0
				for other in root.get_children():
					if other is MeshInstance3D and other.get_aabb().size.y>.03: imprint = false
				break
		if imprint: break
	_check(imprint,"散字为格子尺度的直接地面印记，没有抬高字模")
	_check(view.mist_volume.material.get_shader_parameter("fog_mask")==view.terrain.fog_texture,"体积雾共用实际探索遮罩，不影响揭示规则")
	var warm := false
	var cold := false
	for light: OmniLight3D in view._map_root.find_children("*","OmniLight3D",true,false):
		if not light.visible: continue
		warm = warm or light.light_color.r>light.light_color.b+.1
		cold = cold or light.light_color.b>light.light_color.r+.1
	_check(warm and cold,"暖色灯笼和冷色鬼火在同一地图独立照明")
	if _capture:
		view.environment.volumetric_fog_enabled = false
		await _frames(12)
		_capture_image("09-without-volume-fog-1920.png")
		view.environment.volumetric_fog_enabled = RenderingServer.get_current_rendering_method()=="forward_plus"
		view.following = false
		view.overview = false
		view._look_target = Vector3(11.1,0,7.0)
		view._distance_target = 8.4
		await _settle(view)
		await _frames(12)
		_capture_image("10-ghost-fire-local-1920.png")


func _native_art_states(view: ExpeditionMapView, ex: Expedition) -> void:
	var shop := -1
	var reward := -1
	var rest := -1
	var shrine := -1
	for k in ex.m.node:
		match str(ex.m.node[k].t):
			"市": shop = k
			"小","中","大": reward = k
			"休": rest = k
			"谜": shrine = k
	_check(shop>=0 and reward>=0 and rest>=0 and shrine>=0,"随机地图包含新版设施与封匣")
	if mini(shop,mini(reward,mini(rest,shrine)))<0: return
	var shop_root: Node3D = view._cell_nodes[shop]
	var identity := shop_root.get_instance_id()
	ex.visible.erase(shop)
	view.refresh(ex)
	_check(view._cell_nodes[shop].get_instance_id()==identity and not shop_root.get_meta("in_sight"),"视野暗化复用原建筑，无需重新生成")
	var all_off := true
	for light in shop_root.find_children("*","Light3D",true,false): all_off = all_off and not light.visible
	_check(all_off,"视野外字摊关闭局部灯光")
	ex.visible[shop] = true
	view.refresh(ex)
	_check(view._cell_nodes[shop].get_instance_id()==identity and shop_root.get_meta("in_sight"),"再次可见时恢复同一建筑")
	var saved_taken: Dictionary = ex.taken.duplicate()
	var saved_obstacles: Dictionary = ex.m.obst.duplicate()
	for k in [reward,rest,shrine]: ex.taken[k] = true
	var barrier := -1
	if not ex.m.obst.is_empty():
		barrier = ex.m.obst.keys()[0]
		ex.m.obst.erase(barrier)
	view.refresh(ex)
	await _frames(8)
	var casket: Node3D = view._cell_nodes[reward].get_child(0)
	var pavilion: Node3D = view._cell_nodes[rest].get_child(0)
	var question: Node3D = view._cell_nodes[shrine].get_child(0)
	_check(casket.get_script()==ExpeditionMapArt.CASKET and casket.alternate_state,"地图领奖后真实开启匣盖")
	_check(pavilion.get_script()==ExpeditionMapArt.REST and pavilion.alternate_state and not pavilion._lamps[0].visible,"休息点使用后熄灯并显示已用状态")
	_check(question.get_script()==ExpeditionMapArt.SHRINE and not question.lamp_lit,"问字龛使用后熄灯")
	if barrier>=0:
		var rubble: Node3D = view._cell_nodes[barrier].get_child(0)
		_check(rubble.get_script()==ExpeditionMapArt.BARRIER and rubble.alternate_state,"墨障解除后保留原位碎石")
	_capture_image("07-used-states-1920.png")
	ex.taken = saved_taken
	ex.m.obst = saved_obstacles
	view.refresh(ex)
	await _frames()


func _shore_vertices_match(terrain: ExpeditionTerrain) -> bool:
	var top: MeshInstance3D = terrain.get_node("ContinuousStone")
	var wall: MeshInstance3D = terrain.get_node("ShoreWalls")
	var positions: Dictionary = {}
	for vertex: Vector3 in top.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: positions[Vector2i(roundi(vertex.x*10000),roundi(vertex.z*10000))] = true
	for vertex: Vector3 in wall.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if vertex.y==0 and not positions.has(Vector2i(roundi(vertex.x*10000),roundi(vertex.z*10000))): return false
	return wall.get_aabb().position.y < -0.5


func _gallery() -> void:
	var fixture: Expedition = load('res://tests/expedition_terrain_gallery.gd').make_fixture()
	var view := ExpeditionMapView.new()
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.refresh(fixture)
	view.show_overview()
	await _settle(view)
	_check(_shore_vertices_match(view.terrain),"直岸、内外角、孤池、窄水道和岛屿均无几何接缝")
	_capture_image("06-terrain-joins.png")
	view.queue_free()
	await _frames()


func _engraving_gallery() -> void:
	var fixture: Expedition = load("res://tests/expedition_terrain_gallery.gd").make_fixture()
	fixture.m.ink.fill(0)
	var glyphs := ["火","回","防","击","重","流","精","能","心"]
	for i in glyphs.size(): fixture.m.glyph[MapGen.kk(2+i/3,4+i%3)] = glyphs[i]
	fixture.pos = MapGen.kk(5,3)
	var view := ExpeditionMapView.new()
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.refresh(fixture)
	get_window().size = Vector2i(1920,1080)
	await _frames()
	view.player_actor.visible = false
	view.boss_actor.visible = false
	view._overlay.visible = false
	view.following = false
	view._look_target = Vector3(5.5,0,3.5)
	view._distance_target = 5.6
	await _settle(view)
	var fire: Node3D = view._cell_nodes[MapGen.kk(2,4)].get_child(0)
	var before := _snapshot(fixture)
	_check(fire.floor_mesh!=null and not fire.face.visible and fire.floor_paint.get_shader_parameter("fog_mask")==view.terrain.fog_texture,"刻字使用石材凹槽与实际视野，不显示白色文字面")
	var image: Image = fire.floor_paint.get_shader_parameter("glyph_mask").get_image()
	var ink_pixels := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a>.5: ink_pixels += 1
	_check(ink_pixels>1000 and ink_pixels<image.get_width()*image.get_height()/2,"字体遮罩保留清晰笔画及透明底")
	_capture_image("17-carved-stone-3x3-1920.png")
	view._art.shade(fire,.48)
	_check(not fire.embers.visible,"视野外的火字不显示火星")
	view._art.shade(fire,1.0)
	fire.set_spent(true)
	_check(not fire.embers.visible,"火字消耗状态停止火星")
	fire.set_spent(false)
	_check(fire.embers.visible and before==_snapshot(fixture),"火星恢复和刻槽状态不消耗步数或随机数")
	# A warm light crossing the same stone and cut face verifies material unity.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(4.8,.7,3.6)
	lamp.light_color = Color("ffbd78")
	lamp.light_energy = .55
	lamp.omni_range = 2.1
	view._map_root.add_child(lamp)
	await _frames()
	_capture_image("18-carved-stone-lit-1920.png")
	view.queue_free()
	await _frames()


func _record_camera(screen: Control, view: ExpeditionMapView) -> void:
	get_window().size = Vector2i(1280,720)
	await _frames()
	var frames_path := _out.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_path)
	view.recenter()
	await _settle(view)
	var caption := Label.new()
	caption.add_theme_color_override("font_color",Color("e8d9b5"))
	caption.add_theme_font_size_override("font_size",16)
	caption.position = Vector2(14,14)
	view.add_child(caption)
	var origin := screen.ex.pos as int
	var destination := -1
	for k in MapGen.N:
		if screen.ex.can_step(k) and screen.ex.mech_at(k).is_empty() and not screen.ex.m.node.has(k) and not screen.ex.m.obst.has(k) and not screen.ex.m.get("terr",{}).has(k):
			destination = k
			break
	for i in 210:
		if i<60:
			caption.text = "随行 · 行者逐格前进，镜头平滑跟随"
			if destination>=0 and i in [12,28,44]: screen._on_map_cell(origin if i==28 else destination)
		elif i<150:
			caption.text = "拖看 · 近景树柱与远处碑林产生相对位移"
			if i==60:
				# Art-review reveal only; normal play keeps the real exploration mask.
				for k in MapGen.N:
					screen.ex.explored[k] = true
					screen.ex.visible[k] = true
				view.refresh(screen.ex)
				view.following = false
				view._look = Vector3(5,0,5.2)
				view._look_target = view._look
			view.pan_by(Vector2(-2.8,0.35*sin((i-60)*0.08)))
		else:
			caption.text = "缩放 · 局部地景与全图总览"
			if i==150: view.show_overview()
			if i==185: view.recenter()
		await _frames(1)
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(frames_path.path_join("frame-%04d.png" % i))
	print("[capture] frames=" + frames_path)
	caption.queue_free()
