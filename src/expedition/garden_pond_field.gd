extends RefCounted
## Positive signed field is water. Rendering and navigation use this same shape.


static func sample(ponds: Array, point: Vector2) -> float:
	var value := -100.0
	for pond: Dictionary in ponds:
		var local := (point-Vector2(pond.center)).rotated(-float(pond.get("turn",0)))
		var radius: Vector2 = pond.radius
		var p := local/radius
		var angle := atan2(p.y,p.x)
		var phase := int(pond.get("seed",137))*.173
		var edge := 1.0+.055*sin(angle*3+phase)+.035*cos(angle*5-phase)
		value = maxf(value,(edge-p.length())*minf(radius.x,radius.y))
	return value


static func world_ponds(room: Dictionary) -> Array:
	var result: Array = []
	var transform: Transform2D = room.transform
	for source: Dictionary in room.get("ponds",[]):
		var pond := source.duplicate(true)
		pond.center = transform*Vector2(source.center)
		pond.turn = float(source.get("turn",0))+transform.get_rotation()
		result.append(pond)
	return result
