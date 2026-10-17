extends Node2D
class_name PaperShellActor
## Rigid paper pieces share the approved texture. Only presentation, never combat RNG.
const TEXTURE_PATH := "res://assets/taopunk/enemies/paper_shell_soldier.png"
const REST_RECT := Rect2(223, 61, 578, 1380)
const LENGTH := {"idle": 3.6, "attack": 1.06, "guard": 1.0, "hit": 0.48, "death": 1.2}
const RELEASE := {"attack": 0.40, "guard": 0.34}
var player: AnimationPlayer
var joints: Dictionary = {}
var surfaces: Dictionary = {}
var _rest: Dictionary = {}
var _texture: Texture2D
var _resting := false
var left_step := Vector2.ZERO
var right_step := Vector2.ZERO
var effect := 0.0
var grounded := true
var defeated := false:
	set(value):
		if defeated == value: return
		defeated = value
		if is_node_ready():
			if value:
				if Settings.reduced_motion:
					_reset_pose()
					modulate.a = 0.18
				else: player.play("death")
			else:
				_reset_pose()
				if not Settings.reduced_motion: player.play("idle")


func framing() -> Dictionary:
	return {"rect":REST_RECT,"fill":0.94,"bottom":0.0}


func attack_effect() -> String:
	return "paper"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture = load(TEXTURE_PATH)
	_build_rig()
	_build_animations()
	player.animation_finished.connect(_on_finished)
	_resting = Settings.reduced_motion
	if not _resting: player.play("idle")
	_solve_feet()


func _piece(id: String, parent_id: String, pivot: Vector2, points: Array, layer: int) -> void:
	var parent: Node2D = self if parent_id.is_empty() else joints[parent_id]
	var joint := Node2D.new()
	joint.name = id
	var parent_pivot := Vector2.ZERO if parent_id.is_empty() else Vector2(_rest[parent_id].pivot)
	joint.position = pivot - parent_pivot
	parent.add_child(joint)
	joints[id] = joint
	_rest[id] = {"pivot": pivot, "position": joint.position}
	var surface := Polygon2D.new()
	surface.name = "Paper"
	surface.texture = _texture
	surface.z_as_relative = false
	surface.z_index = layer
	var polygon := PackedVector2Array()
	var uv := PackedVector2Array()
	for p in points:
		var coordinate := Vector2(p[0], p[1])
		polygon.append(coordinate - pivot)
		uv.append(coordinate)
	surface.polygon = polygon
	surface.uv = uv
	joint.add_child(surface)
	surfaces[id] = surface


func _build_rig() -> void:
	_piece("Body", "", Vector2(505, 835), [[269,510],[362,451],[509,535],[611,544],[681,588],[628,759],[554,848],[505,882],[375,815],[350,648]], 3)
	_piece("Head", "Body", Vector2(510, 535), [[307,298],[592,61],[761,305],[611,544],[509,535],[362,451],[372,338]], 4)
	_piece("Pelvis", "Body", Vector2(505, 882), [[375,815],[505,882],[554,848],[637,947],[641,1010],[505,1075],[362,943]], 3)
	_piece("UpperL", "Body", Vector2(290, 550), [[269,510],[350,648],[334,779],[223,779]], 4)
	_piece("ForeL", "UpperL", Vector2(277, 789), [[223,779],[334,779],[320,923],[254,958]], 4)
	_piece("HandL", "ForeL", Vector2(287, 940), [[254,958],[320,923],[363,959],[304,1017]], 4)
	_piece("UpperR", "Body", Vector2(662, 608), [[681,588],[720,700],[727,781],[629,759]], 2)
	_piece("ForeR", "UpperR", Vector2(678, 772), [[629,759],[727,781],[758,947],[705,921],[672,862]], 2)
	_piece("HandR", "ForeR", Vector2(720, 936), [[705,921],[758,947],[741,1012],[710,995]], 2)
	_piece("ThighL", "Pelvis", Vector2(416, 998), [[362,943],[505,1075],[428,1160],[337,1143]], 2)
	_piece("ShinL", "ThighL", Vector2(380, 1155), [[337,1143],[428,1160],[416,1335],[364,1370],[342,1320]], 2)
	_piece("FootL", "ShinL", Vector2(375, 1340), [[342,1320],[416,1335],[464,1424],[230,1438],[312,1370]], 2)
	_piece("ThighR", "Pelvis", Vector2(599, 1030), [[505,1075],[641,1010],[719,1130],[618,1180],[565,1115]], 1)
	_piece("ShinR", "ThighR", Vector2(668, 1150), [[618,1180],[719,1130],[686,1320],[630,1350],[610,1285]], 1)
	_piece("FootR", "ShinR", Vector2(651, 1320), [[610,1285],[686,1320],[800,1425],[538,1425],[610,1360]], 1)


