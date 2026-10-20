extends RefCounted
class_name ExpeditionMapArt
## Runtime adapters for the approved art studies. Gameplay remains in Expedition.
const REST = preload("res://src/map/expedition_rest_pavilion.gd")
const STALL = preload("res://src/map/expedition_type_stall.gd")
const SHRINE = preload("res://src/map/expedition_stylized_shrine.gd")
const GATE = preload("res://src/map/expedition_beast_gate.gd")
const CASKET = preload("res://src/map/expedition_reward_casket.gd")
const LAMP = preload("res://src/map/expedition_bronze_lamp.gd")
const BARRIER = preload("res://src/map/expedition_sealed_barrier.gd")
const TOMB = preload("res://src/map/expedition_tombstone.gd")
const TREE = preload("res://src/map/expedition_stylized_tree.gd")
const INLAY = preload("res://src/map/expedition_inlaid_glyph.gd")
const FIRE = preload("res://src/map/expedition_stylized_fire.gd")
const GARDEN_ASSETS = preload("res://src/expedition/garden_asset_layout.gd")
var style: ExpeditionFlatStyle
var camera: Camera3D
var environment: Environment
var ground_material: ShaderMaterial
var _shade_materials: Dictionary = {}


func reset_material_tracking() -> void:
	_shade_materials.clear()


func _init(painter: ExpeditionFlatStyle, view_camera: Camera3D, settings: Environment) -> void:
	style = painter
	camera = view_camera
	environment = settings


func _asset(parent: Node3D, script: Script, scale_value: float) -> Node3D:
	var node: Node3D = script.new()
	node.scale = Vector3.ONE*scale_value
	parent.add_child(node)
	node.setup(style)
	return node


func bounds(parent: Node3D, height: float, width: float, depth := .75) -> void:
	parent.set_meta("pick_height",height)
	parent.set_meta("visual_height",height)
	parent.set_meta("visual_width",width)
	parent.set_meta("pick_size",Vector3(width,height,depth))
	parent.set_meta("pick_offset",Vector3(0,0,-.20))
	parent.set_meta("tall",height>.65)
	parent.set_meta("native_art",true)


func inlay(parent: Node3D, text: String, position := Vector3(0,.015,.18), scale_value := 1.05, spent := false) -> Node3D:
	var mark := INLAY.new()
	mark.position = position
	mark.scale = Vector3.ONE*scale_value
	parent.add_child(mark)
	mark.setup(text,style.palette,Ink.serif)
	mark.set_floor_imprint(true,ground_material)
	mark.set_spent(spent)
	return mark


func _hide_asset_inlays(node: Node3D) -> void:
	for child in node.get_children():
		if child.get_script()==INLAY: child.visible = false


func chest(parent: Node3D, tier: int, opened: bool) -> void:
	var size_value := .52+tier*.11
	var node := _asset(parent,CASKET,size_value)
	node.position.z = -.21
	node.set_alternate_state(opened)
	_hide_asset_inlays(node)
	inlay(parent,["小","中","大"][tier],Vector3(0,.018,.27),.90,opened)
	bounds(parent,(1.32 if opened else .74)*size_value,1.10*size_value)


func facility(parent: Node3D, type: String, used: bool, show_marker := true, mount_offset := Vector3.ZERO, mount_turn := 0.0) -> void:
	var node: Node3D
	match type:
		"休":
			node = _asset(parent,REST,.49)
			node.set_alternate_state(used)
			bounds(parent,1.00,1.00)
		"市":
			node = _asset(parent,STALL,.48)
			bounds(parent,.82,.95)
		"谜":
			node = _asset(parent,SHRINE,.58)
			node.set_scene_lighting(true)
			node.set_lamp_lit(not used)
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(.26,.52,.28)
			lamp.light_color = style.palette.fire_light
			lamp.light_energy = .65
			lamp.omni_range = .95
			lamp.visible = not used
			node.add_child(lamp)
			bounds(parent,1.03,.90)
		"起","巢":
			var scale_value := .43 if type=="起" else .50
			node = _asset(parent,GATE,scale_value)
			node.set_alternate_state(true)
			bounds(parent,2.0*scale_value,2.3*scale_value)
	node.position = mount_offset if mount_offset!=Vector3.ZERO else Vector3(0,0,-.28)
	node.rotation.y = mount_turn
	var envelope := GARDEN_ASSETS.envelope(type,node.position,mount_turn)
	parent.set_meta("pick_offset",Vector3(envelope.get_center().x,0,envelope.get_center().y))
	parent.set_meta("pick_size",Vector3(envelope.size.x,float(parent.get_meta("pick_height")),envelope.size.y))
	parent.set_meta("visual_width",envelope.size.x)
	_hide_asset_inlays(node)
	if show_marker: inlay(parent,type,Vector3(0,.018,.27),.90,used)


func barrier(parent: Node3D, cleared: bool) -> void:
	var node := _asset(parent,BARRIER,.58)
	node.position.z = -.21
	node.set_alternate_state(cleared)
	_hide_asset_inlays(node)
	inlay(parent,"障",Vector3(0,.018,.27),.90,cleared)
	bounds(parent,.18 if cleared else .70,.84)


func tree(parent: Node3D, scale_value := .70) -> Node3D:
	var node := TREE.new()
	parent.add_child(node)
	node.setup(style,camera)
	# sync_camera sets a global basis; scale afterward to retain map proportions.
	node.scale = Vector3.ONE*scale_value
	bounds(parent,2.15*scale_value,1.85*scale_value,.70)
	return node


