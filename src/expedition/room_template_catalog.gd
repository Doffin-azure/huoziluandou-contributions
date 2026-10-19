extends RefCounted
## Authored room samples. Coordinates are local world X/Z units; +Z is south.
## This is layout/asset data, independent of encounters, rewards and route RNG.
const INTERIORS = preload("res://src/expedition/room_interior_assets.gd")


static func _prop(asset: String, x: float, z: float, scale_value := .5, variant := 0, turn := 0.0, state := "") -> Dictionary:
	return {"asset":asset,"at":Vector3(x,0,z),"scale":scale_value,"variant":variant,"turn":turn,"state":state}


static func _port(side: String, offset: float, role := "exit", frame := "moon", span := 2.0) -> Dictionary:
	return {"id":side.to_lower()+"_"+role,"side":side,"offset":offset,"role":role,"role_mutable":true,"frame":frame,"span":1.0 if frame=="open" else span,"clear_width":.95}


static func templates() -> Array[Dictionary]:
	return [
		{"id":"start_gatehouse","kind":"start","name":"起点 · 照壁门院","floor_size":Vector2i(4,4),"enclosure":"walled",
		 "description":"照壁对景，西侧书案与字柜，东侧红枫石床与长凳；中间整备、出门。",
		 "ports":[_port("S",2)],"water_sides":[],"rail_sides":[],"stand":Vector2(2,2.4),
		 "lanes":[[Vector2(2,4),Vector2(2,1.5)]],"mark":"始","mark_at":Vector2(2,3.1),
		 "props":_interior("start"),
		 "variants":["标准单出口","可整体旋转，仍仅一扇通路门"]},
		{"id":"event_bent_court","kind":"event","name":"事件 · 问碑小院","floor_size":Vector2i(5,4),"enclosure":"walled",
		 "description":"碑龛与香炉构成问字区，洞石与枯槐对景；坐凳靠墙，月门形成折景。",
		 "ports":[_port("S",2.5,"entry"),_port("E",2.5)],"water_sides":["E"],"rail_sides":[],"stand":Vector2(1.35,2.1),
		 "lanes":[[Vector2(2.5,4),Vector2(2.5,2.5),Vector2(5,2.5)],[Vector2(2.5,2.1),Vector2(1.35,2.1)]],
		 "mark":"谜","mark_at":Vector2(1.35,2.1),
		 "props":_interior("event"),
		 "variants":["东折门","直通门：出门转到北侧，碑龛移至西侧"]},
		{"id":"rest_lantern_court","kind":"rest","name":"火堆 · 息灯水榭","floor_size":Vector2i(5,5),"enclosure":"terrace",
		 "description":"方亭、临水柳、荷缸与石桌组成休整庭，鬼火位于通路一侧；四边统一栏杆。",
		 "ports":[_port("S",2.5,"entry","open"),_port("N",2.5,"exit","open"),_port("E",3.5,"exit","open")],"water_sides":["N","E","W"],"rail_sides":["N","E","S","W"],"stand":Vector2(2.65,3),
		 "lanes":[[Vector2(2.5,5),Vector2(2.5,0)],[Vector2(2.5,3.5),Vector2(5,3.5)]],"mark":"息","mark_at":Vector2(2.65,3),
		 "props":_interior("rest"),
		 "variants":["三门休整庭","两门：关闭侧门并补齐同款栏杆"]},
		{"id":"battle_side_gallery","kind":"battle","name":"普通战 · 廊围石庭","floor_size":Vector2i(6,5),"enclosure":"walled",
		 "description":"西廊配字架与长凳，怪松与低山压住对角；中央空庭保持交战和通行空间。",
		 "ports":[_port("S",3,"entry"),_port("N",3),_port("E",2.5)],"water_sides":["E"],"rail_sides":[],"stand":Vector2(3,3.9),
		 "lanes":[[Vector2(3,5),Vector2(3,0)],[Vector2(3,2.5),Vector2(6,2.5)]],"arena":Rect2(2,1.3,3,2.7),"mark":"战","mark_at":Vector2(3,3.3),
		 "props":_interior("battle"),
		 "variants":["侧廊三门","素庭四门：去掉西廊，打开西门"]},
		{"id":"elite_stele_court","kind":"elite","name":"精英 · 镇碑夹庭","floor_size":Vector2i(7,6),"enclosure":"walled",
		 "description":"两翼高低碑、枯槐与洞石，香炉和鬼火引向镇门；中央留出交战庭。",
		 "ports":[_port("S",3.5,"entry"),_port("N",3.5,"exit","beast")],"water_sides":["W"],"rail_sides":[],"stand":Vector2(3.5,4.7),
		 "lanes":[[Vector2(3.5,6),Vector2(3.5,0)]],"arena":Rect2(2,1.5,3,3),"mark":"镇","mark_at":Vector2(3.5,4.1),
		 "props":_interior("elite"),
		 "variants":["前后夹庭","镜像碑群；入口可旋转到侧面"]},
		{"id":"boss_terminal_court","kind":"boss","name":"首领 · 墨渊终庭","floor_size":Vector2i(9,7),"enclosure":"walled",
		 "description":"小阁与六角亭分立镇门两翼，碑炉、红枫与怪松分层夹景；中央仪式庭留白。",
		 "ports":[_port("S",4.5,"entry"),_port("N",4.5,"exit","beast",3)],"water_sides":["E","W"],"rail_sides":[],"stand":Vector2(4.5,5.8),
		 "lanes":[[Vector2(4.5,7),Vector2(4.5,0)]],"arena":Rect2(2,1.6,5,3.8),"mark":"渊","mark_at":Vector2(4.5,5),
		 "props":_interior("boss"),
		 "variants":["水岸终庭","后门仅在通关后开放；不参与普通随机中转"]},
		{"id":"treasure_water_pavilion","kind":"treasure","name":"宝藏 · 荷池藏榭","floor_size":Vector2i(4,4),"enclosure":"terrace",
		 "description":"水榭内收宝匣，红枫、荷缸与字架置于四角；侧面保留绕匣通行，开口只设栏端柱。",
		 "ports":[_port("S",2,"entry","open"),_port("N",2,"exit","open")],"water_sides":["N","S","E","W"],"rail_sides":["N","E","S","W"],"stand":Vector2(2,2.7),
		 "lanes":[[Vector2(2,4),Vector2(2,2.7),Vector2(2.75,2.7),Vector2(2.75,.4),Vector2(2,.4),Vector2(2,0)]],"mark":"藏","mark_at":Vector2(2,2.7),
		 "props":_interior("treasure"),
		 "variants":["前后双门","汇合四门：补两侧门，关闭短桥展示，保持绕匣通行"]},
		{"id":"shop_bronze_court","kind":"shop","name":"商店 · 青铜字肆","floor_size":Vector2i(6,5),"enclosure":"walled",
		 "description":"小阁为后库，字摊靠后墙；侧面安排书案、货架和箱匣，红枫石床收在另一角。",
		 "ports":[_port("S",3,"entry"),_port("E",3)],"water_sides":["E"],"rail_sides":[],"stand":Vector2(3,2.7),
		 "lanes":[[Vector2(3,5),Vector2(3,3),Vector2(6,3)]],"mark":"市","mark_at":Vector2(3,2.7),
		 "props":_interior("shop"),
		 "variants":["东折离店","镜像到西侧；库存与主物件位置共同迁移"]}
	]


