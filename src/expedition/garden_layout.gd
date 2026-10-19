extends RefCounted
## Courtyard topology first, continuous pond geometry second, content last.
const ASSETS = preload("res://src/expedition/garden_asset_layout.gd")
const STONE := 0
const WATER := 1
const FOUNDATION := 2
const VERSION := "garden_v2"


static func plan(seed_value: int, theme: String, _old_start: int = 0) -> Dictionary:
	var random := MapGen.Rng.new(seed_value*104729+43)
	var kind := random.ri(3)
	var gate_c := 2+random.ri(2)
	var bridge_r := 3+random.ri(2)
	var bridge_c := gate_c+4
	var start := MapGen.kk(6+random.ri(2),1+random.ri(2))
	var base := PackedByteArray()
	base.resize(MapGen.N)
	var layout := {"version":VERSION,"kind":["绕池型","双汀型","曲渠型"][kind],"theme":theme,"start":start,
		"terrain_base":base,"reserved":{},"no_content":{},"no_ambush":{},"structures":[],"occupancy":[],"wall_runs":[],
		"bridges":{},"pond_cells":{},"pond_shapes":[],"pond_cuts":[],"wet_patches":[],"water_height":-.18,
		"decor_seed":seed_value*3571+29,"shore_phase":random.next()*TAU,"shore_warp":.035+random.next()*.035,
		"bridge_row":bridge_r,"bridge_col":bridge_c,"court_width":gate_c+2.5}
	_pond_plan(layout,random,kind)
	for k in MapGen.N:
		if _pond_field(layout,Vector2(_world(k).x,_world(k).z))>0:
			base[k] = WATER
			layout.pond_cells[k] = true
			layout.reserved[k] = true
	# Two exits preserve a loop: the moon gate and the east bypass.
	var gate := MapGen.kk(5,gate_c)
	_register(layout,"moon_gate",_world(gate),0,[gate-1,gate+1],[gate],[gate-MapGen.W,gate,gate+MapGen.W],"entrance")
	var left := gate_c-.5
	var right := gate_c+1.5
	var end := gate_c+2.5
	_wall_run(layout,[Vector3(0,0,5.5),Vector3(left,0,5.5)],[Vector3(0,0,5.5),Vector3(left,0,5.5)])
	_wall_run(layout,[Vector3(right,0,5.5),Vector3(end,0,5.5),Vector3(end,0,6.0)],[Vector3(right,0,5.5)])
	_wall_run(layout,[Vector3(end,0,7.0),Vector3(end,0,8.0)],[Vector3(end,0,8.0)])
	_protect(layout,[MapGen.kk(6,gate_c+2)])
	_register(layout,"screen_wall",Vector3(gate_c+1,0,3.5),0,[MapGen.kk(3,gate_c),MapGen.kk(3,gate_c+1)],[],[MapGen.kk(4,gate_c),MapGen.kk(4,gate_c+1)])
	_register(layout,"grave_bed",Vector3(1.1,0,1.1),0,[0,1,MapGen.W,MapGen.W+1],[],[MapGen.kk(2,0),MapGen.kk(2,1),MapGen.kk(1,2)])
	# The gallery looks over the water, with its seats against the rear wall.
	var deck := [MapGen.kk(1,bridge_c),MapGen.kk(1,bridge_c+1)]
	_register(layout,"covered_walk",Vector3(bridge_c+1,0,1.5+ASSETS.WALK_LANE_OFFSET),0,[],deck,deck)
	for k in deck: base[k] = STONE
	# Back benches are solid: a thin enclosure behind the gallery closes those
	# logical moves and ties the backdrop to the perimeter at both ends.
	_wall_run(layout,[Vector3(bridge_c,0,0),Vector3(bridge_c,0,.5),Vector3(bridge_c+2,0,.5),Vector3(bridge_c+2,0,0)],
		[Vector3(bridge_c,0,0),Vector3(bridge_c+2,0,0)],"gallery_back")
	for k in [MapGen.kk(2,bridge_c),MapGen.kk(2,bridge_c+1)]:
		base[k] = STONE
		layout.pond_cells.erase(k)
		_protect(layout,[k])
	var bridge := MapGen.kk(bridge_r,bridge_c)
	for k in [bridge-1,bridge,bridge+1]:
		base[k] = WATER
		layout.pond_cells[k] = true
		layout.reserved[k] = true
	var ports := [bridge-MapGen.W,bridge+MapGen.W]
	for k in ports:
		base[k] = STONE
		layout.pond_cells.erase(k)
		_protect(layout,[k])
	layout.bridges[bridge] = true
	_register(layout,"bridge",_world(bridge),PI*.5,[],[bridge],ports)
	layout.facility_slots = {
		"休":[{"entry":MapGen.kk(3,10),"body":MapGen.kk(2,10)},{"entry":MapGen.kk(4,10),"body":MapGen.kk(4,11)}],
		"市":[{"entry":MapGen.kk(6,5),"body":MapGen.kk(7,5)},{"entry":MapGen.kk(6,6),"body":MapGen.kk(7,6)}],
		"谜":[{"entry":MapGen.kk(1,3),"body":MapGen.kk(0,3)},{"entry":MapGen.kk(1,4),"body":MapGen.kk(0,4)}],
		"巢":[{"entry":MapGen.kk(1,11),"body":MapGen.kk(0,11)},{"entry":MapGen.kk(1,10),"body":MapGen.kk(0,10)}]}
	layout.facility_reserved = {}
	for type in layout.facility_slots:
		var slot: Dictionary = layout.facility_slots[type][0]
		for k in [slot.entry,slot.body]:
			layout.reserved[k] = true
			layout.facility_reserved[k] = type
	layout.pocket_forbidden = {}
	for k in MapGen.N:
		if MapGen.man(k,MapGen.kk(1,11))<4: layout.pocket_forbidden[k] = true
	register_facility(layout,"起",_world(start)+Vector3(0,0,-.28),0,start)
	layout.regions = [{"kind":"门前小庭","anchor":start},{"kind":"折景碑庭","anchor":MapGen.kk(2,3)},{"kind":"临池区域","anchor":bridge}]
	return layout


