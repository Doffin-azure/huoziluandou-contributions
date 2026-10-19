extends Control
var lab: Control


func _draw() -> void:
	if lab==null or not lab.grid_toggle.button_pressed: return
	for cell in lab.run.layout.cells:
		var entry: Dictionary = lab.run.layout.cells[cell]
		if not entry.rooms.any(func(id): return lab.cluster.members.has(id)) and not entry.edges.any(func(id): return lab.cluster.members.has(id.split(">")[0]) and lab.cluster.members.has(id.split(">")[1])): continue
		var p: Vector2 = lab.run.layout.point(cell)
		var at: Vector2 = lab.camera.unproject_position(Vector3(p.x,.03,p.y))
		draw_circle(at,1.4,Color(.56,.78,.66,.62) if entry.edges.is_empty() else Color(.85,.63,.36,.85))
	draw_string(Ink.serif,Vector2(24,74),"真实通行数据：绿点为节点庭地，金点为连接路径；内池和植床不参与行走",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("d4c39f"))
