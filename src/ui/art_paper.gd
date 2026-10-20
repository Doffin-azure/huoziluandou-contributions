extends ColorRect
class_name ArtPaper
## 青铜绘卷装饰底板，文字和交互由原生 UI 承载。
var strip := false
var open_scene := false:
	set(value):
		open_scene = value
		if material is ShaderMaterial:
			material.set_shader_parameter("open_scene", value)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://src/shaders/taopunk_paper.gdshader")
	surface.set_shader_parameter("paper_texture", preload("res://assets/taopunk/parchment_panel.png"))
	surface.set_shader_parameter("strip", strip)
	surface.set_shader_parameter("open_scene", open_scene)
	material = surface