func _track(clip: Animation, target: Node, property: String, times: Array, values: Array, discrete := false) -> void:
	var index := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(index, NodePath("%s:%s" % [get_path_to(target), property]))
	if discrete: clip.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE)
	else: clip.track_set_interpolation_type(index, Animation.INTERPOLATION_LINEAR)
	for i in times.size(): clip.track_insert_key(index, times[i], values[i])


func _rotation(clip: Animation, id: String, times: Array, values: Array) -> void:
	_track(clip, joints[id], "rotation", times, values)


func _build_animations() -> void:
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = LENGTH.idle
	idle.loop_mode = Animation.LOOP_LINEAR
	_track(idle, joints.Body, "position", [0.0,1.0,2.5,3.6], [Vector2(505,835),Vector2(505,830),Vector2(505,838),Vector2(505,835)])
	_rotation(idle, "Head", [0.0,1.4,2.7,3.6], [0.0,0.025,-0.012,0.0])
	_rotation(idle, "ForeL", [0.0,1.5,3.6], [0.0,0.018,0.0])
	_rotation(idle, "ForeR", [0.0,2.0,3.6], [0.0,-0.022,0.0])
	library.add_animation("idle", idle)
	var attack := Animation.new()
	attack.length = LENGTH.attack
	var t := [0.0,0.20,0.34,0.40,0.48,0.56,0.73,1.06]
	_track(attack, joints.Body, "position", t, [Vector2(505,835),Vector2(545,860),Vector2(555,890),Vector2(410,830),Vector2(390,835),Vector2(400,850),Vector2(480,845),Vector2(505,835)])
	_rotation(attack, "Body", t, [0.0,0.09,0.12,-0.12,-0.16,-0.08,0.025,0.0])
	_rotation(attack, "Head", t, [0.0,-0.06,0.02,0.12,0.13,0.08,-0.02,0.0])
	_rotation(attack, "UpperL", t, [0.0,-0.65,-1.0,1.20,1.33,1.15,0.40,0.0])
	_rotation(attack, "ForeL", t, [0.0,-0.85,-1.4,0.1,0.0,0.2,-0.35,0.0])
	_rotation(attack, "HandL", t, [0.0,0.20,0.40,-0.9,-0.7,-0.5,0.1,0.0])
	_rotation(attack, "UpperR", t, [0.0,0.25,0.50,-0.35,-0.65,-0.50,-0.1,0.0])
	_track(attack, self, "left_step", t, [Vector2.ZERO,Vector2(-20,-20),Vector2(-80,-70),Vector2(-140,0),Vector2(-140,0),Vector2(-120,0),Vector2(-45,-15),Vector2.ZERO])
	_track(attack, self, "effect", [0.0,0.39,0.40,0.48,0.59,1.06], [0.0,0.0,1.0,0.7,0.0,0.0])
	library.add_animation("attack", attack)
	var guard := Animation.new()
	guard.length = LENGTH.guard
	t = [0.0,0.16,0.34,0.46,0.68,1.0]
	_track(guard, joints.Body, "position", t, [Vector2(505,835),Vector2(510,860),Vector2(495,855),Vector2(495,855),Vector2(500,845),Vector2(505,835)])
	_rotation(guard, "UpperL", t, [0.0,-0.20,-0.40,-0.40,-0.25,0.0])
	_rotation(guard, "ForeL", t, [0.0,-0.75,-1.80,-1.80,-1.0,0.0])
	_rotation(guard, "UpperR", t, [0.0,0.20,0.45,0.45,0.25,0.0])
	_rotation(guard, "ForeR", t, [0.0,0.75,1.75,1.75,1.0,0.0])
	_track(guard, surfaces.ForeR, "z_index", [0.0,0.12,0.85,1.0], [2,5,5,2], true)
	_track(guard, surfaces.HandR, "z_index", [0.0,0.12,0.85,1.0], [2,5,5,2], true)
	_rotation(guard, "Head", t, [0.0,0.03,0.07,0.07,0.03,0.0])
	_track(guard, self, "effect", t, [0.0,0.0,0.8,0.5,0.0,0.0])
	library.add_animation("guard", guard)
	var hit := Animation.new()
	hit.length = LENGTH.hit
	t = [0.0,0.06,0.12,0.24,0.48]
	_track(hit, joints.Body, "position", t, [Vector2(505,835),Vector2(541,839),Vector2(533,840),Vector2(497,833),Vector2(505,835)])
	_rotation(hit, "Body", t, [0.0,0.10,0.07,-0.025,0.0])
	_rotation(hit, "Head", t, [0.0,-0.10,-0.18,0.04,0.0])
	_rotation(hit, "ForeL", t, [0.0,-0.2,-0.13,0.03,0.0])
	_rotation(hit, "ForeR", t, [0.0,0.16,0.23,-0.05,0.0])
	library.add_animation("hit", hit)
	var death := Animation.new()
	death.length = LENGTH.death
	t = [0.0,0.20,0.45,0.75,1.2]
	_track(death, self, "grounded", [0.0], [false], true)
	_track(death, joints.Body, "position", t, [Vector2(505,835),Vector2(510,860),Vector2(490,980),Vector2(480,1100),Vector2(480,1190)])
	_rotation(death, "Body", t, [0.0,-0.06,-0.15,-0.23,-0.26])
	_rotation(death, "Head", t, [0.0,0.10,0.65,1.2,1.6])
	_rotation(death, "UpperL", t, [0.0,0.45,1.3,1.8,2.0])
	_rotation(death, "ForeL", t, [0.0,0.30,1.2,1.8,1.9])
	_rotation(death, "UpperR", t, [0.0,-0.30,-1.2,-1.7,-1.8])
	_rotation(death, "ForeR", t, [0.0,-0.30,-1.2,-1.6,-1.8])
	_rotation(death, "ThighL", t, [0.0,0.20,0.65,1.0,1.2])
	_rotation(death, "ShinL", t, [0.0,0.10,0.60,1.3,1.5])
	_rotation(death, "ThighR", t, [0.0,-0.20,-0.60,-1.0,-1.2])
	_rotation(death, "ShinR", t, [0.0,-0.10,-0.60,-1.3,-1.5])
	_track(death, joints.Head, "scale:x", t, [1.0,1.0,0.65,0.13,0.04])
	_track(death, joints.Body, "scale:x", t, [1.0,1.0,0.85,0.25,0.06])
	_track(death, self, "modulate:a", t, [1.0,1.0,1.0,0.80,0.0])
	library.add_animation("death", death)
	player.add_animation_library("", library)