static func _pond_plan(layout: Dictionary, random: MapGen.Rng, kind: int) -> void:
	var shift := Vector2((random.next()-.5)*.65,(random.next()-.5)*.45)
	shift.x += (int(layout.bridge_col)-6)*.45
	var turn := (random.next()-.5)*.65
	match kind:
		0:
			_lobe(layout,Vector2(7.8,3.45)+shift,Vector2(1.55+random.next()*.40,1.05+random.next()*.25),turn)
			_lobe(layout,Vector2(8.35,4.6)+shift,Vector2(.95+random.next()*.35,.80+random.next()*.20),-turn)
		1:
			_lobe(layout,Vector2(7.45,3.05)+shift,Vector2(1.25+random.next()*.30,.90+random.next()*.20),turn)
			_lobe(layout,Vector2(8.35,4.45)+shift,Vector2(1.20+random.next()*.35,1.0+random.next()*.20),-turn)
			_lobe(layout,Vector2(7.9,3.8)+shift,Vector2(.95,.85),turn)
			layout.pond_cuts.append({"c":Vector2(6.65,4.3)+shift,"r":Vector2(.80,.65),"a":turn})
		2:
			for n in 4:
				_lobe(layout,Vector2(7.3+n*.40+sin(n*1.4+layout.shore_phase)*.22,2.5+n*.85)+shift,Vector2(.90+random.next()*.22,.82+random.next()*.15),turn)
	layout.bridge_inlet = {"c":Vector2(float(layout.bridge_col)+.5,float(layout.bridge_row)+.5),"r":Vector2(1.50,.54),"a":0.0}


static func _lobe(layout: Dictionary, center: Vector2, radii: Vector2, angle: float) -> void:
	layout.pond_shapes.append({"c":center,"r":radii,"a":angle})


static func _ellipse(shape: Dictionary, point: Vector2) -> float:
	return (1.0-((point-shape.c).rotated(-float(shape.a))/shape.r).length())*minf(shape.r.x,shape.r.y)


