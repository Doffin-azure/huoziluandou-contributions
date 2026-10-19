extends Node3D
## A closed visual enclosure exactly follows the playable rectangle.
## Occupancy and movement remain governed by the existing map bounds.
const BOUNDARY = preload("res://src/map/expedition_garden_boundary.gd")
var records: Array[Dictionary] = []
var fade_roots: Array[Node3D] = []
var assembly: Node3D


func setup(style: ExpeditionFlatStyle) -> void:
	name = "ClosedGardenPerimeter"
	scale = Vector3.ONE*.5
	assembly = BOUNDARY.assemble(self,style,[Vector3.ZERO,Vector3(MapGen.W*2,0,0),Vector3(MapGen.W*2,0,MapGen.H*2),Vector3(0,0,MapGen.H*2)],true,true,true)
	for part in assembly.get_children():
		var is_bay: bool = part.piece in [BOUNDARY.Piece.WALL,BOUNDARY.Piece.WINDOW_WALL]
		var local_center := Vector3(1,0,0) if is_bay else Vector3.ZERO
		var at: Vector3 = part.to_global(local_center)
		part.set_meta("occlusion_center",local_center)
		part.set_meta("height",1.1)
		part.set_meta("visual_width",1.2 if is_bay else .34)
		part.set_meta("perimeter",true)
		part.set_meta("occlusion_fade",.58)
		if is_bay:
			# A continuous opaque foundation marks the limit even when the upper
			# wall fades near the player, and supports it over water at map edges.
			var plinth: MeshInstance3D = part.box(Vector3(1,-.025,0),Vector3(2,1.15,.44),"architecture",.45)
			plinth.name = "ContinuousBoundaryPlinth"
			plinth.set_meta("ground_imprint",true)
			var cap: MeshInstance3D = part.box(Vector3(1,.555,0),Vector3(2,.055,.49),"stone",.40)
			cap.name = "BoundaryPlinthCap"
			cap.set_meta("ground_imprint",true)
		var cells: Array = []
		for dx in [-.20,.20]:
			for dz in [-.20,.20]:
				var row := floori(at.z+dz)
				var col := floori(at.x+dx)
				if MapGen.inb(row,col):
					var k := MapGen.kk(row,col)
					if not cells.has(k): cells.append(k)
		records.append({"root":part,"cells":cells,"outside":false})
		fade_roots.append(part)
