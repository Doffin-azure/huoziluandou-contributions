extends Node3D
const PLAN = preload("res://src/expedition/garden_cluster_plan.gd")
const FIELD = preload("res://src/expedition/garden_pond_field.gd")
const TERRAIN = preload("res://src/map/garden_pond_ground.gd")
const BOUNDARY = preload("res://src/map/expedition_garden_boundary.gd")
const ARCH = preload("res://src/map/expedition_garden_architecture.gd")
const LEAVES = preload("res://src/map/expedition_lotus_leaf_layer.gd")
const LOTUS = preload("res://src/map/expedition_lotus_tile.gd")
var cluster: Dictionary
var layout: RefCounted
var style: ExpeditionFlatStyle
var paints: Array[ShaderMaterial] = []
var segments: Array = []
var wall_roots := {}
var post_roots := {}
var gates: Array = []
var plants: Array = []
var ornaments: Array = []


func build(data: Dictionary, room_layout: RefCounted, painter: ExpeditionFlatStyle) -> void:
	cluster = data; layout = room_layout; style = painter
	var ponds: Array = cluster.ponds.duplicate(true)
	for id in cluster.members: ponds.append_array(FIELD.world_ponds(layout.rooms[id]))
	var soil := _paint(Color("253a32")); var stone := _paint(style.palette.stone_front)
	TERRAIN.build(self,cluster.bounds,ponds,style,soil,stone,-.005)
	# The bottom and perimeter only: no slab cap covers the pond holes.
	var bounds: Rect2 = cluster.bounds
	for entry in [[Vector3(bounds.get_center().x,-.38,bounds.position.y+.04),Vector3(bounds.size.x,.75,.08)],[Vector3(bounds.get_center().x,-.38,bounds.end.y-.04),Vector3(bounds.size.x,.75,.08)],[Vector3(bounds.position.x+.04,-.38,bounds.get_center().y),Vector3(.08,.75,bounds.size.y)],[Vector3(bounds.end.x-.04,-.38,bounds.get_center().y),Vector3(.08,.75,bounds.size.y)]]:
		var masonry := style.mesh(self,TypeMeshes.beveled_box(entry[1],.005),entry[0],"architecture",0)
		masonry.material_override = stone
	for descriptor: Dictionary in cluster.ornaments:
		var scene: PackedScene = load("res://assets/expedition/garden/%s.tscn" % descriptor.scene)
		var item: Node3D = scene.instantiate(); item.position = Vector3(descriptor.at.x,0,descriptor.at.y)
		item.scale = Vector3.ONE*float(descriptor.scale); add_child(item); item.setup(style)
		ornaments.append({"node":item,"at":descriptor.at})
	segments = PLAN.wall_segments(cluster)
	for descriptor: Dictionary in cluster.gates:
		var gate := ARCH.new(); gate.building = ARCH.Building.MOON_GATE; gate.open_floor_passage = true
		gate.position = Vector3(descriptor.at.x,0,descriptor.at.y); gate.scale = Vector3.ONE*.5
		gate.rotation.y = PI*.5 if descriptor.side=="E" else 0.0
		add_child(gate); gate.setup(style); gates.append(gate)
	for pond: Dictionary in cluster.ponds:
		for n in 3:
			var center: Vector2 = pond.center+Vector2(0,(n-1)*pond.radius.y*.53)
			var layer := LEAVES.new(); layer.position = Vector3(center.x,0,center.y)
			layer.half_extent = Vector2(pond.radius.x*.86,pond.radius.y*.23)
			layer.layout_seed = int(cluster.seed)+n*137; layer.small_leaf_count = 7; layer.large_leaf_count = 2
			layer.water_height = -.45; layer.water_test = func(point: Vector2): return FIELD.sample(cluster.ponds,center+point)>.03
			add_child(layer); layer.setup(style); plants.append({"node":layer,"at":center})
			var flower := LOTUS.new(); flower.plants_only = true; flower.scale = Vector3.ONE*.55
			flower.position = Vector3(center.x+.35,0,center.y+.1); flower.water_height = -.45/.55
			var flower_at := Vector2(flower.position.x,flower.position.z)
			flower.water_test = func(point: Vector2): return FIELD.sample(cluster.ponds,flower_at+point*.55)>.03
			add_child(flower); flower.setup(style); plants.append({"node":flower,"at":flower_at})


