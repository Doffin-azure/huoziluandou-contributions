extends RefCounted
## 事件插图清单。清单里的图片尚未生成时返回空路径，事件页继续使用纯文字。
## 这样美术批量产出后只需把文件放到 manifest 指定位置，不需要逐条改事件目录。

const MANIFEST := "res://assets/events/art_manifest.json"
static var _entries: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST):
		return
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_entries = parsed.get("events", {})


static func entry(event_id: String) -> Dictionary:
	_load()
	return _entries.get(event_id, {})


static func path_for(event_id: String) -> String:
	var data := entry(event_id)
	var path := str(data.get("path", ""))
	if path.is_empty():
		return ""
	var res_path := path if path.begins_with("res://") else "res://" + path
	return res_path if ResourceLoader.exists(res_path) else ""


static func style_for(event_id: String) -> String:
	return str(entry(event_id).get("style", "scene"))