static func _d(asset: String, x: float, z: float, scale_value := .5, turn := 0.0) -> Dictionary:
	var prop := _prop(asset,x,z,scale_value,0,turn)
	prop["dressing"] = true
	return prop


static func _interior(kind: String) -> Array:
	match kind:
		"start": return [
			_prop("screen",2,.48,.60),_prop("type_cabinet",.65,1.55,.72),_prop("chest",.65,2.4,.40),
			_d("writing_desk",.70,3.25,.70),_d("rock_bed",3.15,1.40,.70),_d("red_maple",3.15,1.40,.32),
			_d("stone_bench",3.35,2.55,.65,PI*.5),_prop("lamp",3.35,3.35,.36)]
		"event": return [
			_prop("stele_plinth",1.35,.82,1.10),_prop("shrine",1.35,.82,.66,0,0,"service"),
			_d("incense",1.35,1.55,.40),_d("hollow_rockery",3.20,.85,.43),_d("bare_locust",4.25,.65,.42),
			_d("stone_bench",.62,3.0,.62,PI*.5),_d("lotus_tub",4.35,3.25,.58),_prop("lamp",.65,.55,.32)]
		"rest": return [
			_prop("square_pavilion",1.30,1.10,.66,0,0,"service"),_prop("ghost_fire",3.55,3,.67,0,0,"fire"),
			_d("stone_table",1.15,3.70,.69),_d("willow",4.15,.9,.36),_d("low_rockery",3.55,.9,.30),
			_d("lotus_tub",4.28,1.95,.57),_d("lamp",4.30,4.35,.34)]
		"battle": return [
			_prop("covered_walk",.82,2.5,.60,0,PI*.5),_prop("foe",3,2.35,.92,1,0,"enemy"),
			_d("rock_bed",5.10,.85,.87),_d("crooked_pine",5.10,.85,.37),_d("low_rockery",4.95,4.08,.43),
			_d("type_rack",.78,.65,.70),_d("stone_bench",1.05,4.15,.72),_d("incense",5.35,2.5,.47)]
		"elite": return [
			_prop("stele_plinth",1.15,1.1,1.15),_prop("tomb",1.15,1.1,.58,0),
			_prop("stele_plinth",5.8,1.1,1.15),_prop("tomb",5.8,1.1,.49,3),_prop("tomb",1.10,2.3,.39,2),
			_d("bare_locust",1.05,3.25,.46),_d("hollow_rockery",5.85,3.0,.49),_d("incense",5.8,1.95,.45),
			_prop("ghost_fire",1.1,4.8,.46),_d("lotus_tub",5.8,4.85,.64),_prop("elite",3.5,3.05,1.2,2,0,"enemy")]
		"boss": return [
			_d("small_loft",1.55,1.40,.62),_d("hex_pavilion",7.45,1.40,.62),
			_prop("stele_plinth",1.55,3.3,1.10),_prop("tomb",1.55,3.3,.60,0),
			_prop("stele_plinth",7.45,3.3,1.10),_prop("tomb",7.45,3.3,.56,3),
			_d("incense",1.55,4.30,.46),_d("incense",7.45,4.30,.46),
			_d("red_maple",1.15,5.65,.42),_d("crooked_pine",7.85,5.65,.42),
			_prop("ghost_fire",3.0,2.5,.55),_prop("ghost_fire",6.0,2.5,.55),
			_d("stone_bench",2.75,6.05,.60),_d("stone_bench",6.25,6.05,.60),_prop("boss",4.5,3.65,1.65,3,0,"enemy")]
		"treasure": return [
			_prop("water_pavilion",2,1.35,1.0),_prop("chest",2,1.50,.70,1,0,"service"),
			_d("red_maple",.60,3.25,.29),_d("lotus_tub",3.45,.55,.60),_d("incense",.50,.55,.40),
			_d("type_rack",3.45,2.5,.48),_prop("lamp",3.45,3.35,.34)]
		"shop": return [
			_prop("stall",3,1.1,.82,0,0,"service"),_prop("shopkeeper",3,.42,1.0),_d("small_loft",1.15,1.02,.50),
			_d("type_cabinet",.68,2.5,.66,PI*.5),_d("writing_desk",1.20,3.65,.80),_d("chest",1.55,2.55,.40),
			_d("rock_bed",5.30,1.35,.46),_d("red_maple",5.30,1.35,.29),
			_d("type_rack",5.3,3.05,.66,-PI*.5),_d("lotus_tub",5.15,4.25,.60),_prop("lamp",.65,4.25,.34)]
	return []