func _paint(color: Color) -> ShaderMaterial:
	var paint := ShaderMaterial.new(); paint.shader = preload("res://src/shaders/garden_planted_ground.gdshader")
	paint.set_shader_parameter("tint",color)
	# 白色兜底：cluster 刚建好、update_fog 尚未调用的那一帧也要有地面。
	var white_image := Image.create(1,1,false,Image.FORMAT_RGBA8); white_image.fill(Color.WHITE)
	paint.set_shader_parameter("fog_mask",ImageTexture.create_from_image(white_image))
	paint.set_shader_parameter("vision_origin",Vector2.ZERO)
	paint.set_shader_parameter("vision_size",Vector2(4096,4096))
	paint.set_shader_parameter("clip_vision_bounds",false)
	paints.append(paint)
	return paint


func update_fog(mask: Texture2D, bounds: Rect2) -> void:
	for paint in paints:
		paint.set_shader_parameter("fog_mask",mask); paint.set_shader_parameter("vision_origin",bounds.position)
		paint.set_shader_parameter("vision_size",bounds.size); paint.set_shader_parameter("clip_vision_bounds",true)


func refresh(run: RefCounted, player: Vector2, reveal_all := false) -> void:
	var needed_posts := {}
	for i in segments.size():
		var segment: Dictionary = segments[i]
		var known := reveal_all or _known(run,segment.center,3.0)
		# 已加载的墙段多保留一段距离，避免玩家跨过阈值时整段闪现/消失。
		var wall_radius := 22.0 if wall_roots.has(i) else 18.0
		var needed: bool = known and (reveal_all or player.distance_to(segment.center)<wall_radius)
		if not needed:
			if wall_roots.has(i): wall_roots[i].queue_free(); wall_roots.erase(i)
			continue
		if not wall_roots.has(i):
			var holder := Node3D.new(); holder.scale = Vector3.ONE*.5; add_child(holder)
			var group := BOUNDARY.assemble(holder,style,[Vector3(segment.a.x*2,0,segment.a.y*2),Vector3(segment.b.x*2,0,segment.b.y*2)],true,false,i%4==1)
			for part in group.get_children():
				if part.piece in [BOUNDARY.Piece.WALL_POST,BOUNDARY.Piece.WALL_END]: group.remove_child(part); part.queue_free()
			wall_roots[i] = holder
		for point: Vector2 in [segment.a,segment.b]: needed_posts[str(point)] = point
	for key in post_roots.keys():
		if not needed_posts.has(key): post_roots[key].queue_free(); post_roots.erase(key)
	for key in needed_posts:
		if post_roots.has(key): continue
		var at: Vector2 = needed_posts[key]
		if cluster.gates.any(func(gate): return absf(gate.at.distance_to(at)-1.0)<.01): continue
		var post := BOUNDARY.new(); post.piece = BOUNDARY.Piece.WALL_POST; post.scale = Vector3.ONE*.5
		post.position = Vector3(at.x,0,at.y); add_child(post); post.setup(style); post_roots[key] = post
	for gate in gates:
		gate.visible = reveal_all or _known(run,Vector2(gate.position.x,gate.position.z),3.0)
		gate.set_lamps_enabled(false)
	for plant in plants: plant.node.visible = reveal_all or _known(run,plant.at,4.0)
	for item in ornaments:
		item.node.visible = reveal_all or _known(run,item.at,4.0)
		item.node.set_lamps_enabled(false)


func _known(run: RefCounted, point: Vector2, margin: float) -> bool:
	for id in cluster.members:
		if run.visited_rooms.has(id) and layout.rooms[id].bounds.grow(margin).has_point(point): return true
	return false
