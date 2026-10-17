extends Node2D
class_name InkGuardianActor
## 原图蒙皮样板：骨骼只驱动画面，不参与战斗状态或随机数。
const SOURCE_SIZE := Vector2(1402, 1122)
const EYE := Vector2(720, 437)
const RELEASE := {"attack": 0.24, "inject": 0.40}
const LENGTH := {"attack": 0.72, "inject": 1.04}
var skeleton: Skeleton2D
var mesh: Polygon2D
var player: AnimationPlayer
var bones: Dictionary = {}
var _resting := false
var defeated := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	_add_bone("Body", Vector2(700, 1040), skeleton)
	_add_bone("Head", Vector2(10, -430), bones.Body)
	_add_bone("Halo", Vector2(-55, -665), bones.Body)
	_add_bone("ClothLeft", Vector2(-330, -330), bones.Body)
	_add_bone("ClothRight", Vector2(320, -450), bones.Body)
	_build_mesh()
	_build_animations()
	player.animation_finished.connect(_on_finished)
	_set_resting(Settings.reduced_motion)
	if not _resting: player.play("idle")


func _add_bone(id: String, offset: Vector2, parent: Node) -> void:
	var bone := Bone2D.new()
	bone.name = id
	bone.position = offset
	bone.rest = bone.transform
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(80)
	parent.add_child(bone)
	bones[id] = bone


func _build_mesh() -> void:
	mesh = Polygon2D.new()
	mesh.name = "Skin"
	mesh.texture = TaopunkArt.portrait("ink_spirit")
	var vertices := PackedVector2Array()
	var polygons: Array[PackedInt32Array] = []
	var weights: Dictionary = {}
	for id in bones: weights[id] = PackedFloat32Array()
	const COLUMNS := 32
	const ROWS := 26
	for y in ROWS + 1:
		for x in COLUMNS + 1:
			var uv := Vector2(float(x) / COLUMNS, float(y) / ROWS)
			vertices.append(uv * SOURCE_SIZE)
			var w := skin_weights(uv)
			for id in weights: weights[id].append(w[id])
	for y in ROWS:
		for x in COLUMNS:
			var a := y * (COLUMNS + 1) + x
			polygons.append(PackedInt32Array([a, a + 1, a + COLUMNS + 2]))
			polygons.append(PackedInt32Array([a, a + COLUMNS + 2, a + COLUMNS + 1]))
	mesh.polygon = vertices
	mesh.uv = vertices
	mesh.polygons = polygons
	add_child(mesh)
	mesh.skeleton = mesh.get_path_to(skeleton)
	for id in bones: mesh.add_bone(skeleton.get_path_to(bones[id]), weights[id])


static func skin_weights(uv: Vector2) -> Dictionary:
	# 面具和双角为同一刚性区域；软权重只落在颈部过渡带。
	var head := (1.0 - smoothstep(0.14, 0.19, absf(uv.x - 0.505))) * smoothstep(0.08, 0.115, uv.y) * (1.0 - smoothstep(0.53, 0.59, uv.y))
	var halo := (1.0 - head) * (1.0 - smoothstep(0.48, 0.62, uv.y)) * (1.0 - smoothstep(0.72, 0.79, uv.x)) * smoothstep(0.10, 0.18, uv.x)
	var available := 1.0 - head - halo
	var left := available * (1.0 - smoothstep(0.25, 0.45, uv.x)) * smoothstep(0.46, 0.72, uv.y)
	var right := available * smoothstep(0.62, 0.83, uv.x) * smoothstep(0.20, 0.50, uv.y)
	return {"Head": head, "Halo": halo, "ClothLeft": left, "ClothRight": right, "Body": maxf(0, 1.0 - head - halo - left - right)}


