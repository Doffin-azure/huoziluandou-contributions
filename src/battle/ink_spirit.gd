extends Control
class_name InkSpirit
## 按风格显示透明角色；未映射的敌人保留原字形回退。
var glyph := "墨"
var enemy_id := "ink_spirit":
	set(value):
		enemy_id = value
		if is_node_ready(): _sync_actor()
var _ink: Texture2D
var _character: Texture2D
var _actor: InkGuardianActor
var _attack_actor: EnemyAttackActor
## Articulated actor contract: framing, play_action, feedback, origin, effect, defeated.
const CHARACTER_ACTORS := {
	"paper_shell_soldier": preload("res://src/battle/paper_shell_actor.gd"),
	"needle_wasp": preload("res://src/battle/needle_wasp_actor.gd"),
	"tilting_inkstone": preload("res://src/battle/tilting_inkstone_actor.gd"),
	"fold_page_moth": preload("res://src/battle/fold_page_moth_actor.gd"),
}
var _character_actor: Node2D
var _character_actor_id := ""
var _paper_actor: PaperShellActor:
	get: return _character_actor as PaperShellActor


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ink = load("res://assets/battle/ink_spirit.png")
	_character = load("res://assets/battle/ink_spirit_character.png")
	resized.connect(_fit_actor)
	_sync_actor()


func _sync_actor() -> void:
	var character_active := CHARACTER_ACTORS.has(enemy_id) and Palette.STYLE_ID == "taopunk"
	if _character_actor != null and _character_actor_id != enemy_id:
		_character_actor.queue_free()
		_character_actor = null
	if character_active and _character_actor == null:
		_character_actor = CHARACTER_ACTORS[enemy_id].new()
		_character_actor_id = enemy_id
		add_child(_character_actor)
	if _character_actor != null:
		_character_actor.visible = character_active
		_character_actor.process_mode = Node.PROCESS_MODE_INHERIT if character_active else Node.PROCESS_MODE_DISABLED
	var active := enemy_id == "ink_spirit" and Palette.STYLE_ID == "taopunk"
	if active and _actor == null:
		_actor = InkGuardianActor.new()
		add_child(_actor)
	if _actor != null:
		_actor.visible = active
		_actor.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	var attack_active := EnemyAttackActor.available(enemy_id) and Palette.STYLE_ID == "taopunk"
	if _attack_actor != null and _attack_actor.enemy_id != enemy_id:
		_attack_actor.queue_free()
		_attack_actor = null
	if attack_active and _attack_actor == null:
		_attack_actor = EnemyAttackActor.new()
		_attack_actor.enemy_id = enemy_id
		add_child(_attack_actor)
	if _attack_actor != null:
		_attack_actor.visible = attack_active
		_attack_actor.process_mode = Node.PROCESS_MODE_INHERIT if attack_active else Node.PROCESS_MODE_DISABLED
	_fit_actor()


func _fit_actor() -> void:
	if _character_actor != null:
		var framing: Dictionary = _character_actor.call("framing")
		var region: Rect2 = framing.rect
		var factor := minf(size.x / region.size.x, size.y / region.size.y) * float(framing.fill)
		_character_actor.position = Vector2((size.x - region.size.x * factor) * 0.5, size.y - region.size.y * factor - float(framing.bottom)) - region.position * factor
		_character_actor.scale = Vector2.ONE * factor
	if _actor != null:
		var area := portrait_rect(TaopunkArt.portrait("ink_spirit"), size, "ink_spirit")
		_actor.position = area.position
		_actor.scale = area.size / InkGuardianActor.SOURCE_SIZE
	if _attack_actor != null:
		# 按全部关键姿势的共同画布等比适配，不能按原立绘比例拉伸新动作。
		var factor := minf(size.x / _attack_actor.source_size.x, size.y / _attack_actor.source_size.y) * 0.94
		var extent := _attack_actor.source_size * factor
		_attack_actor.position = Vector2((size.x - extent.x) * 0.5, size.y - extent.y)
		_attack_actor.scale = Vector2.ONE * factor
	queue_redraw()


func play_action(move: EnemyMoveData) -> Dictionary:
	if has_character_actor(): return _character_actor.call("play_action",move)
	return _actor.play_action(move) if _actor != null and _actor.visible else {}


func action_origin() -> Vector2:
	if has_character_actor(): return _character_actor.call("action_global_position")
	if _attack_actor != null and _attack_actor.visible: return _attack_actor.eye_global_position()
	return _actor.eye_global_position() if _actor != null and _actor.visible else get_global_rect().get_center()


func set_defeated(value: bool) -> void:
	if _character_actor != null: _character_actor.set("defeated",value)
	if _actor != null: _actor.defeated = value
	if _attack_actor != null: _attack_actor.defeated = value


func has_attack_actor() -> bool:
	return has_character_actor() or (_attack_actor != null and _attack_actor.visible)


func has_paper_actor() -> bool:
	return _paper_actor != null and _paper_actor.visible


func has_character_actor() -> bool:
	return _character_actor != null and _character_actor.visible


func attack_effect() -> String:
	if has_character_actor(): return _character_actor.call("attack_effect")
	return EnemyAttackProfiles.get_profile(enemy_id).get("effect","paper")


func apply_character_feedback(event: Dictionary) -> bool:
	if not has_character_actor(): return false
	_character_actor.call("apply_feedback",event)
	return true


func play_attack_hit(move: EnemyMoveData, hit_index: int) -> Dictionary:
	if has_character_actor(): return _character_actor.call("play_action",move,hit_index)
	return _attack_actor.play_action(move, hit_index) if has_attack_actor() else {}


func _draw() -> void:
	if has_character_actor(): return
	if _ink == null:
		return
	var unit := minf(size.x, size.y)
	var origin := (size - Vector2.ONE * unit) * 0.5
	if Palette.STYLE_ID == "taopunk":
		var portrait := TaopunkArt.portrait(enemy_id)
		if portrait != null:
			if _actor != null and _actor.visible: return
			if _attack_actor != null and _attack_actor.visible: return
			draw_texture_rect(portrait, portrait_rect(portrait, size, enemy_id), false)
			return
	if glyph == "墨" and _character != null:
		draw_texture_rect(_character, Rect2(origin, Vector2.ONE * unit), false)
		return
	draw_texture_rect(_ink, Rect2(origin, Vector2.ONE * unit), false)
	var fs := int(unit * 0.37)
	var font: Font = Ink.serif
	var width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var center := size * Vector2(0.50, 0.56)
	draw_string(font, center + Vector2(-width * 0.5, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5),
		glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.PAPER_WARM)


static func portrait_rect(texture: Texture2D, area: Vector2, id: String) -> Rect2:
	var aspect := float(texture.get_width()) / maxf(1, texture.get_height())
	if id == "ink_spirit":
		# 第一个敌人保留原半身像的比例和裁切。
		var cover := Vector2(maxf(area.x, area.y * aspect), maxf(area.y, area.x / aspect))
		return Rect2(Vector2((area.x - cover.x) * 0.5, 0), cover)
	# 新敌人形体横竖各异，完整保留头冠、翅尖和足部，统一贴住台面。
	var factor := minf(area.x / texture.get_width(), area.y / texture.get_height())
	var extent := Vector2(texture.get_size()) * factor
	return Rect2(Vector2((area.x - extent.x) * 0.5, area.y - extent.y), extent)
