extends "res://src/map/expedition_garden_asset_base.gd"
## Walk-through timber shell. Size changes add bays, never stretch a solid loft.
var extent := Vector2(6,4)
var openings := {"N":[],"E":[],"S":[],"W":[]}
var title := ""
var gallery := false
var second_storey := false
var column_omit: Array = []
var roof_kind := ""
var roof_parts: Array[GeometryInstance3D] = []


func _build() -> void:
	map_scale = 1.0; footprint = extent
	var height := 1.85 if gallery else 2.25
	var half := extent*.5
	var columns := {}
	for side in ["N","E","S","W"]:
		var length: float = extent.x if side in ["N","S"] else extent.y
		var cuts: Array = openings[side].duplicate()
		cuts.sort()
		var cursor := -length*.5
		for offset: float in cuts:
			_wall(side,cursor,offset-.85,height)
			cursor = maxf(cursor,offset+.85)
		_wall(side,cursor,length*.5,height)
		for end in [-length*.5,length*.5]:
			var at := _at(side,end)
			if columns.has(at): continue
			columns[at] = true
			if column_omit.has(Vector2(at.x,at.z)): continue
			box(at+Vector3.UP*.09,Vector3(.29,.18,.29),"stone",.55)
			box(at+Vector3.UP*(height*.5),Vector3(.14,height,.14),"architecture",.7)
		var a := _at(side,-length*.5); var b := _at(side,length*.5)
		beam(a+Vector3.UP*height,b+Vector3.UP*height,.16,"architecture")
		beam(a+Vector3.UP*(height-.12),b+Vector3.UP*(height-.12),.055,"seal")
	# Brackets and deep eaves carry the roof, instead of a thin floating plane.
	for x in [-half.x+.2,half.x-.2]:
		for z in [-half.y+.2,half.y-.2]:
			beam(Vector3(x,height-.22,z),Vector3(x-signf(x)*.24,height+.06,z),.08,"wood")
	if extent.x>2:
		for x in [-minf(2,half.x*.65),minf(2,half.x*.65)]: lantern(Vector3(x,height-.52,half.y-.12),.48)
	if second_storey:
		_roof(Vector3(0,height+.10,0),extent.x+.65,extent.y+.65,.34,false)
		# The upper storey is visual; all navigation remains on the ground floor.
		box(Vector3(0,height+.15,0),Vector3(extent.x-.25,.18,extent.y-.25),"architecture",.65).set_meta("roof_occluder",true)
		box(Vector3(0,height+.78,0),Vector3(extent.x-.85,1.1,extent.y-.8),"wood",.7).set_meta("roof_occluder",true)
		for x in [-half.x*.6,0.0,half.x*.6]:
			box(Vector3(x,height+.8,half.y-.37),Vector3(.55,.54,.035),"patina",.45).set_meta("roof_occluder",true)
		height += 1.4
	# Keep the ridge along the long side after a generated quarter-turn.
	# Rotating the whole roof also rotates its ridge caps and ink strokes.
	_roof(Vector3(0,height+.14,0),extent.x+.55,extent.y+.55,.44 if gallery else .70,gallery and roof_kind!="hip")
	# The compact hall keeps a pronounced eave ring around its open interior.
	# It remains visible after the center roof window is cut, so the building
	# still reads as a roofed Chinese courtyard from the follow camera.
	if gallery:
		var eave_y := height+.10
		box(Vector3(0,eave_y,-half.y-.03),Vector3(extent.x+.95,.10,.22),"roof",.55).set_meta("roof_occluder",true)
		box(Vector3(0,eave_y,half.y+.03),Vector3(extent.x+.95,.10,.22),"roof",.55).set_meta("roof_occluder",true)
		box(Vector3(-half.x-.03,eave_y,0),Vector3(.22,.10,extent.y+.95),"roof",.55).set_meta("roof_occluder",true)
		box(Vector3(half.x+.03,eave_y,0),Vector3(.22,.10,extent.y+.95),"roof",.55).set_meta("roof_occluder",true)
	else:
		# The main roof above already supplies the visible perimeter after the
		# interior window is clipped. Keep only a narrow entrance eave here;
		# a second deep hip roof would cover the whole courtyard in close view.
		var eave_y := height+.10
		box(Vector3(0,eave_y,-half.y-.04),Vector3(extent.x+.72,.10,.18),"roof",.55).set_meta("roof_occluder",true)
		box(Vector3(0,eave_y,half.y+.04),Vector3(extent.x+.72,.10,.18),"roof",.55).set_meta("roof_occluder",true)
	if not title.is_empty():
		box(Vector3(0,height-.25,half.y+.12),Vector3(minf(1.8,extent.x*.5),.35,.09),"copper_dark",.5)
		sign_text(title,Vector3(0,height-.25,half.y+.18),.0020)
	_collect_roofs(self,false)


