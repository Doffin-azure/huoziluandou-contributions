extends ColorRect
class_name ArtPaper
var strip := false
var tilt := 0.0
var _table: BattleTableScene
## 装饰纸面与游戏数据分离，全部文字仍是清晰的原生 UI。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := ShaderMaterial.new()
	surface.shader = load("res://src/shaders/art_paper.gdshader")
	surface.set_shader_parameter("paper_texture", load("res://assets/battle/xuan_sheet.png"))
	surface.set_shader_parameter("paper_color", Palette.PAPER)
	surface.set_shader_parameter("strip", strip)
	material = surface
	if not strip and is_instance_valid(Router.study_stage) and Router.study_stage.shared_table_active():
		_table = Router.study_stage.battle_table
		_table.register_paper(self)
		surface.set_shader_parameter("physical", true)
	resized.connect(_place_sheet)
	_place_sheet()


func _place_sheet() -> void:
	pivot_offset = size * 0.5
	rotation = 0.0 if strip else deg_to_rad(tilt)


func _exit_tree() -> void:
	if is_instance_valid(_table):
		_table.unregister_paper(self)