func _reset_pose() -> void:
	player.stop()
	left_step = Vector2.ZERO
	right_step = Vector2.ZERO
	effect = 0.0
	grounded = true
	modulate = Color.WHITE
	for id in joints:
		joints[id].position = _rest[id].position
		joints[id].rotation = 0.0
		joints[id].scale = Vector2.ONE
		surfaces[id].scale = Vector2.ONE
		surfaces.ForeR.z_index = 2
		surfaces.HandR.z_index = 2
	_solve_feet()


func play_action(move: EnemyMoveData, _hit_index := 0) -> Dictionary:
	var clip := "guard" if move.kind == EnemyMoveData.Kind.BLOCK else "attack"
	if move.kind not in [EnemyMoveData.Kind.ATTACK, EnemyMoveData.Kind.ATTACK_BLOCK, EnemyMoveData.Kind.MULTI, EnemyMoveData.Kind.BLOCK]: return {}
	if Settings.reduced_motion or defeated: return {"release": 0.04, "duration": 0.04, "action": clip}
	_reset_pose()
	player.play(clip)
	return {"release": RELEASE[clip], "duration": LENGTH[clip], "action": clip}


func apply_feedback(event: Dictionary) -> void:
	if event.has("hp") and int(event.hp) <= 0:
		defeated = true
	elif not defeated and (int(event.get("hp_loss", 0)) > 0 or int(event.get("blocked", 0)) > 0):
		if not Settings.reduced_motion:
			_reset_pose()
			player.play("hit")


