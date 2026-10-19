extends RefCounted
## Existing models occupy reserved corner bays, leaving doorways and through
## lanes intact. Coordinates follow the same local prop contract as old rooms.
const SETS := {
	"start":["writing_desk","type_cabinet","lotus_tub","lamp"],
	"battle":["incense","stone_bench","type_rack","lamp"],
	"elite":["incense","type_cabinet","stone_bench","lamp"],
	"boss":["incense","type_cabinet","lotus_tub","lamp"],
	"event":["writing_desk","type_rack","incense","lamp"],
	"shop":["type_cabinet","type_rack","writing_desk","lamp"],
	"rest":["stone_table","stone_bench","lotus_tub","lamp"],
	"treasure":["type_cabinet","incense","lotus_tub","lamp"],
}


static func populate(room: Dictionary, node: Dictionary, plan: RefCounted) -> void:
	var half := (Vector2i(node.extent)-Vector2i.ONE)/2
	var index := 0
	var corner_signs: Array[Vector2i] = [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]
	for sign_at: Vector2i in corner_signs:
		var cell := Vector2i(node.at)+sign_at*half
		var point := Vector2(cell)-Vector2(sign_at)*.26
		var local: Vector2 = room.transform.affine_inverse()*point
		var asset: String = SETS[room.kind][index]; index += 1
		var scale_value := .45 if asset=="stone_table" else (.55 if asset=="stone_bench" else .65)
		room.props.append({"asset":asset,"at":Vector3(local.x,0,local.y),"scale":scale_value,"turn":0.0,"reserved_cell":cell})
		for neighbor: Vector2i in plan.links.get(cell,[]): plan.links[neighbor].erase(cell)
		plan.links.erase(cell)
	# A long hall gets two useful wall bays near its center. They reserve the
	# actual occupied tiles, instead of moving visual props onto a walking lane.
	var vertical := half.y>=half.x
	if maxi(half.x,half.y)<3: return
	for side in [-1,1]:
		var cell := Vector2i(node.at)+(Vector2i(side*half.x,0) if vertical else Vector2i(0,side*half.y))
		if node.doors.any(func(door):return Vector2i(door.cell).distance_to(cell)<1.5): continue
		var point := Vector2(cell)+(Vector2(-side*.12,0) if vertical else Vector2(0,-side*.12))
		var local: Vector2 = room.transform.affine_inverse()*point
		room.props.append({"asset":"writing_desk" if side<0 else "type_cabinet","at":Vector3(local.x,0,local.y),"scale":.75,"turn":PI*.5 if vertical else 0.0,"reserved_cell":cell})
		for neighbor: Vector2i in plan.links.get(cell,[]): plan.links[neighbor].erase(cell)
		plan.links.erase(cell)
