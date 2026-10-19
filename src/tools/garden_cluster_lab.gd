extends "res://src/tools/garden_landmark_lab.gd"
const RUN = preload("res://src/expedition/room_run_state.gd")
const ROOM_VISUAL = preload("res://src/map/garden_room_visual.gd")
const CLUSTER_VISUAL = preload("res://src/map/garden_cluster_visual.gd")
const NETWORK = preload("res://src/map/garden_bridge_network.gd")
const LAYOUT = preload("res://src/expedition/garden_room_layout.gd")
var run: RefCounted
var cluster: Dictionary
var views: Array = []
var garden: Node3D
var bridge: Node3D
var pool_room := ""


func _ready() -> void:
	output = "res://docs/art-concepts/2026-10-18-cluster-runtime"
	run = RUN.new(); run.reset({"seed":29}); run.autosave = false
	assert(run.generation_error.is_empty(),run.generation_error)
	cluster = run.layout.clusters[0]
	for id in cluster.members:
		run.visited_rooms[id] = true; run.resolved[id] = true
		if not run.layout.rooms[id].get("ponds",[]).is_empty(): pool_room = id
	super._ready()


func _build_controls() -> void:
	super._build_controls()
	mode.clear(); mode.add_item("荷池组团 · 共用围墙与内池"); mode.add_item("庭内莲池 · 同一运行房间")
	roof_toggle.visible = false; grid_toggle.text = "实际通行格"
	annotation.set_script(load("res://src/tools/garden_cluster_overlay.gd")); annotation.set("lab",self)
	var column: VBoxContainer = chrome.get_child(1).get_child(0)
	(column.get_child(1) as Label).text = "真实随机图数据与生产渲染 · 本工作台揭示组团用于检查美术／游戏仍保留迷雾和分支封路"


func set_mode(index: int) -> void:
	current_mode = index; mode.select(index)
	title.text = "荷池组团 · %d 个节点与前庭" % (cluster.members.size()-1) if index==0 else "庭内莲池 · 地面／岸壁／通行共用形状"
	style.reset_geometry_tracking()
	for list in [assets,assemblies,trees,labels,landmarks,views]: list.clear()
	if contents!=null: world.remove_child(contents); contents.queue_free()
	contents = Node3D.new(); world.add_child(contents); _water_context()
	garden = CLUSTER_VISUAL.new(); contents.add_child(garden); garden.build(cluster,run.layout,style)
	garden.refresh(run,run.layout.point(run.position),true)
	for paint in garden.paints: paint.set_shader_parameter("fog_mask",_white())
	for id in cluster.members:
		var data: Dictionary = run.layout.rooms[id]
		var view := ROOM_VISUAL.new()
		view.position = Vector3(data.transform.origin.x,0,data.transform.origin.y); view.rotation.y = -data.transform.get_rotation()
		contents.add_child(view); view.build(data,style,camera,environment,ground_material)
		view.update_state(true,false,true); views.append(view); assets.append_array(view.assets)
	var subset := LAYOUT.new(); subset.bounds = cluster.bounds
	for id in cluster.members: subset.rooms[id] = run.layout.rooms[id]
	for corridor in run.layout.corridors:
		if cluster.members.has(corridor.from) and cluster.members.has(corridor.to): subset.corridors.append(corridor)
	var ids: Array = subset.corridors.map(func(corridor): return corridor.id)
	for cell in run.layout.cells:
		var entry: Dictionary = run.layout.cells[cell]
		var owned: Array = entry.rooms.filter(func(id): return cluster.members.has(id))
		var edges: Array = entry.edges.filter(func(id): return ids.has(id))
		if not owned.is_empty() or not edges.is_empty(): subset.cells[cell] = {"rooms":owned,"edges":edges}
	bridge = NETWORK.new(); contents.add_child(bridge); bridge.setup(subset,run.graph,style,ground_material)
	bridge.refresh(cluster.bounds.get_center(),run)
	var stand: Vector2 = run.layout.point(run.layout.rooms[cluster.source].stand_cell)
	_traveler(Vector3(stand.x,0,stand.y))
	_yaw = 12; _pitch = 52
	if index==0:
		_look = Vector3(cluster.bounds.get_center().x,.65,cluster.bounds.get_center().y)
		_height = cluster.bounds.size.y*.8+6.8
	else:
		var box: Rect2 = run.layout.rooms[pool_room].bounds
		_look = Vector3(box.get_center().x,.60,box.get_center().y); _height = 6.8
	_apply_camera()


func _apply_camera() -> void:
	super._apply_camera()
	for view in views: view.sync_camera(camera)


func _capture() -> void:
	get_window().content_scale_size = Vector2i.ZERO; get_window().size = Vector2i(1600,1100)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _frames(10)
	set_mode(0); await _frames(5); _snap("01-cluster-whole.png")
	set_mode(1); await _frames(5); _snap("02-inner-court-pond.png")
	set_mode(0); grid_toggle.button_pressed = true; await _frames(4); _snap("03-cluster-navigation.png",true)
	print("[ClusterStudy] members=",cluster.members.size()," bounds=",cluster.bounds," inner_pool=",pool_room)
	get_tree().quit()


func _snap(filename: String, with_ui := false) -> void:
	RenderingServer.force_draw(false)
	var rendered := get_viewport() if with_ui else viewport
	assert(rendered.get_texture().get_image().save_png(output.path_join(filename))==OK)
