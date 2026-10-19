extends RefCounted
class_name ExpeditionMapProps
## Shared markers/actors, with native painted assets when map_art is configured.
const TEAL := Color("234647")
const GOLD := Color("ac8545")
const STONE := Color("52615c")
const RED := Color("a63630")
const PAPER := Color("e6d7af")
var actors: Array[Texture2D] = []
var props: Array[Texture2D] = []
var camera_up := Vector3(0,0.707107,-0.707107)
var _plain_cache: Dictionary = {}
var _surface_cache: Dictionary = {}
var _atlas: Texture2D
var _alpha_images: Dictionary = {}
var map_art: ExpeditionMapArt


func _init(pitch_degrees := 45.0) -> void:
	camera_up = Vector3(0,cos(deg_to_rad(pitch_degrees)),-sin(deg_to_rad(pitch_degrees)))
	if ResourceLoader.exists("res://assets/expedition/architecture-materials-v2.png"):
		_atlas = load("res://assets/expedition/architecture-materials-v2.png")
	var source: Texture2D = load("res://assets/expedition/map-actors.png")
	var regions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/expedition/map-actors.json")).regions
	for region: Array in regions:
		var texture := AtlasTexture.new()
		texture.atlas = source
		texture.region = Rect2(region[0], region[1], region[2], region[3])
		texture.filter_clip = true
		actors.append(texture)
	var prop_source: Texture2D = load("res://assets/expedition/map-props.png")
	var prop_regions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/expedition/map-props.json")).regions
	for region: Array in prop_regions:
		var texture := AtlasTexture.new()
		texture.atlas = prop_source
		texture.region = Rect2(region[0],region[1],region[2],region[3])
		texture.filter_clip = true
		props.append(texture)


func plain(color: Color, unshaded := true) -> StandardMaterial3D:
	var key := str(color) + str(unshaded)
	if _plain_cache.has(key): return _plain_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_plain_cache[key] = material
	return material


func surface_material(index: int, tint := Color.WHITE) -> Material:
	var key := str(index) + str(tint)
	if _surface_cache.has(key): return _surface_cache[key]
	if _atlas == null: return plain(tint * TEAL.lightened(0.3))
	var material := ShaderMaterial.new()
	material.shader = load("res://src/shaders/expedition_architecture.gdshader")
	material.set_shader_parameter("atlas", _atlas)
	material.set_shader_parameter("quadrant", Vector2(index % 2, index / 2))
	material.set_shader_parameter("tint",tint)
	material.set_meta("tint_value",tint)
	_surface_cache[key] = material
	return material


func box(parent: Node3D, pos: Vector3, dimensions: Vector3, material: Material, bevel := 0.018) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = TypeMeshes.beveled_box(dimensions, bevel)
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh


func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = 8
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = (a + b) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	parent.add_child(mesh)
	return mesh


func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	return rod(parent, pos-Vector3.UP*height*0.5, pos+Vector3.UP*height*0.5, radius, material)


func panel(parent: Node3D, pos: Vector3, dimensions: Vector2, material: Material) -> MeshInstance3D:
	var shape := QuadMesh.new()
	shape.size = dimensions
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh


func actor(parent: Node3D, index: int, height: float) -> Node3D:
	if parent.has_meta("k"):
		parent.set_meta("card_height",height)
		parent.set_meta("card_width",height*actors[index].get_width()/actors[index].get_height())
		parent.set_meta("card_texture",actors[index])
	var result := _cutout(parent,actors[index],height)
	result.set_meta("card_height",height)
	result.set_meta("card_width",height*actors[index].get_width()/actors[index].get_height())
	result.set_meta("card_texture",actors[index])
	return result


func illustration(parent: Node3D, index: int, height: float) -> Node3D:
	var result := _cutout(parent,props[index],height)
	parent.set_meta("card_height",height)
	parent.set_meta("card_width",height*props[index].get_width()/props[index].get_height())
	parent.set_meta("card_texture",props[index])
	return result


func opaque_at(texture: Texture2D, uv: Vector2) -> bool:
	if uv.x<0 or uv.x>=1 or uv.y<0 or uv.y>=1: return false
	var key := texture.get_instance_id()
	if not _alpha_images.has(key):
		var source := texture.get_image()
		if source.is_compressed(): source.decompress()
		_alpha_images[key] = source
	var image: Image = _alpha_images[key]
	return image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),clampi(int(uv.y*image.get_height()),0,image.get_height()-1)).a>=0.16


func _cutout(parent: Node3D, texture: Texture2D, height: float) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = height / texture.get_height()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = false
	sprite.shaded = map_art!=null
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.16
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The image plane is camera-facing, so its centre follows the camera's up
	# vector. Its bottom pixel stays precisely at the world-space foot anchor.
	sprite.position = camera_up * height * 0.5
	sprite.set_meta("illustrated",true)
	holder.add_child(sprite)
	shadow(holder, 0.19 + height * 0.06)
	return holder


func shadow(parent: Node3D, radius: float) -> void:
	glow(parent,radius*1.4,Color(0.018,0.032,0.029,0.44))


