extends RefCounted
class_name SaveCodec
## Save only plain data and a fixed set of game model types. Never deserialize Objects,
## load a path supplied by a save, or serialize presentation nodes/signals.
const TYPES := {
	"char": preload("res://src/core/char_instance.gd"),
	"combatant": preload("res://src/core/combatant.gd"),
	"board": preload("res://src/core/board_state.gd"),
	"battle": preload("res://src/core/battle_state.gd"),
	"expedition": preload("res://src/expedition/expedition.gd"),
	"character": preload("res://src/data/character_data.gd"),
	"effect": preload("res://src/data/effect_data.gd"),
	"enemy": preload("res://src/data/enemy_data.gd"),
	"move": preload("res://src/data/enemy_move_data.gd"),
	"word": preload("res://src/data/word_data.gd"),
	"node": preload("res://src/data/map_node_data.gd"),
	"rules": preload("res://src/data/battle_rules.gd"),
}
var valid := true
# Older saves may omit only the fields introduced by the restored monster roster.
# Unknown fields and missing pre-existing fields remain invalid.
const MONSTER_DEFAULT_FIELDS := {
	"battle": ["monster_net_energy", "monster_paid", "monster_entered", "_energy_spend_turn"],
	"combatant": ["largest_hp_hit"],
	"enemy": ["initial_block", "mechanic", "tuning", "act"],
	"move": ["mechanic_action", "inject_glyph"],
	"node": ["enemy_pool"],
}
var _ids := {}
var _nodes: Array = []
var _objects: Array = []


func pack(value: Dictionary) -> Dictionary:
	var root = _encode(value, 0)
	return {"root": root, "nodes": _nodes} if valid else {}


func _fields(object: Object) -> Dictionary:
	var fields := {}
	for property in object.get_script().get_script_property_list():
		if object.get_script() == TYPES.battle and str(property.name) == "achievement": continue
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields[str(property.name)] = property
	return fields


func _encode(value: Variant, depth: int) -> Variant:
	if depth > 80:
		valid = false
		return null
	if value is Object:
		if _ids.has(value.get_instance_id()): return {"ref": _ids[value.get_instance_id()]}
		var type := "rng" if value is RandomNumberGenerator else ""
		for key in TYPES:
			if value.get_script() == TYPES[key]: type = key; break
		if type.is_empty() or _nodes.size() >= 20000:
			valid = false
			return null
		var index := _nodes.size()
		_ids[value.get_instance_id()] = index
		var fields := {}
		_nodes.append({"type": type, "fields": fields})
		if type == "rng":
			fields.seed = value.seed
			fields.state = value.state
		else:
			for key in _fields(value):
				var field_value: Variant = value.get(key)
				if _is_log_field(type, key): field_value = RecentLog.bounded(field_value, type == "expedition")
				fields[key] = _encode(field_value, depth + 1)
		return {"ref": index}
	if value is Array:
		var items: Array = []
		for item in value: items.append(_encode(item, depth + 1))
		return {"array": items}
	if value is Dictionary:
		var pairs: Array = []
		for key in value: pairs.append([_encode(key, depth + 1), _encode(value[key], depth + 1)])
		return {"dict": pairs}
	if typeof(value) in [TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]: valid = false; return null
	return value


func unpack(data: Dictionary) -> Dictionary:
	if not data.get("nodes") is Array or data.nodes.size() > 20000: return {}
	for node in data.nodes:
		if not node is Dictionary or not node.get("fields") is Dictionary: return {}
		var type = node.get("type")
		if type == "rng": _objects.append(RandomNumberGenerator.new())
		elif type == "battle": _objects.append(BattleState.new(Database.rules))
		elif TYPES.has(type): _objects.append(TYPES[type].new())
		else: return {}
	# Allocate first so shared character identities and forward references survive.
	for index in data.nodes.size():
		var node: Dictionary = data.nodes[index]
		var object: Object = _objects[index]
		if node.type == "rng":
			if not node.fields.get("seed") is int or not node.fields.get("state") is int: return {}
			object.seed = node.fields.seed
			object.state = node.fields.state
			continue
		var fields := _fields(object)
		for key in fields:
			if not node.fields.has(key) and not MONSTER_DEFAULT_FIELDS.get(node.type, []).has(key): return {}
		for key in node.fields:
			if node.type == "expedition" and key == "tray":
				var legacy = _decode(node.fields[key], 0)
				if not valid or not legacy is Array or not legacy.all(func(g): return g is String and Database.get_character_by_glyph(g) != null): return {}
				object.set_meta("legacy_tray", legacy)
				continue
			if not fields.has(key): return {}
			var encoded: Variant = node.fields[key]
			# Crop legacy histories before decoding every old entry. Keep the same
			# field names/types so existing saves retain their full gameplay state.
			if _is_log_field(node.type, key) and encoded is Dictionary and encoded.get("array") is Array:
				var entries: Array = encoded.array
				encoded = {"array": entries.slice(0, RecentLog.MAX_ENTRIES) if node.type == "expedition" else entries.slice(maxi(0, entries.size() - RecentLog.MAX_ENTRIES))}
			var value = _decode(encoded, 0)
			if not valid or not _fits(value, fields[key]): return {}
			if _is_log_field(node.type, key):
				if not value.all(func(item): return item is String): return {}
				value = RecentLog.bounded(value, node.type == "expedition")
			var template = object.get(key)
			if template is Array and template.is_typed():
				for item in value:
					if not _fits_array(item, template): return {}
				template.assign(value)
				object.set(key, template)
			else: object.set(key, value)
	var root = _decode(data.get("root"), 0)
	if not valid or not root is Dictionary: return {}
	return root


func _is_log_field(type: String, key: String) -> bool:
	return (type == "battle" and key == "log") or (type == "expedition" and key == "lines")


func _fits(value: Variant, property: Dictionary) -> bool:
	var type := int(property.type)
	if type == TYPE_NIL: return true
	if type == TYPE_OBJECT:
		if value == null: return true
		if not value is Object: return false
		return value.is_class(property.class_name) or (value.get_script() != null and value.get_script().get_global_name() == property.class_name)
	return typeof(value) == type


func _fits_array(value: Variant, template: Array) -> bool:
	if template.get_typed_builtin() == TYPE_OBJECT:
		if value == null: return true
		var script = template.get_typed_script()
		return value is Object and (script == null or value.get_script() == script)
	return typeof(value) == template.get_typed_builtin()


func _decode(value: Variant, depth: int) -> Variant:
	if depth > 80: valid = false; return null
	if value is Dictionary:
		if value.size() != 1: valid = false; return null
		if value.has("ref") and value.ref is int and value.ref >= 0 and value.ref < _objects.size(): return _objects[value.ref]
		if value.get("array") is Array:
			var array: Array = []
			for item in value.array: array.append(_decode(item, depth + 1))
			return array
		if value.get("dict") is Array:
			var dict := {}
			for pair in value.dict:
				if not pair is Array or pair.size() != 2: valid = false; return null
				var key = _decode(pair[0], depth + 1)
				if key is Object or key is Array or key is Dictionary: valid = false; return null
				dict[key] = _decode(pair[1], depth + 1)
			return dict
		valid = false
		return null
	if value is Array or value is Object or typeof(value) in [TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]: valid = false; return null
	return value
