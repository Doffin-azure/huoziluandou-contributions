extends Control
class_name ScreenBase
## 所有全屏界面的基类：自动铺宣纸底 + 提供 content 容器。

var params: Dictionary = {}
var content: Control


func setup(p: Dictionary) -> void:
	params = p


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Ink.paper_layer())
	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	build(content)


## 子类重写
func build(_root: Control) -> void:
	pass


func goto(path: String, p: Dictionary = {}) -> void:
	Router.goto(path, p)
