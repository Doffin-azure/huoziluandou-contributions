extends "res://src/map/expedition_garden_asset_base.gd"
## Full-scale, parametric garden spans. End floor heights are always zero.
const PLAN = preload("res://src/expedition/garden_bridge_plan.gd")
@export_enum("arch","covered","pier","gallery","rail","post") var kind := "arch"
@export_range(1.0,16.0,.25) var span_length := 6.0
@export var with_deck := true
## Compact gardens keep every walking tile level. The stone arch is underneath
## the flat deck; the legacy raised arch profile remains available elsewhere.
var level_deck := false
var canopy_height := 1.0
var ground_material: ShaderMaterial
var roof_parts: Array[GeometryInstance3D] = []
var roof_faded := false
var omit_first_post := false
var omit_last_post := false


func setup(painter: ExpeditionFlatStyle) -> void:
	if ground_material==null: ground_material = preload("res://src/map/expedition_pond_shape_tile.gd").ground_material(Vector2.ZERO)
	super.setup(painter)
	for part: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if part.get_meta("roof_occluder",false): roof_parts.append(part)


func _build() -> void:
	map_scale = 1.0
	footprint = Vector2(span_length,1.65 if kind in ["gallery","covered"] else 1.14)
	set_meta("connections",[Vector3.ZERO,Vector3(span_length,0,0)])
	if kind=="post": _post(0,0,true); return
	if kind=="rail":
		_rail(0,omit_first_post,omit_last_post)
		return
	if with_deck: _deck()
	for side in [-1.0,1.0]:
		_curb(side*.445)
		_rail(side*.475)
	match kind:
		"arch": _arches()
		"pier": _piers(1.7)
		"covered","gallery":
			_piers(2.0)
			var first := get_child_count()
			_canopy()
			if not is_equal_approx(canopy_height,1.0):
				var parts := get_children().slice(first)
				var canopy := Node3D.new(); canopy.name = "Canopy"; add_child(canopy); canopy.scale.y = canopy_height
				for part: Node3D in parts: part.reparent(canopy,false)


func _h(s: float) -> float: return 0.0 if level_deck else PLAN.elevation(kind,s,span_length)


func _deck() -> void:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in roundi(span_length*4):
		var a := i*.25; var b := a+.25
		var points := [Vector3(a,_h(a),-.375),Vector3(b,_h(b),-.375),Vector3(b,_h(b),.375),Vector3(a,_h(a),.375)]
		_quad(surface,points,Vector3(_h(a)-_h(b),.25,0).normalized())
	var deck := MeshInstance3D.new(); deck.mesh = surface.commit()
	deck.material_override = ground_material if ground_material!=null else style.face_material("stone")
	add_child(deck)
	for side in [-1.0,1.0]:
		var profile_points := PackedVector2Array()
		for i in roundi(span_length*4)+1: profile_points.append(Vector2(i*.25,_h(i*.25)-.005))
		for i in range(roundi(span_length*4),-1,-1): profile_points.append(Vector2(i*.25,_h(i*.25)-.13))
		profile(profile_points,.10,Vector3(0,0,side*.355),"stone",.6)


func _curb(z: float) -> void:
	for i in ceili(span_length/.75):
		var a := span_length*i/ceili(span_length/.75)
		var b := span_length*(i+1)/ceili(span_length/.75)
		profile(PackedVector2Array([Vector2(a+.006,_h(a)+.035),Vector2(b-.006,_h(b)+.035),Vector2(b-.006,_h(b)-.12),Vector2(a+.006,_h(a)-.12)]),.15,Vector3(0,0,z),"architecture",.55)


func _post(s: float, z: float, tall := false) -> void:
	var h := _h(s)
	box(Vector3(s,h+.035,z),Vector3(.16,.10,.17),"stone",.65)
	box(Vector3(s,h+.265,z),Vector3(.095,.40,.105),"architecture",.7)
	box(Vector3(s,h+.44,z),Vector3(.15,.085,.16),"stone",.75)
	box(Vector3(s,h+.49,z),Vector3(.095,.025,.105),"patina",.35)
	profile(PackedVector2Array([Vector2(-.044,.495),Vector2(0,.535),Vector2(.044,.495)]),.09,Vector3(s,h,z),"copper_dark",.4)
	for side in [-1.0,1.0]:
		ink([Vector3(s-.022,h+.16,z+side*.054),Vector3(s-.022,h+.34,z+side*.054),Vector3(s+.022,h+.34,z+side*.054)],.3)
	if tall:
		box(Vector3(s,h-.24,z),Vector3(.11,.43,.12),"architecture",.5)
		box(Vector3(s,h-.40,z),Vector3(.18,.08,.20),"patina",.35)


