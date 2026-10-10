extends Control
class_name ReactionOverlay
## 短反馈：打出“无效词”时弹一下「无效词！/ 这家伙在说什么呢」，约 0.6 秒。
## 非阻塞（不挡字盘），有冷却防止连播。

const SHOW_TIME := 0.6

var _panel: PanelContainer
var _cooldown := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = Ink.panel("PanelCard")
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -320
	_panel.offset_right = -20
	_panel.offset_top = 92
	_panel.offset_bottom = 92 + 108
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var psb := (_panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	psb.bg_color.a = 1.0
	psb.shadow_size = 10
	psb.shadow_color = Color(0, 0, 0, 0.35)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)

	var pad := Ink.margin(10)
	_panel.add_child(pad)
	var row := Ink.hbox(10)
	pad.add_child(row)

	var face_holder := Control.new()
	face_holder.custom_minimum_size = Vector2(84, 84)
	face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/reactions/invalid_word.png"):
		var tr := TextureRect.new()
		tr.texture = load("res://assets/reactions/invalid_word.png")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		face_holder.add_child(tr)
	else:
		var face := ShockedFace.new()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face_holder.add_child(face)
	row.add_child(face_holder)

	var col := Ink.vbox(2)
	col.add_child(Ink.label("无效词！", "Subheading", Palette.VERMILION))
	col.add_child(Ink.label("这家伙在说什么呢", "Muted"))
	row.add_child(col)


func _process(delta: float) -> void:
	_cooldown = max(0.0, _cooldown - delta)


func show_invalid() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = SHOW_TIME + 0.4
	_panel.visible = true
	_panel.modulate.a = 1.0
	_panel.scale = Vector2(0.92, 0.92)
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func(): _panel.visible = false)
