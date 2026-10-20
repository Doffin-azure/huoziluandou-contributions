extends HBoxContainer
class_name DefenseDisplay
## 只承接血条防御数值；不混入状态、能力或游戏规则。
signal details_requested(title: String, body: String, scroll_body: bool)
var block := 0
var persistent_block := 0
var is_player := true
var cell_size := 40.0
var _badges: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_PASS
	for id in ["block", "persistent_block"]:
		var badge := ShieldBadge.new()
		badge.persistent = id == "persistent_block"
		badge.pressed.connect(_show_details.bind(id))
		_badges[id] = badge
		add_child(badge)
	_sync()


func set_values(temporary: int, persistent: int) -> void:
	block = maxi(0, temporary)
	persistent_block = maxi(0, persistent)
	_sync()


func set_cell_size(value: float) -> void:
	cell_size = value
	_sync()


func display_width() -> float:
	# 固定预留两种盾的位置；出现、耗尽或数值变化都不再推挤血条。
	return 2.0 * cell_size


func badge_for(id: String) -> ShieldBadge:
	return _badges.get(id)


func _sync() -> void:
	visible = block > 0 or persistent_block > 0
	for id in _badges:
		var badge: ShieldBadge = _badges[id]
		badge.value = block if id == "block" else persistent_block
		badge.visible = badge.value > 0
		badge.ui_scale = cell_size / 40.0
		badge.custom_minimum_size = Vector2.ONE * cell_size
		badge.tooltip_text = "%s · %d 点\n%s" % [_title(id), badge.value, _description(id)]
		badge.queue_redraw()


func _title(id: String) -> String:
	return "持久盾" if id == "persistent_block" else ("临时格挡" if is_player else "护盾")


func _description(id: String) -> String:
	if id == "persistent_block": return "临时格挡用完后继续抵挡伤害，剩余值保留到下回合。"
	return "先于持久盾抵挡伤害。" + ("所有敌人行动后清空。" if is_player else "剩余值保留到下回合。")


func _show_details(id: String) -> void:
	var value := block if id == "block" else persistent_block
	details_requested.emit("%s · %d 点" % [_title(id), value], _description(id), false)