func _build_animations() -> void:
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 3.6
	idle.loop_mode = Animation.LOOP_LINEAR
	_track(idle, "Body", "position", [0.0, 0.9, 1.8, 2.7, 3.6], [Vector2(700, 1040), Vector2(700, 1035), Vector2(700, 1040), Vector2(700, 1043), Vector2(700, 1040)])
	_track(idle, "Head", "rotation", [0.0, 1.8, 3.6], [0.0, -0.012, 0.0])
	_track(idle, "Halo", "rotation", [0.0, 1.8, 3.6], [0.0, 0.009, 0.0])
	_track(idle, "ClothLeft", "rotation", [0.0, 0.9, 2.7, 3.6], [0.0, 0.018, -0.012, 0.0])
	_track(idle, "ClothRight", "rotation", [0.0, 1.1, 2.9, 3.6], [0.0, -0.018, 0.012, 0.0])
	library.add_animation("idle", idle)
	var attack := Animation.new()
	attack.length = LENGTH.attack
	var times := [0.0, 0.17, 0.24, 0.30, 0.46, 0.72]
	_track(attack, "Body", "position", times, [Vector2(700, 1040), Vector2(727, 1054), Vector2(654, 1023), Vector2(650, 1027), Vector2(692, 1045), Vector2(700, 1040)])
	_track(attack, "Head", "rotation", times, [0.0, 0.075, -0.115, -0.10, 0.035, 0.0])
	_track(attack, "Halo", "rotation", times, [0.0, -0.025, 0.025, 0.04, -0.012, 0.0])
	_track(attack, "ClothLeft", "rotation", times, [0.0, -0.035, 0.075, 0.10, -0.035, 0.0])
	_track(attack, "ClothRight", "rotation", times, [0.0, 0.03, -0.03, -0.065, 0.018, 0.0])
	library.add_animation("attack", attack)
	var inject := Animation.new()
	inject.length = LENGTH.inject
	times = [0.0, 0.24, 0.40, 0.55, 0.76, 1.04]
	_track(inject, "Body", "position", times, [Vector2(700, 1040), Vector2(700, 1023), Vector2(692, 1016), Vector2(690, 1022), Vector2(700, 1035), Vector2(700, 1040)])
	_track(inject, "Head", "rotation", times, [0.0, -0.06, -0.09, -0.07, -0.025, 0.0])
	_track(inject, "Halo", "rotation", times, [0.0, 0.05, 0.085, 0.07, 0.03, 0.0])
	_track(inject, "ClothLeft", "rotation", times, [0.0, 0.035, 0.06, 0.04, 0.015, 0.0])
	_track(inject, "ClothRight", "rotation", times, [0.0, -0.035, -0.06, -0.04, -0.015, 0.0])
	library.add_animation("inject", inject)
	player.add_animation_library("", library)


func _track(clip: Animation, bone: String, property: String, times: Array, values: Array) -> void:
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, NodePath("%s:%s" % [get_path_to(bones[bone]), property]))
	clip.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for i in times.size(): clip.track_insert_key(track, times[i], values[i])


func play_action(move: EnemyMoveData) -> Dictionary:
	if Settings.reduced_motion or defeated: return {"release": 0.04, "duration": 0.04}
	var action := "inject" if move.kind == EnemyMoveData.Kind.INJECT else "attack"
	if move.kind not in [EnemyMoveData.Kind.ATTACK, EnemyMoveData.Kind.ATTACK_BLOCK, EnemyMoveData.Kind.MULTI, EnemyMoveData.Kind.INJECT]:
		return {}
	player.play(action, 0.055)
	return {"release": RELEASE[action], "duration": LENGTH[action], "action": action}


func eye_global_position() -> Vector2:
	# 跟随头骨的实际动画变换，避免特效起点与面具脱离。
	return bones.Head.global_transform * (EYE - Vector2(710, 610))


func _on_finished(_animation: StringName) -> void:
	if not defeated and not Settings.reduced_motion: player.play("idle", 0.12)


func _set_resting(value: bool) -> void:
	_resting = value
	if value:
		player.stop()
		for bone in bones.values(): bone.apply_rest()
	else:
		player.play("idle")


func _process(_delta: float) -> void:
	if _resting != (Settings.reduced_motion or defeated): _set_resting(Settings.reduced_motion or defeated)
