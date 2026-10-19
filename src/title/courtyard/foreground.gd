extends Node3D
## Two real lanterns light the existing terrace. Instanced leaves sit on its
## boards; lantern frames and leaves share the title world's camera/depth.
const Workshop = preload("res://src/title/courtyard/mesh_workshop.gd")
var lamps: Array[OmniLight3D] = []
var leaves: MultiMeshInstance3D


func build() -> void:
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color("111f24"); dark.roughness = .92
	var copper := StandardMaterial3D.new(); copper.albedo_color = Color("7b6944"); copper.roughness = .85
	var silk := StandardMaterial3D.new(); silk.albedo_color = Color("e7ad62")
	silk.emission_enabled = true; silk.emission = Color("e39a45"); silk.emission_energy_multiplier = .7
	for at: Vector3 in [Vector3(-1.85,.275,5.9),Vector3(4.25,.275,5.45)]:
		var root := Node3D.new(); root.name = "TerraceLanternLeft" if lamps.is_empty() else "TerraceLanternRight"; root.position = at; add_child(root)
		var model := Workshop.new()
		model.box(Vector3(0,.10,0),Vector3(.66,.20,.64),dark)
		model.box(Vector3(0,.24,0),Vector3(.51,.10,.50),copper)
		model.box(Vector3(0,.32,0),Vector3(.61,.08,.59),dark)
		# Glowing paper stops below the roof. The open frame casts an actual
		# lattice shadow; the paper itself must not block the light inside it.
		model.box(Vector3(0,.79,0),Vector3(.47,.82,.45),silk,Vector3.ZERO,"LitPaper")
		for x in [-.275,.275]:
			for z in [-.265,.265]: model.box(Vector3(x,.80,z),Vector3(.065,.93,.065),dark)
		for side in [-1.0,1.0]:
			model.box(Vector3(0,.79,side*.274),Vector3(.045,.91,.055),dark)
			model.beam(Vector3(-.25,.46,side*.28),Vector3(.25,1.15,side*.28),.035,.035,dark)
			model.box(Vector3(side*.285,.79,0),Vector3(.055,.91,.045),dark)
		model.box(Vector3(0,1.28,0),Vector3(.69,.11,.65),dark)
		var roof := CylinderMesh.new(); roof.radial_segments = 4; roof.rings = 1
		roof.top_radius = .17; roof.bottom_radius = .53; roof.height = .22
		model.add(roof,dark,Transform3D(Basis(Vector3.UP,PI*.25),Vector3(0,1.44,0)),"LanternRoof")
		model.box(Vector3(0,1.56,0),Vector3(.25,.065,.25),copper)
		model.box(Vector3(0,1.64,0),Vector3(.10,.10,.10),dark)
		model.finish(root)
		for part: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			if str(part.name).begins_with("LitPaper"): part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lamp := OmniLight3D.new(); lamp.name = "WarmTerraceLight"; lamp.position = Vector3(0,.84,0)
		lamp.light_color = Color("ffb16d"); lamp.light_energy = 1.7; lamp.omni_range = 5.8
		lamp.shadow_enabled = true; lamp.shadow_bias = .025; lamp.shadow_normal_bias = .05
		lamp.light_volumetric_fog_energy = .05
		root.add_child(lamp); lamps.append(lamp)
	_scatter_leaves()


static func leaf_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := PackedVector2Array([Vector2(0,-.52),Vector2(.09,-.24),Vector2(.30,-.37),Vector2(.24,-.12),Vector2(.49,-.14),Vector2(.28,.05),Vector2(.32,.27),Vector2(.12,.18),Vector2(.035,.43),Vector2(-.04,.20),Vector2(-.30,.27),Vector2(-.25,.05),Vector2(-.49,-.14),Vector2(-.23,-.12),Vector2(-.29,-.37),Vector2(-.09,-.24)])
	for i in rim.size():
		for point: Vector3 in [Vector3(0,.022,0),Vector3(rim[i].x,0,rim[i].y),Vector3(rim[(i+1)%rim.size()].x,0,rim[(i+1)%rim.size()].y)]:
			surface.set_normal(Vector3.UP); surface.set_color(Color.WHITE if point.y>.01 else Color(.74,.74,.74)); surface.add_vertex(point)
	return surface.commit()


func _scatter_leaves() -> void:
	var mesh := MultiMesh.new(); mesh.transform_format = MultiMesh.TRANSFORM_3D; mesh.use_colors = true
	mesh.mesh = leaf_mesh(); mesh.instance_count = 52
	var random := RandomNumberGenerator.new(); random.seed = 2026101904
	for i in mesh.instance_count:
		var center := Vector2(-1.4,4.1) if i%3!=0 else Vector2(3.4,4.6)
		var at := center+Vector2(random.randfn(0,1.20),random.randfn(0,1.0))
		at.x = clampf(at.x,-6.4,6.4); at.y = clampf(at.y,2.65,7.65)
		var scale_value := random.randf_range(.16,.31)
		mesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*scale_value),Vector3(at.x,.282,at.y)))
		mesh.set_instance_color(i,Color("b92e3a").lerp(Color("dc5744"),random.randf()*.6))
	leaves = MultiMeshInstance3D.new(); leaves.name = "SettledMapleLeaves"; leaves.multimesh = mesh
	var paint := StandardMaterial3D.new(); paint.vertex_color_use_as_albedo = true
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED; paint.roughness = .95
	leaves.material_override = paint; leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(leaves)