func tomb(parent: Node3D, kind: int, scale_value := .48) -> Node3D:
	var node := TOMB.new()
	node.variant = kind
	node.scale = Vector3.ONE*scale_value
	parent.add_child(node)
	node.setup(style)
	return node


func lamp(parent: Node3D, scale_value := .46, spent := false) -> Node3D:
	var node := _asset(parent,LAMP,scale_value)
	node.set_alternate_state(spent)
	return node


func fire(parent: Node3D, scale_value := .70) -> Node3D:
	var node := FIRE.new()
	parent.add_child(node)
	node.set_ghost_fire(true)
	node.setup(style,camera,environment,false)
	node.scale = Vector3.ONE*scale_value
	return node


func box(parent: Node3D, pos: Vector3, size: Vector3, role: String, outline := .45) -> MeshInstance3D:
	return style.mesh(parent,TypeMeshes.beveled_box(size,.008),pos,role,outline)


func mechanism(parent: Node3D, mc: Dictionary, used: bool, shut: bool) -> void:
	var geometry := Node3D.new()
	geometry.position.z = -.20
	parent.add_child(geometry)
	var g := str(mc.g)
	match g:
		"泉":
			box(geometry,Vector3(0,.06,0),Vector3(.70,.12,.52),"architecture")
			box(geometry,Vector3(0,.13,0),Vector3(.54,.025,.36),"roof",.2)
			for x in [-.31,.31]: box(geometry,Vector3(x,.17,0),Vector3(.09,.14,.50),"stone")
			for z in [-.22,.22]: box(geometry,Vector3(0,.17,z),Vector3(.54,.14,.08),"stone")
			box(geometry,Vector3(0,.30,-.22),Vector3(.22,.24,.13),"patina")
			if not used: box(geometry,Vector3(0,.245,-.12),Vector3(.10,.10,.12),"roof",.2)
		"纸":
			for i in 3:
				var paper := box(geometry,Vector3((i-1)*.06,.018+i*.008,0),Vector3(.48,.012,.53),"bronze",.15)
				paper.rotation.y = (i-1)*.07
			box(geometry,Vector3(.07,.049,-.04),Vector3(.27,.008,.31),"patina",0)
		"潮","闸":
			for x in [-.32,.32]: box(geometry,Vector3(x,.24,0),Vector3(.13,.48,.22),"patina")
			box(geometry,Vector3(0,.48,0),Vector3(.80,.09,.24),"copper_dark")
			for i in 4: box(geometry,Vector3(-.24+i*.16,.25 if shut else .035,0),Vector3(.055,.42 if shut else .05,.065),"cloth" if shut else "copper_dark",.3)
		"焰":
			fire(geometry,.62)
		"炉","桩":
			var node := lamp(geometry,.37,used)
			if g!="桩":
				node.position.y = -.06
				box(geometry,Vector3(0,.12,0),Vector3(.42,.24,.38),"architecture")
		"渗":
			box(geometry,Vector3(0,.025,0),Vector3(.46,.05,.46),"copper_dark",.2)
			box(geometry,Vector3(0,.052,0),Vector3(.33,.012,.33),"roof",.15)
		"吊":
			for x in [-.25,.25]: box(geometry,Vector3(x,.24,0),Vector3(.065,.48,.075),"patina",.25)
			box(geometry,Vector3(0,.48,0),Vector3(.62,.075,.09),"copper_dark",.3)
			box(geometry,Vector3(0,.34,0),Vector3(.025,.23,.025),"bronze",.15)
		"线":
			box(geometry,Vector3(0,.065,0),Vector3(.32,.13,.28),"copper_dark",.25)
			box(geometry,Vector3(0,.15,0),Vector3(.16,.06,.14),"roof" if shut else "patina",.2)
	if g in ["流","吊"]:
		var direction: Vector2i = mc.get("dir",Vector2i.ZERO)
		var arrow := str({Vector2i(0,1):"→",Vector2i(1,0):"↓",Vector2i(0,-1):"←",Vector2i(-1,0):"↑"}.get(direction,"流"))
		inlay(parent,arrow,Vector3(.30,.015,-.22),.48)
	inlay(parent,g,Vector3(0,.025,.27),.90,used or (mc.kind=="wire" and shut))
	bounds(parent,.65,.78)


func shade(node: Node, value: float) -> void:
	if node.get_script()==INLAY: node.set_in_sight(value>.9)
	if node is Sprite3D or node is Label3D:
		if not node.has_meta("base_modulate"): node.set_meta("base_modulate",node.modulate)
		node.modulate = node.get_meta("base_modulate")*Color(value,value,value)
	elif node is MeshInstance3D and node.material_override!=null:
		if not node.has_meta("map_base_material"): node.set_meta("map_base_material",node.material_override)
		var base: Material = node.get_meta("map_base_material")
		if value>.99:
			node.material_override = base
		else:
			# Reuse a dim variant of each shared paint. Changing sight does not
			# allocate a new material for every small roof beam or ink stroke.
			var key := str(base.get_instance_id())+":"+str(value)
			if not _shade_materials.has(key):
				var paint: Material = base.duplicate()
				if paint is ShaderMaterial:
					paint.set_shader_parameter("map_shade",value)
				elif paint is StandardMaterial3D:
					paint.albedo_color *= Color(value,value,value)
					paint.emission_energy_multiplier = 0.0
				_shade_materials[key] = paint
			node.material_override = _shade_materials[key]
	if node is Light3D:
		if not node.has_meta("base_visible"): node.set_meta("base_visible",node.visible)
		node.visible = bool(node.get_meta("base_visible")) and value>.9
	for child in node.get_children(): shade(child,value)