func _rail(z: float, skip_first := false, skip_last := false) -> void:
	var bays := maxi(1,ceili(span_length/1.35))
	for i in bays+1:
		if (i==0 and skip_first) or (i==bays and skip_last): continue
		_post(span_length*i/bays,z,kind=="rail")
	for i in bays:
		var a := span_length*i/bays+.065
		var b := span_length*(i+1)/bays-.065
		if b-a<.08: continue
		beam(Vector3(a,_h(a)+.405,z),Vector3(b,_h(b)+.405,z),.058,"stone")
		beam(Vector3(a,_h(a)+.14,z),Vector3(b,_h(b)+.14,z),.042,"architecture")
		var mid := (a+b)*.5
		# One broad garden key-fret per bay, with air around it.
		var y := _h(mid)+.27
		for side in [-1.0,1.0]:
			var x: float = mid+float(side)*minf(.16,(b-a)*.2)
			beam(Vector3(x,y-.09,z),Vector3(x,y+.09,z),.025,"patina")
			beam(Vector3(x,y+.09,z),Vector3(mid,y+.09,z),.025,"patina")
			beam(Vector3(x,y-.09,z),Vector3(mid,y-.09,z),.025,"patina")


func _arches() -> void:
	var bays := maxi(1,roundi(span_length/3.4))
	for i in bays:
		var a := span_length*i/bays
		var b := span_length*(i+1)/bays
		for side in [-1.0,1.0]:
			var z: float = side*.405
			for wedge in 13:
				var x0 := lerpf(a+.12,b-.12,wedge/13.0)
				var x1 := lerpf(a+.12,b-.12,(wedge+1)/13.0)
				var t0 := inverse_lerp(a+.12,b-.12,x0)
				var t1 := inverse_lerp(a+.12,b-.12,x1)
				var low0 := _h(x0)-.16-.49*pow(2*t0-1,2)
				var low1 := _h(x1)-.16-.49*pow(2*t1-1,2)
				profile(PackedVector2Array([Vector2(x0+.004,_h(x0)-.06),Vector2(x1-.004,_h(x1)-.06),Vector2(x1-.004,low1),Vector2(x0+.004,low0)]),.15,Vector3(0,0,z),"stone" if wedge%3 else "architecture",.45)
				# The intrados has a thick carved lip, rather than a painted arch line.
				profile(PackedVector2Array([Vector2(x0+.004,low0+.075),Vector2(x1-.004,low1+.075),Vector2(x1-.004,low1),Vector2(x0+.004,low0)]),.19,Vector3(0,0,z),"architecture",.65)
			var mid := (a+b)*.5
			profile(PackedVector2Array([Vector2(mid-.10,_h(mid)-.04),Vector2(mid+.10,_h(mid)-.04),Vector2(mid+.065,_h(mid)-.22),Vector2(mid-.065,_h(mid)-.22)]),.205,Vector3(0,0,z),"patina",.65)
	for i in bays+1:
		var x := span_length*i/bays
		# Abutment tops stay below the zero-height approach, including the end bays.
		box(Vector3(x,-.35,0),Vector3(.30,.64,.99),"architecture",.8)
		box(Vector3(x,-.11,0),Vector3(.39,.09,1.06),"stone",.65)


func _piers(spacing: float) -> void:
	var bays := maxi(1,ceili(span_length/spacing))
	for i in bays+1:
		var x := span_length*i/bays
		box(Vector3(x,-.10,0),Vector3(.23,.15,1.05),"stone",.75)
		for side in [-1.0,1.0]:
			var z: float = side*.33
			cylinder(Vector3(x,-.34,z),.105,.47,"architecture",null,6)
			box(Vector3(x,-.38,z),Vector3(.25,.065,.25),"patina",.4)
			box(Vector3(x,-.19,z),Vector3(.23,.075,.24),"stone",.5)
			if i>0 and kind=="pier":
				var previous := span_length*(i-1)/bays
				beam(Vector3(previous,-.24,z),Vector3(x,-.13,z),.06,"copper_dark")
	for z in [-.31,.31]: box(Vector3(span_length*.5,-.17,z),Vector3(span_length,.09,.10),"architecture",.5)