static func _pond_field(layout: Dictionary, point: Vector2) -> float:
	var value := -10.0
	for shape in layout.pond_shapes:
		var other := _ellipse(shape,point)
		var blend := clampf(.5+.5*(value-other)/.20,0,1)
		value = lerpf(other,value,blend)+.20*blend*(1-blend)
	for cut in layout.pond_cuts: value = minf(value,-_ellipse(cut,point))
	# A decorative cove cannot erase one of the bridge's two water-side cells.
	value = maxf(value,_ellipse(layout.bridge_inlet,point))
	var phase: float = layout.shore_phase
	return value+float(layout.shore_warp)*(sin(point.x*2.3+point.y*.8+phase)+sin(point.y*2.9-point.x*.7-phase)*.45)


static func _protect(layout: Dictionary, cells: Array) -> void:
	for k in cells:
		layout.reserved[k] = true
		layout.no_content[k] = true
		layout.no_ambush[k] = true


static func _register(layout: Dictionary, asset: String, at: Vector3, turn: float, solid: Array, walk: Array, reveal: Array, joint := "") -> void:
	var entry := {"asset":asset,"at":at,"turn":turn,"solid":solid,"walk":walk,"reveal":reveal,"clearance":ASSETS.envelope(asset,at,turn),"joint":joint}
	layout.structures.append(entry)
	layout.occupancy.append(entry)
	for k in solid: layout.terrain_base[k] = FOUNDATION
	_protect(layout,solid+walk)


static func _wall_run(layout: Dictionary, points: Array[Vector3], omit: Array[Vector3], joint := "entrance") -> void:
	var cells: Array = []
	for k in MapGen.N:
		var center := Vector2(_world(k).x,_world(k).z)
		for n in range(points.size()-1):
			var a := Vector2(points[n].x,points[n].z)
			var b := Vector2(points[n+1].x,points[n+1].z)
			if center.distance_to(Geometry2D.get_closest_point_to_segment(center,a,b))<.01:
				layout.terrain_base[k] = FOUNDATION
				if not cells.has(k): cells.append(k)
	for n in range(points.size()-1):
		var a := Vector2(points[n].x,points[n].z)
		var b := Vector2(points[n+1].x,points[n+1].z)
		layout.occupancy.append({"asset":"divider","clearance":Rect2(a,Vector2.ZERO).expand(b).grow(.145),"joint":joint})
	layout.wall_runs.append({"points":points,"omit_posts":omit,"solid":cells,"anchor":"perimeter","joint":joint})
	_protect(layout,cells)


static func register_facility(layout: Dictionary, type: String, at: Vector3, turn: float, entry: int) -> void:
	layout.occupancy.append({"asset":type,"at":at,"turn":turn,"clearance":ASSETS.envelope(type,at,turn),"entry":entry,"joint":""})


static func alcove_runs(cells: Array, mouth: int) -> Array:
	var first := _world(cells[0])
	var forward := (_world(mouth)-first).normalized()
	var side := Vector3(-forward.z,0,forward.x)
	var result: Array = []
	for sign_value in [-1.0,1.0]:
		var a: Vector3 = first+side*sign_value-forward*.5
		var b: Vector3 = first+side*sign_value+forward*(cells.size()-.5)
		if a.x<0 or a.z<0 or a.x>MapGen.W or a.z>MapGen.H: continue
		result.append([a,b])
	return result


static func alcove_fits(layout: Dictionary, runs: Array) -> bool:
	for line in runs:
		var rect := Rect2(Vector2(line[0].x,line[0].z),Vector2.ZERO).expand(Vector2(line[1].x,line[1].z)).grow(.15)
		for entry in layout.occupancy:
			if rect.grow(.04).intersects(entry.clearance): return false
	return true


static func register_alcove(layout: Dictionary, runs: Array) -> void:
	for line in runs:
		var points: Array[Vector3] = [line[0],line[1]]
		_wall_run(layout,points,[points[0]],"alcove_"+str(layout.wall_runs.size()))


static func room_for(layout: Dictionary, rect: Rect2) -> bool:
	if not Rect2(.19,.19,MapGen.W-.38,MapGen.H-.38).encloses(rect): return false
	for entry in layout.get("occupancy",layout.structures):
		if rect.grow(.06).intersects(entry.clearance): return false
	return true


static func _world(k: int) -> Vector3:
	var p := MapGen.rc(k)
	return Vector3(p.y+.5,0,p.x+.5)


