extends Control
## An honest full-map plan: every rectangle, pond and connector comes from the
## same layout used by the playable run, with all forks revealed for inspection.
const RUN = preload("res://src/expedition/room_run_state.gd")
const FIELD = preload("res://src/expedition/garden_pond_field.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-18-whole-garden"
const SEEDS := [29,17,818]
const COLORS := [Color("b55b49"),Color("c4a366"),Color("61908c")]
var run: RefCounted
var show_walk := false
var subtitle: Label
var seed_menu: OptionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var row := HBoxContainer.new(); row.position = Vector2(24,20); row.add_theme_constant_override("separation",16); add_child(row)
	seed_menu = OptionButton.new(); row.add_child(seed_menu)
	for seed_value in SEEDS: seed_menu.add_item("种子 "+str(seed_value))
	seed_menu.item_selected.connect(func(index): select_seed(SEEDS[index]))
	var walking := CheckButton.new(); walking.text = "真实通行格"; row.add_child(walking)
	walking.toggled.connect(func(on): show_walk = on; queue_redraw())
	subtitle = Label.new(); subtitle.position = Vector2(24,62); subtitle.add_theme_font_override("font",Ink.serif); subtitle.add_theme_color_override("font_color",Color("c5b58e")); add_child(subtitle)
	resized.connect(queue_redraw)
	select_seed(SEEDS[0])
	if OS.get_cmdline_user_args().has("--capture"): capture.call_deferred()


func select_seed(seed_value: int) -> void:
	run = RUN.new(); run.reset({"seed":seed_value}); run.autosave = false
	assert(run.generation_error.is_empty(),run.generation_error)
	var site: Dictionary = run.layout.clusters[0]
	subtitle.text = "整园真实布局 · %d 庭／三处分叉 · 朱砂／旧金／丹青表示三个阶段 · %.1f × %.1f 世界单位" % [run.graph.rooms.size(),site.bounds.size.x,site.bounds.size.y]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b171c"))
	if run==null: return
	var site: Dictionary = run.layout.clusters[0]
	var area := Rect2(Vector2(38,108),size-Vector2(76,164))
	var scale_value := minf(area.size.x/site.bounds.size.x,area.size.y/site.bounds.size.y)
	var transform := Transform2D(0,Vector2.ONE*scale_value,0,area.get_center()-site.bounds.get_center()*scale_value)
	draw_rect(Rect2(transform*site.bounds.position,site.bounds.size*scale_value),Color("202c29"))
	draw_rect(Rect2(transform*site.bounds.position,site.bounds.size*scale_value),Color("6a7770"),false,3)
	for pond in site.ponds: _pond(pond,transform)
	for corridor: Dictionary in run.layout.corridors:
		var points := PackedVector2Array()
		for point: Vector2 in corridor.points: points.append(transform*point)
		var color: Color = COLORS[_stage(corridor.to)]
		draw_polyline(points,Color("080e11"),maxf(5,scale_value*.98),true)
		draw_polyline(points,color.darkened(.22),maxf(3,scale_value*.72),true)
		var middle := points.size()/2
		var delta := (points[middle]-points[middle-1]).normalized()
		var at := (points[middle]+points[middle-1])*.5
		var normal := Vector2(-delta.y,delta.x)
		draw_colored_polygon(PackedVector2Array([at+delta*5,at-delta*4+normal*3,at-delta*4-normal*3]),color.lightened(.2))
	for id: String in run.layout.rooms:
		var room: Dictionary = run.layout.rooms[id]
		var color: Color = COLORS[_stage(id)]
		var box := Rect2(transform*room.bounds.position,room.bounds.size*scale_value)
		draw_rect(box,Color("101b1c")); draw_rect(box,color.darkened(.35),false,2)
		for pond: Dictionary in FIELD.world_ponds(room): _pond(pond,transform)
		var label: String = run.LABELS[room.kind]+("·汇合" if id in ["treasure_merge","battle_merge","last_rest"] else "")
		var at: Vector2 = transform*room.bounds.get_center()
		var font_size := clampi(int(scale_value*.65),14,22)
		var extent := Ink.serif.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		draw_string(Ink.serif,at+Vector2(-extent.x*.5,4),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("e0d4b6"))
		var short_id := id.replace("opening_","前庭 ").replace("start","起点").replace("treasure_merge","一").replace("battle_merge","二").replace("last_rest","三").replace("boss","终庭")
		var width := Ink.serif.get_string_size(short_id,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(Ink.serif,at+Vector2(-width*.5,21),short_id,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
		for port: Dictionary in room.edge_ports.values():
			var foot: Vector2 = transform*port.at
			var normal: Vector2 = port.normal
			var tangent := Vector2(-normal.y,normal.x)
			draw_line(foot-tangent*scale_value*.35,foot+tangent*scale_value*.35,Color("f0d496"),3,true)
	if show_walk:
		for cell in run.layout.cells:
			var entry: Dictionary = run.layout.cells[cell]
			draw_circle(transform*run.layout.point(cell),.8,Color(.8,.85,.65,.5) if entry.edges.is_empty() else Color(.9,.6,.3,.7))
	draw_string(Ink.serif,Vector2(24,size.y-24),"所有分叉均已显示。空间相邻只共用边界，实际推进仍须经过院门；水与景观地面不能绕过节点。",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("c5b58e"))


func _stage(id: String) -> int:
	if id.begins_with("g1") or id=="battle_merge": return 1
	if id.begins_with("g2") or id in ["last_rest","boss"]: return 2
	return 0


func _pond(pond: Dictionary, transform: Transform2D) -> void:
	var points := PackedVector2Array()
	for i in 64:
		var angle := i*TAU/64.0
		var phase: float = int(pond.seed)*.173
		var edge := 1.0+.055*sin(angle*3+phase)+.035*cos(angle*5-phase)
		points.append(transform*(pond.center+(Vector2(cos(angle),sin(angle))*pond.radius*edge).rotated(float(pond.get("turn",0)))))
	draw_colored_polygon(points,Color("102e39"))
	draw_polyline(points,Color("718c84"),2,true)


func capture() -> void:
	get_window().size = Vector2i(1400,1100); get_window().content_scale_size = Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for index in SEEDS.size():
		seed_menu.select(index); select_seed(SEEDS[index])
		await get_tree().process_frame; await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(OUTPUT.path_join("%02d-plan-seed-%d.png" % [index+1,SEEDS[index]]))
		print("[WholeGardenPlan] seed=",SEEDS[index]," rooms=",run.graph.rooms.size()," bounds=",run.layout.clusters[0].bounds," candidate=",run.graph.site_plan.candidate," ponds=",run.layout.clusters[0].ponds.size())
	get_tree().quit()
