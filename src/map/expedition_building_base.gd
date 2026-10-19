extends Node3D
## Shared production geometry and ink for the small architecture studies.
const INK = preload("res://src/shaders/expedition_tree_ink.gdshader")
const INLAY = preload("res://src/map/expedition_inlaid_glyph.gd")
const LIT_ROOF = preload("res://src/shaders/expedition_lit_roof.gdshader")
const FLAT_ROOF = preload("res://src/shaders/expedition_painted_roof.gdshader")
var style: ExpeditionFlatStyle
var details: Node3D
var alternate_state := false
var lamps_when_alternate := false
var map_scale := .5
var footprint := Vector2(1.8,1.4)
var _lamps_enabled := true
var _lamps: Array[OmniLight3D] = []
var _flames: Array[MeshInstance3D] = []
var _roof_paints: Array[ShaderMaterial] = []
var _inks: Dictionary = {}
var _labels: Array[Label3D] = []
var _detail_items: Array[MeshInstance3D] = []


func setup(painter: ExpeditionFlatStyle) -> void:
	style = painter
	details = Node3D.new()
	details.name = "EngravedDetails"
	add_child(details)
	_build()
	style.palette.changed.connect(refresh_palette)
	refresh_palette()
	set_alternate_state(false)


func _exit_tree() -> void:
	if style!=null and style.palette.changed.is_connected(refresh_palette): style.palette.changed.disconnect(refresh_palette)


func _build() -> void:
	pass


func box(center: Vector3, size: Vector3, role := "architecture", outline := .7, parent: Node3D = null) -> MeshInstance3D:
	return style.mesh(self if parent==null else parent,TypeMeshes.beveled_box(size,minf(.009,minf(size.x,minf(size.y,size.z))*.12)),center,role,outline)


func beam(a: Vector3, b: Vector3, width: float, role := "architecture", parent: Node3D = null) -> MeshInstance3D:
	var result := box((a+b)*.5,Vector3(width,a.distance_to(b),width),role,.45,parent)
	result.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return result


func cylinder(center: Vector3, radius: float, height: float, role := "copper_dark", parent: Node3D = null, segments := 8) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = segments
	return style.mesh(self if parent==null else parent,shape,center,role,.45)


func profile(points: PackedVector2Array, depth: float, center: Vector3, role := "architecture", outline := .65, parent: Node3D = null) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(points)
	for sign_value in [-1.0,1.0]:
		for n in range(0,indices.size(),3):
			var p: Array[Vector3] = []
			for j in 3:
				var xy := points[indices[n+j]]
				p.append(Vector3(xy.x,xy.y,sign_value*depth*.5))
			_triangle(surface,p[0],p[1],p[2],Vector3(0,0,sign_value))
	for n in points.size():
		var a := points[n]
		var b := points[(n+1)%points.size()]
		_quad(surface,[Vector3(a.x,a.y,-depth*.5),Vector3(b.x,b.y,-depth*.5),Vector3(b.x,b.y,depth*.5),Vector3(a.x,a.y,depth*.5)],Vector3(b.y-a.y,a.x-b.x,0).normalized())
	return style.mesh(self if parent==null else parent,surface.commit(),center,role,outline)


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for point: Vector3 in ([a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]):
		surface.set_normal(normal)
		surface.add_vertex(point)


func _quad(surface: SurfaceTool, points: Array, normal: Vector3) -> void:
	_triangle(surface,points[0],points[1],points[2],normal)
	_triangle(surface,points[0],points[2],points[3],normal)


func ink(points: Array[Vector3], weight := .3, role := "ink", parent: Node3D = null) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(points.size()-1):
		for corner: Vector2i in [Vector2i(n,-1),Vector2i(n+1,-1),Vector2i(n+1,1),Vector2i(n,-1),Vector2i(n+1,1),Vector2i(n,1)]:
			var j := corner.x
			surface.set_normal((points[mini(points.size()-1,j+1)]-points[maxi(0,j-1)]).normalized())
			surface.set_color(Color.WHITE)
			surface.set_uv(Vector2(0,corner.y))
			surface.add_vertex(points[j])
	var key := role+str(weight)
	if not _inks.has(key):
		var paint := ShaderMaterial.new()
		paint.shader = INK
		paint.set_meta("role",role)
		paint.set_meta("weight",weight)
		_inks[key] = paint
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = _inks[key]
	# 屋面瓦楞、碑刻和檐线是极细装饰；进入 shadow map 只会产生低分辨率圆斑。
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(details if parent==null else parent).add_child(node)
	_detail_items.append(node)
	return node