func _roof(center: Vector3, width: float, depth: float, rise: float, gable: bool) -> void:
	var rotated := depth>width
	var long_side := maxf(width,depth); var short_side := minf(width,depth)
	var roof := Node3D.new(); roof.set_meta("roof_occluder",true); add_child(roof)
	var first := get_child_count()
	var first_detail := details.get_child_count()
	if gable:
		var half := short_side*.5
		var shape := PackedVector2Array([Vector2(-half,-.08),Vector2(-half,0),Vector2(-half*.78,.055),Vector2(0,rise),Vector2(half*.78,.055),Vector2(half,0),Vector2(half,-.08)])
		var panel := profile(shape,long_side,center,"roof",.6)
		panel.rotation.y = PI*.5
		for end in [-long_side*.5,long_side*.5]:
			beam(center+Vector3(end,0,-half),center+Vector3(end,rise,0),.075,"copper_dark")
			beam(center+Vector3(end,rise,0),center+Vector3(end,0,half),.075,"copper_dark")
		beam(center+Vector3(-long_side*.5,rise+.02,0),center+Vector3(long_side*.5,rise+.02,0),.09,"copper_dark")
	else: hip_roof(center,long_side,short_side,rise,.48)
	for side in [-1.0,1.0]:
		beam(center+Vector3(-long_side*.5,-.075,side*short_side*.5),center+Vector3(long_side*.5,-.075,side*short_side*.5),.12,"architecture")
		for x in [-long_side*.45,long_side*.45]: box(center+Vector3(x,.025,side*short_side*.48),Vector3(.07,.09,.17),"copper_dark",.4)
	for part in get_children().slice(first): part.reparent(roof,false)
	# hip_roof() adds its carved tile strokes under EngravedDetails. They must
	# rotate with the roof surface too, rather than staying on the old long axis.
	for part in details.get_children().slice(first_detail): part.reparent(roof,false)
	if rotated:
		roof.rotation.y = PI*.5


func _at(side: String, along: float) -> Vector3:
	match side:
		"N": return Vector3(along,0,-extent.y*.5)
		"S": return Vector3(along,0,extent.y*.5)
		"W": return Vector3(-extent.x*.5,0,along)
	return Vector3(extent.x*.5,0,along)


func _wall(side: String, a: float, b: float, height: float) -> void:
	if b-a<.08: return
	var start := _at(side,a); var finish := _at(side,b)
	if gallery:
		# Gallery edges retain an open view and a continuous lane between posts.
		return
	var length := b-a
	var holder := Node3D.new(); holder.position = (start+finish)*.5
	if side in ["W","E"]: holder.rotation.y = PI*.5
	add_child(holder)
	box(Vector3(0,.28,0),Vector3(length,.56,.13),"stone",.45,holder)
	box(Vector3(0,height-.21,0),Vector3(length,.42,.13),"wood",.45,holder)
	for x in [-length*.5+.07,length*.5-.07]: box(Vector3(x,height*.5,0),Vector3(.14,height,.16),"architecture",.55,holder)
	var count := maxi(1,roundi(length/.85))
	for i in count:
		var x := -length*.5+length*(i+.5)/count
		# Paper is inset in the opening, with paired timber uprights tied into
		# both rails. The lattice sits proud of the paper instead of floating as
		# a lone X in front of an empty black rectangle.
		for face_sign in [-1.0,1.0]:
			var paper := box(Vector3(x,1.025,face_sign*.052),Vector3(.58,.66,.012),"garden_paper",0,holder)
			paper.set_meta("garden_role","garden_paper")
			paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for edge in [-.31,.31]: beam(Vector3(x+edge,.67,face_sign*.084),Vector3(x+edge,1.38,face_sign*.084),.045,"wood",holder)
			beam(Vector3(x-.31,.67,face_sign*.084),Vector3(x+.31,.67,face_sign*.084),.045,"wood",holder)
			beam(Vector3(x-.31,1.38,face_sign*.084),Vector3(x+.31,1.38,face_sign*.084),.045,"wood",holder)
			beam(Vector3(x-.28,.69,face_sign*.105),Vector3(x,1.025,face_sign*.105),.040,"patina",holder)
			beam(Vector3(x,1.025,face_sign*.105),Vector3(x+.28,.69,face_sign*.105),.040,"patina",holder)
			beam(Vector3(x-.28,1.36,face_sign*.105),Vector3(x,1.025,face_sign*.105),.034,"patina",holder)
			beam(Vector3(x,1.025,face_sign*.105),Vector3(x+.28,1.36,face_sign*.105),.034,"patina",holder)
			beam(Vector3(x,.82,face_sign*.105),Vector3(x,1.25,face_sign*.105),.024,"bronze",holder)
			beam(Vector3(x-.15,1.025,face_sign*.105),Vector3(x+.15,1.025,face_sign*.105),.024,"bronze",holder)
	beam(Vector3(-length*.5,.59,0),Vector3(length*.5,.59,0),.07,"architecture",holder)
	beam(Vector3(-length*.5,height-.43,0),Vector3(length*.5,height-.43,0),.07,"architecture",holder)


func _collect_roofs(node: Node, inherited: bool) -> void:
	var is_roof := inherited or bool(node.get_meta("roof_occluder",false))
	if is_roof and node is GeometryInstance3D: roof_parts.append(node)
	for child in node.get_children(): _collect_roofs(child,is_roof)


func set_roofs_faded(value: bool) -> void:
	for mesh in roof_parts: mesh.transparency = .88 if value else 0.0