static func with_variant(source: Dictionary, alternate: bool) -> Dictionary:
	var room := source.duplicate(true)
	room["variant"] = 0
	if not alternate or room.kind not in ["battle","treasure","rest","event"]: return room
	room.variant = 1
	match room.kind:
		"battle":
			room.props = room.props.filter(func(p): return p.asset!="covered_walk")
			room.ports.append(_port("W",2.5,"entry"))
			room.lanes.append([Vector2(0,2.5),Vector2(6,2.5)])
			room.name = "普通战 · 四门素庭"
		"treasure":
			room.ports.append(_port("E",2.5,"exit","open"))
			room.ports.append(_port("W",2.5,"entry","open"))
			room.erase("bridge_side")
			room.lanes.append([Vector2(0,2.5),Vector2(4,2.5)])
			room.name = "宝藏 · 四门汇合台"
		"rest":
			room.ports = room.ports.filter(func(p): return p.side!="E")
			room.lanes = [room.lanes[0]]
			room.name = "火堆 · 双门息灯庭"
		"event":
			room.ports[1] = _port("N",2.5)
			room.lanes[0] = [Vector2(2.5,4),Vector2(2.5,0)]
			room.name = "事件 · 直通问字庭"
	return room


static func apply_enclosure(room: Dictionary) -> void:
	# The complete room owns its enclosure. Water placement cannot change one wall
	# into an unrelated railing, including ports reoriented by the route generator.
	var terrace: bool = room.get("enclosure","walled")=="terrace"
	room.rail_sides = ["N","E","S","W"] if terrace else []
	if terrace:
		for port in room.ports:
			port.frame = "open"
			port.span = 1.0
	_adapt_interior(room)