func action_global_position() -> Vector2:
	return joints.HandL.to_global(Vector2(-30, 30))


func sample(clip: String, seconds: float) -> void:
	# Deterministic render capture; does not advance rules or consume random values.
	_reset_pose()
	player.play(clip)
	player.seek(clampf(seconds, 0.0, LENGTH[clip]), true)
	_solve_feet()
	queue_redraw()


func _solve_leg(side: String, target: Vector2, bend: float) -> void:
	var thigh: Node2D = joints["Thigh" + side]
	var shin: Node2D = joints["Shin" + side]
	var foot: Node2D = joints["Foot" + side]
	var parent := thigh.get_parent() as Node2D
	var goal: Vector2 = parent.to_local(to_global(target)) - thigh.position
	var upper: Vector2 = _rest["Shin" + side].position
	var lower: Vector2 = _rest["Foot" + side].position
	var a := upper.length()
	var b := lower.length()
	var distance := clampf(goal.length(), absf(a - b) + 0.1, a + b - 0.1)
	var angle: float = goal.angle() + bend * acos(clampf((a * a + distance * distance - b * b) / (2.0 * a * distance), -1.0, 1.0))
	thigh.rotation = angle - upper.angle()
	var knee := upper.rotated(thigh.rotation)
	shin.rotation = (goal - knee).angle() - thigh.rotation - lower.angle()
	foot.rotation = global_rotation - shin.global_rotation


func _solve_feet() -> void:
	if not grounded: return
	# Preserve rigid lengths: lower the hips if a planted ankle is out of reach.
	var drop := 0.0
	for side in ["L", "R"]:
		var hip := to_local(joints["Thigh" + side].global_position)
		var target := Vector2(375,1340) + left_step if side == "L" else Vector2(651,1320) + right_step
		var upper: Vector2 = _rest["Shin" + side].position
		var lower: Vector2 = _rest["Foot" + side].position
		var reach := upper.length() + lower.length() - 0.2
		var horizontal := target.x - hip.x
		var available := sqrt(maxf(1.0, reach * reach - horizontal * horizontal))
		drop = maxf(drop, target.y - hip.y - available)
	if drop > 0.0: joints.Body.position.y += drop
	_solve_leg("L", Vector2(375,1340) + left_step, 1.0)
	_solve_leg("R", Vector2(651,1320) + right_step, -1.0)


func _process(_delta: float) -> void:
	if _resting != Settings.reduced_motion:
		_resting = Settings.reduced_motion
		_reset_pose()
		if defeated: modulate.a = 0.18
		elif not _resting: player.play("idle")
	_solve_feet()
	queue_redraw()


func _on_finished(clip: StringName) -> void:
	if clip == "death" or defeated or Settings.reduced_motion: return
	_reset_pose()
	player.play("idle")


func _draw() -> void:
	if effect <= 0.0 or Settings.reduced_motion: return
	if player.current_animation == "attack":
		var tip := to_local(action_global_position())
		draw_polyline(PackedVector2Array([tip + Vector2(100,-55),tip + Vector2(-120,-15),tip + Vector2(-175,10)]), Color(0.91,0.84,0.65,effect * 0.65), 5.0, true)
	elif player.current_animation == "guard":
		draw_arc(Vector2(500,730), 240.0, -2.5, -0.65, 24, Color(0.71,0.53,0.22,effect * 0.65), 5.0, true)