func inlay(glyph: String, center: Vector3, scale_value := .38) -> Node3D:
	var node := INLAY.new()
	node.position = center
	node.scale = Vector3.ONE*scale_value
	add_child(node)
	node.setup(glyph,style.palette,Ink.serif)
	return node


func sign_text(glyph: String, center: Vector3, scale_value := .0017, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = glyph
	label.font = Ink.serif
	label.font_size = 96
	label.pixel_size = scale_value
	label.position = center
	label.outline_size = 0
	(self if parent==null else parent).add_child(label)
	_labels.append(label)
	return label


func _roof_y(x: float, z: float, half_width: float, half_depth: float, ridge: float, rise: float) -> float:
	var hip := maxf(absf(z)/half_depth,maxf(0,absf(x)-ridge)/(half_width-ridge))
	return rise*pow(maxf(0,1-hip),.85)+.05*pow(absf(x)/half_width,6)*pow(absf(z)/half_depth,2)


func hip_roof(center: Vector3, width: float, depth: float, rise: float, ridge_ratio := .38) -> MeshInstance3D:
	var hw := width*.5
	var hd := depth*.5
	var ridge := hw*ridge_ratio
	var xs := [-hw,-hw*.8,-ridge,0.0,ridge,hw*.8,hw]
	var zs := [-hd,-hd*.72,0.0,hd*.72,hd]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(xs.size()-1):
		for z in range(zs.size()-1):
			var p: Array = []
			for pair in [Vector2(xs[x],zs[z]),Vector2(xs[x+1],zs[z]),Vector2(xs[x+1],zs[z+1]),Vector2(xs[x],zs[z+1])]:
				p.append(Vector3(pair.x,_roof_y(pair.x,pair.y,hw,hd,ridge,rise),pair.y))
			for tri in [[0,1,2],[0,2,3]]:
				var normal: Vector3 = (p[tri[1]]-p[tri[0]]).cross(p[tri[2]]-p[tri[0]]).normalized()
				if normal.y<0: normal = -normal
				_triangle(surface,p[tri[0]],p[tri[1]],p[tri[2]],normal)
				_triangle(surface,p[tri[0]]-Vector3.UP*.05,p[tri[1]]-Vector3.UP*.05,p[tri[2]]-Vector3.UP*.05,Vector3.DOWN)
	for side in [-1.0,1.0]:
		for x in range(xs.size()-1):
			var a := Vector3(xs[x],_roof_y(xs[x],side*hd,hw,hd,ridge,rise),side*hd)
			var b := Vector3(xs[x+1],_roof_y(xs[x+1],side*hd,hw,hd,ridge,rise),side*hd)
			_quad(surface,[a,b,b-Vector3.UP*.05,a-Vector3.UP*.05],Vector3(0,0,side))
		for z in range(zs.size()-1):
			var a := Vector3(side*hw,_roof_y(side*hw,zs[z],hw,hd,ridge,rise),zs[z])
			var b := Vector3(side*hw,_roof_y(side*hw,zs[z+1],hw,hd,ridge,rise),zs[z+1])
			_quad(surface,[a,b,b-Vector3.UP*.05,a-Vector3.UP*.05],Vector3(side,0,0))
	var node := style.mesh(self,surface.commit(),center,"roof",1.0)
	node.set_meta("roof_occluder",true)
	var paint := ShaderMaterial.new()
	paint.shader = LIT_ROOF if style.scene_lighting else FLAT_ROOF
	paint.set_shader_parameter("roof_half_width",hw)
	paint.set_shader_parameter("roof_half_depth",hd)
	paint.set_shader_parameter("roof_ridge_half_width",ridge)
	_roof_paints.append(paint)
	node.material_override = paint
	box(center+Vector3(0,rise+.023,0),Vector3(ridge*2+.12,.045,.075),"roof",.5).set_meta("roof_occluder",true)
	for side in [-1.0,1.0]:
		box(center+Vector3(side*(ridge+.055),rise+.035,0),Vector3(.055,.075,.10),"copper_dark",.35).set_meta("roof_occluder",true)
		for fraction in [-.66,-.33,0.0,.33,.66]:
			var path: Array[Vector3] = []
			for n in range(1,9):
				var z: float = side*hd*n/9.0
				var x: float = fraction*hw
				path.append(center+Vector3(x,_roof_y(x,z,hw,hd,ridge,rise)+.002,z))
			ink(path,.24).set_meta("roof_occluder",true)
		for sx in [-1.0,1.0]:
			var path: Array[Vector3] = []
			for n in 10:
				var t := n/9.0
				var x: float = sx*lerpf(ridge,hw,t)
				var z: float = side*hd*t
				path.append(center+Vector3(x,_roof_y(x,z,hw,hd,ridge,rise)+.003,z))
			ink(path,.43).set_meta("roof_occluder",true)
	return node


func lantern(center: Vector3, scale_value := 1.0, hanging := true) -> Node3D:
	var holder := Node3D.new()
	holder.position = center
	holder.scale = Vector3.ONE*scale_value
	add_child(holder)
	cylinder(Vector3(0,.15,0),.15,.045,"roof",holder,6)
	cylinder(Vector3(0,-.14,0),.13,.045,"copper_dark",holder,6)
	for n in 6:
		var angle := TAU*n/6
		box(Vector3(cos(angle)*.105,0,sin(angle)*.105),Vector3(.018,.27,.018),"copper_dark",.25,holder)
	if hanging: beam(Vector3(0,.18,0),Vector3(0,.40,0),.02,"copper_dark",holder)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.emission_enabled = true
	var flame := MeshInstance3D.new()
	var core := CylinderMesh.new()
	core.radial_segments = 6
	core.top_radius = .065
	core.bottom_radius = .065
	core.height = .19
	flame.mesh = core
	flame.material_override = paint
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(flame)
	_flames.append(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0,.015,.015)
	light.light_energy = .68
	light.omni_range = 1.45
	light.omni_attenuation = 1.3
	# 局部灯只提供暖光，不参与 shadow map；主光保留唯一阴影。
	light.shadow_enabled = false
	holder.add_child(light)
	_lamps.append(light)
	return holder


func set_lamps_enabled(value: bool) -> void:
	_lamps_enabled = value
	refresh_palette()


func set_details_enabled(value: bool) -> void:
	for item in _detail_items: item.visible = value


func set_alternate_state(value: bool) -> void:
	alternate_state = value
	_apply_state()
	refresh_palette()


func _apply_state() -> void:
	pass


func set_scene_lighting(value: bool) -> void:
	for paint in _roof_paints: paint.shader = LIT_ROOF if value else FLAT_ROOF
	refresh_palette()


func refresh_palette() -> void:
	var colors := style.palette
	for paint in _roof_paints:
		paint.set_shader_parameter("roof_color",colors.roof)
		paint.set_shader_parameter("diffuse_response",colors.roof_light_response)
		if not style.scene_lighting:
			var source := style.face_material("architecture")
			for parameter in ["fire_position","fire_color","fire_energy","fire_radius","fire_pulse"]:
				paint.set_shader_parameter(parameter,source.get_shader_parameter(parameter))
	for paint: ShaderMaterial in _inks.values():
		var role: String = paint.get_meta("role")
		var tint: Color = colors.ink
		if role=="worn": tint = colors.architecture_top.lerp(colors.stone_top,.45)
		elif role=="bronze": tint = colors.bronze
		paint.set_shader_parameter("ink_color",tint)
		paint.set_shader_parameter("half_width_pixels",colors.outline_pixels*float(paint.get_meta("weight")))
	var lit := _lamps_enabled and (not alternate_state or lamps_when_alternate)
	for light in _lamps:
		light.light_color = colors.fire_light
		light.visible = lit and style.scene_lighting
	for flame in _flames:
		var paint: StandardMaterial3D = flame.material_override
		paint.albedo_color = colors.fire_inner if lit else colors.roof
		paint.emission = colors.fire_inner
		paint.emission_energy_multiplier = 1.1 if lit else 0.0
	for label in _labels: label.modulate = colors.glyph_fill
