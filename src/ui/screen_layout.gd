extends RefCounted
class_name ScreenLayout
## UI coordinates, Android density and display cutouts share one conversion.
## Preview values let desktop checks exercise the same paths as exported phones.
static var preview_density := 0.0
static var preview_window_size := Vector2i.ZERO
static var preview_insets := Vector4.ZERO # physical pixels: left, top, right, bottom


static func density() -> float:
	if preview_density > 0.0: return preview_density
	if OS.has_feature("android"): return maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	if OS.has_feature("ios"): return maxf(1.0, DisplayServer.screen_get_scale())
	return 1.0


static func window_size(control: Control) -> Vector2i:
	return preview_window_size if preview_window_size != Vector2i.ZERO else control.get_window().size


static func unit_for(view_size: Vector2, pixels: Vector2i) -> float:
	return maxf(1.0, view_size.y / maxf(1, pixels.y) * density())


static func unit(control: Control) -> float:
	return unit_for(control.get_viewport_rect().size, window_size(control))


static func safe_rect(control: Control) -> Rect2:
	var pixels := Vector2(window_size(control))
	var usable := Rect2(Vector2.ZERO, pixels)
	if preview_window_size != Vector2i.ZERO:
		usable.position = Vector2(preview_insets.x, preview_insets.y)
		usable.size -= usable.position + Vector2(preview_insets.z, preview_insets.w)
	elif OS.has_feature("android") or OS.has_feature("ios"):
		var display := DisplayServer.get_display_safe_area()
		if display.has_area():
			var relative := Rect2(Vector2(display.position - control.get_window().position), Vector2(display.size))
			usable = usable.intersection(relative)
	if not usable.has_area(): usable = Rect2(Vector2.ZERO, pixels)
	var ratio := control.get_viewport_rect().size / pixels.max(Vector2.ONE)
	var viewport_rect := Rect2(usable.position * ratio, usable.size * ratio)
	return control.get_global_transform().affine_inverse() * viewport_rect


static func margins(frame: MarginContainer, control: Control, padding: float) -> void:
	var safe := safe_rect(control)
	var full := control.get_rect().size
	frame.add_theme_constant_override("margin_left", ceili(safe.position.x + padding))
	frame.add_theme_constant_override("margin_top", ceili(safe.position.y + padding))
	frame.add_theme_constant_override("margin_right", ceili(maxf(0, full.x - safe.end.x) + padding))
	frame.add_theme_constant_override("margin_bottom", ceili(maxf(0, full.y - safe.end.y) + padding))
