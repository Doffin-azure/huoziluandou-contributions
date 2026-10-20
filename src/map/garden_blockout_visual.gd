extends RefCounted
## Cheap occupancy meshes: one combined body per eight-tile chunk.
const PLAN = preload("res://src/expedition/garden_blockout_plan.gd")
const COLORS := {"start":Color("ceb17b"),"battle":Color("ad6754"),"elite":Color("d4945c"),"event":Color("a3b19e"),"rest":Color("8db3bd"),"shop":Color("c8b06a"),"treasure":Color("b09cbf"),"boss":Color("d48867")}
var material: ShaderMaterial


func _init() -> void:
	material = ShaderMaterial.new(); material.shader = preload("res://src/shaders/garden_blockout.gdshader")


func chunk(plan: RefCounted, key: Vector2i) -> Node3D:
	var root := Node3D.new(); root.name = "Block_%d_%d" % [key.x,key.y]
	var data: Dictionary = plan.chunks[key]
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Vector2i in data.floor:
		_box(surface,Vector3(c.x,-.18,c.y),Vector3(1,.36,1),Color("6d685a"))
	for c: Vector2i in data.plots:
		if plan.plots[c]=="water": _box(surface,Vector3(c.x,-.55,c.y),Vector3(1,.12,1),Color("18363e"))
		else: _box(surface,Vector3(c.x,-.02,c.y),Vector3(1,.48,1),Color("555c57") if plan.plots[c]=="rocks" else Color("3e5143"))
	for wall: Dictionary in data.walls:
		var at: Vector2 = (wall.a+wall.b)*.5
		var extent: Vector2 = (wall.b-wall.a).abs()
		_box(surface,Vector3(at.x,.5,at.y),Vector3(maxf(.12,extent.x),1.0,maxf(.12,extent.y)),Color("64716c"))
	_mesh(root,surface.commit())
	var roofs := Node3D.new(); roofs.name = "RoofProxies"; roofs.visible = false; root.add_child(roofs)
	var roof_items: Array = []
	for id: String in data.nodes:
		var node: Dictionary = plan.nodes[id]
		var mark := Label3D.new(); mark.text = PLAN.GLYPHS[node.kind]
		mark.font = Ink.serif; mark.font_size = 72; mark.pixel_size = .009
		mark.modulate = COLORS[node.kind]; mark.position = Vector3(node.at.x,.025,node.at.y)
		mark.rotation_degrees.x = -90; mark.no_depth_test = false; mark.outline_size = 0
		root.add_child(mark)
		if node.kind in ["start","boss","shop","rest"] or node.kind=="event" and int(node.row)%2==0:
			var roof := SurfaceTool.new(); roof.begin(Mesh.PRIMITIVE_TRIANGLES)
			var eave := -.08 if node.has("role") else .4
			_box(roof,Vector3(node.at.x,2.35,node.at.y),Vector3(node.extent.x+eave,.18,node.extent.y+eave),Color("243b41"))
			var mesh := _mesh(roofs,roof.commit()); roof_items.append({"node":mesh,"rect":plan.node_rect(node)})
	root.set_meta("roof_items",roof_items); root.set_meta("chunk",key)
	return root


func surroundings(plan: RefCounted) -> Node3D:
	var root := Node3D.new(); root.name = "WaterAndOuterBoundary"
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size := Vector2(plan.bounds.size); var center := size*.5-Vector2.ONE*.5
	_box(surface,Vector3(center.x,-.62,center.y),Vector3(size.x+8,.12,size.y+8),Color("18363e"))
	for x in [-.5,size.x-.5]: _box(surface,Vector3(x,.65,center.y),Vector3(.24,1.3,size.y),Color("475952"))
	for y in [-.5,size.y-.5]: _box(surface,Vector3(center.x,.65,y),Vector3(size.x,1.3,.24),Color("475952"))
	_mesh(root,surface.commit()); return root


func gates(travel: RefCounted, wanted: Dictionary) -> Node3D:
	var root := Node3D.new(); root.name = "ForwardDoors"
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for gate: Dictionary in travel.gates:
		if not wanted.has(PLAN.chunk_at(Vector2(gate.a))) and not wanted.has(PLAN.chunk_at(Vector2(gate.b))): continue
		var middle: Vector2 = (Vector2(gate.a)+Vector2(gate.b))*.5
		var normal: Vector2 = Vector2(gate.b-gate.a); var tangent := Vector2(-normal.y,normal.x)
		var extent := Vector3(.13,.88,.13)
		for sign_value in [-1,1]:
			var at: Vector2 = middle+tangent*.43*sign_value
			_box(surface,Vector3(at.x,.44,at.y),extent,Color("514c42"))
		if gate.open:
			var direction := Vector2(gate.direction)
			var across := Vector2(-direction.y,direction.x)
			for point: Vector2 in [middle+direction*.33,middle-direction*.19-across*.23,middle-direction*.19+across*.23]:
				surface.set_normal(Vector3.UP); surface.set_color(Color("e5bc70")); surface.add_vertex(Vector3(point.x,.035,point.y))
		else:
			_box(surface,Vector3(middle.x,.38,middle.y),Vector3(.12 if normal.x!=0 else .85,.76,.85 if normal.x!=0 else .12),Color("7d493c"))
		count += 1
	if count>0: _mesh(root,surface.commit())
	return root


func _mesh(parent: Node3D, mesh: ArrayMesh) -> MeshInstance3D:
	var result := MeshInstance3D.new(); result.mesh = mesh; result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result); return result


static func _box(surface: SurfaceTool, center: Vector3, extent: Vector3, tint: Color) -> void:
	var half := extent*.5
	for axis in 3:
		for sign_value in [-1.0,1.0]:
			var normal := Vector3.ZERO; normal[axis] = sign_value
			var u := (axis+1)%3; var v := (axis+2)%3
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point := center; point[axis] += half[axis]*sign_value; point[u] += corner.x*half[u]; point[v] += corner.y*half[v]
				surface.set_normal(normal); surface.set_color(tint); surface.add_vertex(point)
