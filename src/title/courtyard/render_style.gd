extends RefCounted
## Render-only pigments. Authoring materials and the portable model stay intact.
const PIGMENT := preload("res://src/title/courtyard/pigment.gdshader")
const OUTLINE := preload("res://src/title/courtyard/ink_outline.gdshader")
const INK_GROUPS := ["Columns", "TieBeams", "EntryLintels", "EntryDoorPanels", "CurvedFascia", "RidgeCaps", "PoolCoping", "ColumnPlinths", "ArchivePlaque", "Planters", "LanternSilk", "LanternCaps"]
const GILT_GROUPS := ["PostCaps", "CurvedFascia", "EntryMouldings", "LintelCarving", "DoorPanelRails"]
var _materials: Dictionary = {}
var material_count := 0
var outlined_count := 0


func apply(architecture: Node3D, landscape: Node3D) -> void:
	var palette = architecture.palette
	var roles := {
		palette.wood: ["223438", "4f5649", "8c825f"],
		palette.paint: ["102d35", "23605d", "4b8171"],
		palette.dark_paint: ["0b1b26", "173b40", "2c5654"],
		palette.stone: ["192f37", "385653", "718377"],
		palette.plaster: ["344c4d", "8d9c85", "cbbd94"],
		palette.roof: ["0d2a34", "24545b", "497775"],
		palette.brass: ["3a3d32", "9b783a", "ccb16b"],
		palette.paper: ["89937b", "c3b387", "e1cca0"],
		palette.red: ["471b2c", "9d2635", "c34c45"],
	}
	for instance in architecture.get_children():
		if instance is not MeshInstance3D: continue
		var source: StandardMaterial3D = instance.material_override
		if source == null: continue
		var colors: Array = roles.get(source, ["10252f", "285153", "507572"])
		for group in GILT_GROUPS:
			if str(instance.name).begins_with(group): colors = ["303c35", "7b6942", "b19a5e"]
		# Suppress facet chatter in the curved soffit, while keeping the rafters distinct.
		if str(instance.name).begins_with("RoofSoffits"): colors = ["1a2e35", "263e42", "3b514f"]
		instance.material_override = _pigment(source, colors, _needs_outline(instance.name))
		if str(instance.name).begins_with("TerraceBoards"):
			# Let the two low lanterns paint a warm pool on the boards. Keep this
			# local to the foreground, instead of tinting the whole garden orange.
			instance.material_override = instance.material_override.duplicate()
			instance.material_override.set_shader_parameter("local_light_gain",.92)
	var flower_index := 0
	var cliff_index := 0
	for instance in landscape.get_children():
		if instance is not MeshInstance3D: continue
		var source: StandardMaterial3D = instance.material_override
		var colors: Array
		var leaves := false
		if str(instance.name).begins_with("CherryBlossoms"):
			var reds := [
				["50172d", "ad2f42", "c64a4d"],
				["571c31", "b83849", "d05454"],
				["4d192c", "a52e40", "c14749"],
				["521a30", "b03246", "ca4a50"]]
			colors = reds[flower_index % reds.size()]
			flower_index += 1
			leaves = true
			# Tiny petal shadows make a stippled mess on the columns and ground.
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif str(instance.name).begins_with("DistantCliffs"):
			var layers := ["135059", "1a666b", "207b79"]
			var flat := StandardMaterial3D.new()
			flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			flat.albedo_color = Color(layers[cliff_index % 3])
			flat.cull_mode = BaseMaterial3D.CULL_DISABLED
			instance.material_override = flat
			cliff_index += 1
			continue
		elif str(instance.name).begins_with("TreeBranches"):
			colors = ["111e2b", "2d3940", "51534a"]
		elif str(instance.name).begins_with("LanternSilk") or str(instance.name).begins_with("LanternTassels"):
			colors = ["641f30", "bd3b40", "e07950"]
		else:
			colors = ["343b30", "957442", "c3a464"]
		instance.material_override = _pigment(source, colors, _needs_outline(instance.name), leaves)
	var lettering := architecture.get_node_or_null("ArchiveLettering") as Label3D
	if lettering != null:
		lettering.shaded = false
		lettering.modulate = Color("dfc68d")
		lettering.no_depth_test = false
		# Put the glyphs in the opaque image sampled by the contour pass.
		lettering.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		lettering.alpha_scissor_threshold = 0.4


func _needs_outline(node_name: String) -> bool:
	for group in INK_GROUPS:
		if node_name.begins_with(group): return true
	return false


func _pigment(source: StandardMaterial3D, colors: Array, outline: bool, leaves := false) -> ShaderMaterial:
	var key := str(source.get_instance_id()) + str(outline) + str(colors) + str(leaves)
	if _materials.has(key): return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = PIGMENT
	material.set_shader_parameter("shade_ink", Color(colors[0]))
	material.set_shader_parameter("pigment_mid", Color(colors[1]))
	material.set_shader_parameter("pigment_light", Color(colors[2]))
	material.set_shader_parameter("foliage", leaves)
	_set_breeze(material, source, leaves)
	material.set_shader_parameter("grain_amount", 0.28 if source.albedo_texture != null else 0.0)
	material.set_shader_parameter("grain_scale", source.uv1_scale.x)
	if source.albedo_texture != null:
		material.set_shader_parameter("grain_texture", source.albedo_texture)
	if outline:
		var ink := ShaderMaterial.new()
		ink.shader = OUTLINE
		_set_breeze(ink, source, leaves)
		material.next_pass = ink
		outlined_count += 1
	_materials[key] = material
	material_count += 1
	return material


func _set_breeze(material: ShaderMaterial, source: StandardMaterial3D, leaves: bool) -> void:
	material.set_shader_parameter("wind_mode", 1 if leaves else int(source.get_meta("wind_mode", 0)))
	material.set_shader_parameter("lantern_pivot", source.get_meta("lantern_pivot", Vector3.ZERO))
	material.set_shader_parameter("wind_phase", source.get_meta("wind_phase", 0.0))
