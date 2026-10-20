extends RefCounted
class_name AchievementArt
static var _data := {}
static var _textures := {}

static func _load() -> void:
	if not _data.is_empty(): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/achievements/jade_icons.json"))
	if parsed is Dictionary: _data = parsed

static func title(definition: Dictionary) -> String:
	return str(definition.get("name", "成就"))

static func texture(definition: Dictionary) -> Texture2D:
	_load()
	var id := str(definition.get("badge_id", ""))
	if _textures.has(id): return _textures[id]
	# 策划指定单张资源时优先使用；默认复用已确认玉符总览的独立图案区域。
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(Achievements.CATALOG))
	if catalog is Dictionary:
		for badge in catalog.get("badges", []):
			if badge.id == id and not str(badge.asset_path).is_empty() and ResourceLoader.exists("res://" + str(badge.asset_path)):
				_textures[id] = load("res://" + str(badge.asset_path))
				return _textures[id]
	var meta: Dictionary = _data.get("icons", {}).get(id, {})
	if meta.is_empty(): return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(str(_data.texture))
	var r: Array = meta.region
	atlas.region = Rect2(r[0], r[1], r[2], r[3])
	atlas.filter_clip = true
	_textures[id] = atlas
	return atlas

static func icon(definition: Dictionary, pixels := 72.0, active := true) -> TextureRect:
	var view := TextureRect.new()
	view.texture = texture(definition)
	if view.texture is AtlasTexture:
		var key := ShaderMaterial.new()
		key.shader = preload("res://src/shaders/achievement_jade.gdshader")
		view.material = key
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = Vector2(pixels, pixels)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.modulate = Color.WHITE if active else Color(0.57, 0.65, 0.62, 0.65)
	return view