static func finalize(layout: Dictionary, ink: PackedByteArray) -> void:
	for k in MapGen.N:
		if ink[k]!=0 and layout.terrain_base[k]==STONE: layout.terrain_base[k] = WATER
	layout.walk_mask = PackedByteArray()
	layout.walk_mask.resize(MapGen.N)
	for k in MapGen.N: layout.walk_mask[k] = 1 if ink[k]==0 else 0


static func base_at(map: Dictionary, row: int, col: int) -> int:
	if MapGen.inb(row,col): return int(map.layout.terrain_base[MapGen.kk(row,col)])
	var rr := clampi(row,0,MapGen.H-1)
	var cc := clampi(col,0,MapGen.W-1)
	if abs(row-rr)+abs(col-cc)<=1: return int(map.layout.terrain_base[MapGen.kk(rr,cc)])
	return STONE if sin(col*.85+row*.57)+cos(row*1.21-col*.27)>-.55 else WATER


static func _cubic(a: float, b: float, c: float, d: float, t: float) -> float:
	return b+.5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)))


static func _value_at(map: Dictionary, r: int, c: int) -> float:
	if MapGen.inb(r,c) and map.layout.get("pond_cells",{}).has(MapGen.kk(r,c)): return -.64
	var kind := base_at(map,r,c)
	return .46 if kind==WATER else (-1.0 if kind==FOUNDATION else -.64)


static func water_field(map: Dictionary, point: Vector2) -> float:
	var p := point-Vector2.ONE*.5
	var cell := Vector2i(floori(p.x),floori(p.y))
	var f := p-Vector2(cell)
	var rows := PackedFloat64Array()
	for dy in range(-1,3):
		rows.append(_cubic(_value_at(map,cell.y+dy,cell.x-1),_value_at(map,cell.y+dy,cell.x),_value_at(map,cell.y+dy,cell.x+1),_value_at(map,cell.y+dy,cell.x+2),f.x))
	var value := _cubic(rows[0],rows[1],rows[2],rows[3],f.y)
	if map.layout.has("pond_shapes"): value = maxf(value,_pond_field(map.layout,point))
	for patch in map.layout.wet_patches: value = maxf(value,(float(patch.radius)-point.distance_to(patch.at))*2)
	if value<-.14: return value
	if map.layout.has("pond_shapes") and Rect2(0,0,MapGen.W,MapGen.H).has_point(point):
		# Do not leave tiny water slivers stranded in otherwise dry gallery
		# aprons. Curved banks may extend into a neighbour, but stay near water.
		var support := -10.0
		for r in range(maxi(0,cell.y),mini(MapGen.H,cell.y+3)):
			for c in range(maxi(0,cell.x),mini(MapGen.W,cell.x+3)):
				if map.layout.terrain_base[MapGen.kk(r,c)]==WATER: support = maxf(support,(.92-point.distance_to(Vector2(c+.5,r+.5)))*2)
		value = minf(value,support)
	for entry in map.layout.get("occupancy",[]):
		if entry.asset=="bridge": continue
		var rect: Rect2 = entry.clearance
		var closest := Vector2(clampf(point.x,rect.position.x,rect.end.x),clampf(point.y,rect.position.y,rect.end.y))
		value = minf(value,(point.distance_to(closest)-.04)*2)
	for r in range(maxi(0,cell.y),mini(MapGen.H,cell.y+3)):
		for c in range(maxi(0,cell.x),mini(MapGen.W,cell.x+3)):
			var k := MapGen.kk(r,c)
			if map.ink[k]!=0 or map.layout.bridges.has(k): continue
			var center := Vector2(c+.5,r+.5)
			value = minf(value,(point.distance_to(center)-.26)*2)
			for delta: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
				var rr := r+delta.y
				var cc := c+delta.x
				if not MapGen.inb(rr,cc): continue
				var n := MapGen.kk(rr,cc)
				if map.ink[n]!=0 or map.layout.bridges.has(n): continue
				var q := Geometry2D.get_closest_point_to_segment(point,center,center+Vector2(delta))
				value = minf(value,(point.distance_to(q)-.26)*2)
	return value