func glow(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var shape := PlaneMesh.new()
	shape.size = Vector2.ONE*radius*2
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position.y = 0.018
	var material := ShaderMaterial.new()
	material.shader = load("res://src/shaders/expedition_ground_glow.gdshader")
	material.set_shader_parameter("tint",color)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func label(parent: Node3D, text: String, position: Vector3, color := PAPER, size := 40, pixel_size := 0.008) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font = Ink.serif
	node.font_size = size
	node.pixel_size = pixel_size
	node.modulate = color
	node.outline_size = 0
	node.position = position
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(node)
	return node


func chest(parent: Node3D, tier: int, opened: bool) -> void:
	if map_art!=null:
		map_art.chest(parent,tier,opened)
		return
	illustration(parent,3 if opened else tier,0.40+tier*0.13)


func facility(parent: Node3D, type: String, used: bool, mount_offset := Vector3.ZERO, mount_turn := 0.0) -> void:
	if map_art!=null:
		map_art.facility(parent,type,used,true,mount_offset,mount_turn)
		return
	var index: int = {"起":15,"休":4,"市":5,"谜":6,"巢":7}.get(type,15)
	var height: float = {"起":0.25,"休":1.28,"市":1.16,"谜":1.23,"巢":1.56}.get(type,1.2)
	var card := illustration(parent,index,height)
	if used and type in ["休","谜"]:
		tint_tree(card,Color("9d9d87"))
		var notice := panel(parent,Vector3(0,0.22,0.25),Vector2(0.42,0.16),plain(PAPER.darkened(0.15)))
		notice.rotation_degrees.x = -45
		notice.rotation_degrees.z = -9
		label(parent,"已用",Vector3(0,0.23,0.27),TEAL,28,0.0055)
	elif type=="休":
		glow(parent,0.52,Color(0.94,0.63,0.22,0.20))


func glyph(parent: Node3D, text: String, guarded: bool) -> void:
	if map_art!=null:
		map_art.inlay(parent,text,Vector3(0,.018,0),1.35)
		if guarded: map_art.box(parent,Vector3(.29,.022,.29),Vector3(.09,.008,.09),"seal",0)
		return
	var block := box(parent,Vector3(0,0.11,0),Vector3(0.35,0.22,0.29),plain(Color("76674a")))
	block.rotation_degrees.x = -9
	var face := panel(parent,Vector3(0,0.25,0.06),Vector2(0.35,0.37),plain(PAPER.darkened(0.12) if guarded else PAPER,true))
	face.rotation_degrees.x = -55
	label(parent,text,Vector3(0,0.27,0.085),Color("182b29"),56,0.0054)
	if guarded:
		var seal := panel(parent,Vector3(0,0.28,0.10),Vector2(0.39,0.045),plain(RED,true))
		seal.rotation_degrees.x = -55
		seal.rotation_degrees.z = -30
	shadow(parent,0.23)


func barrier(parent: Node3D, cleared: bool) -> void:
	if map_art!=null:
		map_art.barrier(parent,cleared)
		return
	illustration(parent,13 if cleared else 8,0.27 if cleared else 0.78)
	if not cleared: label(parent,"封",Vector3(0,0.40,0.20),PAPER,32,0.006)


func mechanism(parent: Node3D, mc: Dictionary, used: bool, shut: bool) -> void:
	if map_art!=null:
		map_art.mechanism(parent,mc,used,shut)
		return
	var g := str(mc.g)
	if g in ["泉","炉"]:
		var card := illustration(parent,11 if used else 9,0.37 if used else 0.83)
		if g=="炉": tint_tree(card,Color(1.0,0.75,0.58))
	elif g=="纸":
		illustration(parent,10,0.33)
	elif g in ["潮","闸"]:
		for x in [-0.35,0.35]: box(parent,Vector3(x,0.25,0),Vector3(0.1,0.5,0.23),surface_material(0))
		var y := 0.37 if shut else 0.05
		for i in 4: box(parent,Vector3(-0.24+i*0.16,y,0),Vector3(0.038,0.48 if shut else 0.03,0.055),plain(RED if shut else GOLD))
	elif g in ["桩","焰"]:
		cylinder(parent,Vector3(0,0.16 if used else 0.25,0),0.14,0.30 if used else 0.5,surface_material(0))
		cylinder(parent,Vector3(0,0.31 if used else 0.51,0),0.10,0.08,plain(GOLD.darkened(0.6) if used else Color("efb85c"),true))
	else:
		box(parent,Vector3(0,0.025,0),Vector3(0.7,0.04,0.7),plain(TEAL.lightened(0.2)))
	if mc.kind == "slide":
		var direction: Vector2i = mc.get("dir",Vector2i.ZERO)
		label(parent,{Vector2i(0,1):"→",Vector2i(1,0):"↓",Vector2i(0,-1):"←",Vector2i(-1,0):"↑"}.get(direction,"流"),Vector3(0,0.10,0),GOLD,48,0.009)
	elif g not in ["泉","纸"]: label(parent,g,Vector3(0,0.32,0.15),PAPER,32,0.006)


func tint_tree(node: Node, tint: Color) -> void:
	if map_art!=null:
		map_art.shade(node,minf(tint.r,minf(tint.g,tint.b)))
		return
	if node is Sprite3D or node is Label3D:
		if not node.has_meta("base_modulate"): node.set_meta("base_modulate",node.modulate)
		node.modulate = node.get_meta("base_modulate") * tint
	elif node is MeshInstance3D and node.material_override != null:
		if not node.has_meta("base_material"): node.set_meta("base_material",node.material_override)
		var base: Material = node.get_meta("base_material")
		var material := base.duplicate()
		if material is StandardMaterial3D: material.albedo_color *= tint
		elif material is ShaderMaterial and material.has_meta("tint_value"):
			var old: Color = material.get_meta("tint_value",Color.WHITE)
			material.set_shader_parameter("tint",old*tint)
		node.material_override = material
	for child in node.get_children(): tint_tree(child,tint)
