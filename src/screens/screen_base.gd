extends Control
class_name ScreenBase
## 所有全屏界面的基类：自动铺宣纸底 + 提供 content 容器。

var params: Dictionary = {}
var content: Control


func setup(p: Dictionary) -> void:
	params = p


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var world_backed := is_instance_valid(Router.study_stage) and Router.study_stage.visible
	var path: String = get_script().resource_path
	if not world_backed or (not path.contains("title_screen") and not path.contains("battle_screen")):
		var paper := Ink.paper_layer()
		if world_backed:
			var material := ShaderMaterial.new()
			material.shader = load("res://src/shaders/study_sheet.gdshader")
			material.set_shader_parameter("paper_color", Palette.PAPER)
			material.set_shader_parameter("margin", Vector2(0.045, 0.075) if path.contains("map_screen") else Vector2(0.010, 0.008))
			paper.material = material
		add_child(paper)
	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	build(content)


## 子类重写
func build(_root: Control) -> void:
	pass


func goto(path: String, p: Dictionary = {}) -> void:
	Router.goto(path, p)