static func _adapt_interior(room: Dictionary) -> void:
	# Re-run from the authored list when a runtime merge turns its entrance.
	# Dropping a small decorative group is preferable to putting a tree in a door.
	if not room.has("_interior_source"): room["_interior_source"] = room.props.duplicate(true)
	var clearances: Array[Rect2] = [Rect2(room.stand-Vector2.ONE*.42,Vector2.ONE*.84)]
	for lane: Array in room.lanes:
		for n in range(lane.size()-1): clearances.append(Rect2(lane[n],Vector2.ZERO).expand(lane[n+1]).grow(.32))
	var gate_bounds: Array[Rect2] = []
	for port in room.ports:
		var point := port_position(room,port)
		var at := Vector2(point.x,point.z)
		var normal: Vector2 = {"N":Vector2.DOWN,"S":Vector2.UP,"E":Vector2.LEFT,"W":Vector2.RIGHT}[port.side]
		var deep := Rect2(at,Vector2.ZERO).expand(at+normal*1.15).grow(.39)
		clearances.append(deep)
		gate_bounds.append(Rect2(at-Vector2(port.span*.5+.10,.28),Vector2(port.span+.20,.56)) if port.side in ["N","S"] else Rect2(at-Vector2(.28,port.span*.5+.10),Vector2(.56,port.span+.20)))
	room.props = []
	for source: Dictionary in room._interior_source:
		var prop := source.duplicate(true)
		if prop.get("dressing",false):
			var rect := INTERIORS.placed_rect(prop).grow(.10)
			var visual := INTERIORS.placed_rect(prop,true)
			if clearances.any(func(area): return area.intersects(rect)) or gate_bounds.any(func(area): return area.intersects(visual)): continue
		room.props.append(prop)


static func port_position(room: Dictionary, port: Dictionary) -> Vector3:
	match port.side:
		"N": return Vector3(port.offset,0,0)
		"E": return Vector3(room.floor_size.x,0,port.offset)
		"S": return Vector3(port.offset,0,room.floor_size.y)
		_: return Vector3(0,0,port.offset)