func _canopy() -> void:
	var bays := maxi(2,roundi(span_length/1.65))
	var roof_y := 1.52
	for i in bays+1:
		var x := span_length*i/bays
		for z in [-.475,.475]:
			box(Vector3(x,.075,z),Vector3(.18,.15,.19),"stone",.65)
			box(Vector3(x,.80,z),Vector3(.075,1.40,.085),"architecture",.8)
			box(Vector3(x,1.42,z),Vector3(.15,.12,.16),"copper_dark",.55)
			box(Vector3(x,.23,z),Vector3(.115,.12,.13),"patina",.45)
			var direction := 1.0 if i<bays else -1.0
			beam(Vector3(x,1.17,z),Vector3(x+direction*.26,1.44,z),.045,"architecture")
			ink([Vector3(x-.021,.38,z+.046),Vector3(x-.021,1.29,z+.046)],.28)
		box(Vector3(x,1.46,0),Vector3(.095,.11,1.17),"architecture",.7)
		if i<bays:
			var next := span_length*(i+1)/bays
			var mid := (x+next)*.5
			for z in [-.49,.49]:
				box(Vector3(mid,1.30,z),Vector3(next-x-.10,.07,.055),"patina",.45)
				# Open lattice transom; large simple geometry, no dense texture.
				for dx in [-.20,0.0,.20]:
					var transom := beam(Vector3(mid+dx,1.31,z),Vector3(mid+dx,1.43,z),.025,"wood")
					transom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if kind=="gallery":
				box(Vector3(mid,.34,-.60),Vector3(next-x-.20,.075,.22),"wood",.65)
				box(Vector3(mid,.045,-.59),Vector3(next-x-.12,.09,.29),"architecture",.55)
				for dx in [-.40,.40]: box(Vector3(mid+dx,.19,-.60),Vector3(.065,.24,.13),"architecture",.45)
	for z in [-.49,.49]: box(Vector3(span_length*.5,1.48,z),Vector3(span_length+.15,.10,.11),"architecture",.7)
	var roof_width := span_length+.40
	var ridge_ratio := clampf(1-.85/roof_width,.55,.94)
	hip_roof(Vector3(span_length*.5,roof_y,0),roof_width,1.62,.24,ridge_ratio)
	# Tile ribs have a steady world-space rhythm across the whole span.
	# They do not restart as a row of small overlapping pavilion roofs.
	for i in floori(span_length/.38)+1:
		var x := i*.38
		for side in [-1.0,1.0]:
			var path: Array[Vector3] = []
			for fraction in [.12,.38,.67,.97]:
				var z: float = float(side)*.81*float(fraction)
				var y := roof_y+_roof_y(x-span_length*.5,z,roof_width*.5,.81,roof_width*.5*ridge_ratio,.24)+.003
				path.append(Vector3(x,y,z))
			ink(path,.23).set_meta("roof_occluder",true)
	# One restrained vermilion tie and old-gold plaque make the long silhouette readable.
	box(Vector3(span_length*.5,1.40,.56),Vector3(.32,.15,.025),"copper_dark",.5)
	ink([Vector3(span_length*.5-.10,1.43,.575),Vector3(span_length*.5+.10,1.43,.575),Vector3(span_length*.5+.10,1.36,.575)],.30,"bronze")
	box(Vector3(.04,1.05,.51),Vector3(.11,.25,.023),"seal",.45)
	for x in [span_length*.25,span_length*.75]: lantern(Vector3(x,1.06,-.25),.37)
	# The ridge, eave beams and roof strokes must use the same cutaway as the
	# roof skin. Otherwise a floating opaque beam still crosses the character.
	for part in get_children():
		if part is MeshInstance3D and part.mesh!=null:
			var bounds: AABB = part.transform*part.get_aabb()
			if bounds.position.y>=1.08: part.set_meta("roof_occluder",true)


func set_roof_faded(value: bool) -> void:
	if value==roof_faded: return
	roof_faded = value
	for part in roof_parts:
		part.transparency = .88 if value else 0.0
		var outline: Variant = part.get_meta("flat_outline") if part.has_meta("flat_outline") else null
		if outline is GeometryInstance3D: outline.transparency = .92 if value else 0.0
