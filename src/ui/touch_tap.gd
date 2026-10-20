extends RefCounted
class_name TouchTap
## Raw Control hit targets: activate on a finger release, never on a scroll or
## canceled touch. Native touch consumes its emulated mouse duplicate.
var _finger := -1
var _origin := Vector2.ZERO
var _moved := false


func matches(event: InputEvent, control: Control) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and (_finger < 0 or event.index == _finger):
			_finger = event.index
			_origin = event.position
			_moved = false
		elif not event.pressed and event.index == _finger:
			_finger = -1
			var tap: bool = not event.canceled and not _moved and _origin.distance_to(event.position) <= 12 * JourneyStyle.touch_scale(control) and Rect2(Vector2.ZERO, control.size).has_point(event.position)
			if tap: control.accept_event()
			return tap
	elif event is InputEventScreenDrag and event.index == _finger:
		_moved = _moved or _origin.distance_to(event.position) > 12 * JourneyStyle.touch_scale(control)
	elif event is InputEventMouseButton:
		# Godot emits the simulated mouse press BEFORE its native ScreenTouch.
		# Waiting until a finger was observed allows duplicate actions or makes
		# the same gesture immediately dismiss a freshly opened details sheet.
		if event.device == InputEvent.DEVICE_ID_EMULATION: return false
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			control.accept_event()
			return true
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		control.accept_event()
		return true
	return false
