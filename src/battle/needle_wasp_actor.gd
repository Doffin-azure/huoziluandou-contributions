extends Node2D
class_name NeedleWaspActor
## Approved wasp artwork, articulated tail and continuous independently driven wings.
const TEXTURE_PATH := "res://assets/taopunk/enemies/needle_wasp.png"
const REST_RECT := Rect2(0, 0, 1402, 1122)
const LENGTH := {"idle":2.4,"sting_a":0.46,"sting_b":0.43,"sting_c":0.48,"charge":1.0,"heavy":1.08,"hit":0.42,"death":1.15}
const RELEASE := {"sting_a":0.16,"sting_b":0.13,"sting_c":0.15,"charge":0.72,"heavy":0.48}
const WINGS := ["WingFar","WingNear","WingHind"]
var player: AnimationPlayer
var joints: Dictionary = {}
var surfaces: Dictionary = {}
var wing_rate := 7.0
var wing_span := 1.0
var hover_weight := 1.0
var effect := 0.0
var wing_clock := 0.0
var flight: Node2D
var _texture: Texture2D
var _rest: Dictionary = {}
var _resting := false
var defeated := false:
	set(value):
		if defeated == value: return
		defeated = value
		if not is_node_ready(): return
		_reset_pose()
		if value:
			if Settings.reduced_motion: modulate.a = 0.18
			else: player.play("death")
		elif not Settings.reduced_motion: player.play("idle")


func framing() -> Dictionary:
	return {"rect":REST_RECT,"fill":0.80,"bottom":24.0}


func attack_effect() -> String:
	return "blade"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture = load(TEXTURE_PATH)
	flight = Node2D.new()
	flight.name = "Flight"
	add_child(flight)
	_build_rig()
	_build_animations()
	player.animation_finished.connect(_on_finished)
	_resting = Settings.reduced_motion
	if not _resting: player.play("idle")
	_update_flight()


func _piece(id: String, parent_id: String, pivot: Vector2, points: Array, layer: int) -> void:
	var parent: Node2D = flight if parent_id.is_empty() else joints[parent_id]
	var joint := Node2D.new()
	joint.name = id
	var parent_pivot := Vector2.ZERO if parent_id.is_empty() else Vector2(_rest[parent_id].pivot)
	joint.position = pivot - parent_pivot
	parent.add_child(joint)
	joints[id] = joint
	_rest[id] = {"position":joint.position,"pivot":pivot}
	var surface := Polygon2D.new()
	surface.name = "Illustration"
	surface.texture = _texture
	surface.z_as_relative = false
	surface.z_index = layer
	var polygon := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in points:
		var p := Vector2(point[0],point[1])
		polygon.append(p - pivot)
		uv.append(p)
	surface.polygon = polygon
	surface.uv = uv
	joint.add_child(surface)
	surfaces[id] = surface


func _build_rig() -> void:
	_piece("Body","",Vector2(505,492),[[405,444],[439,397],[493,383],[544,400],[621,433],[673,479],[636,529],[575,580],[550,610],[459,579],[414,555]],5)
	_piece("WingFar","Body",Vector2(439,399),[[428,405],[440,369],[474,270],[545,119],[668,8],[707,0],[720,6],[715,44],[668,177],[614,286],[552,360],[454,413]],0)
	_piece("WingNear","Body",Vector2(538,405),[[523,417],[540,379],[640,310],[866,173],[1088,75],[1266,32],[1366,25],[1402,37],[1395,72],[1303,145],[1177,228],[1006,305],[839,359],[672,389],[568,432]],2)
	_piece("WingHind","Body",Vector2(621,433),[[599,441],[622,420],[780,383],[976,356],[1127,358],[1213,375],[1235,394],[1225,414],[1115,445],[931,468],[759,469],[653,457]],1)
	_piece("Head","Body",Vector2(410,500),[[0,340],[407,340],[427,448],[438,499],[419,561],[395,610],[300,630],[286,570],[0,570]],6)
	_piece("LegFront","Body",Vector2(418,550),[[393,542],[429,541],[457,562],[498,597],[478,612],[443,605],[429,600],[437,636],[467,670],[525,693],[517,707],[484,693],[438,672],[409,637],[400,597]],4)
	_piece("LegMid","Body",Vector2(499,550),[[490,488],[534,535],[560,589],[549,625],[550,704],[582,775],[604,798],[582,810],[557,783],[532,734],[520,702],[517,641],[506,593],[482,535]],6)
	_piece("LegRear","Body",Vector2(597,558),[[572,538],[602,540],[650,548],[700,548],[744,610],[769,666],[782,723],[840,777],[840,792],[796,752],[756,704],[738,662],[702,599],[685,579],[628,577],[666,610],[692,623],[688,674],[674,712],[691,774],[741,837],[731,851],[696,818],[667,776],[652,734],[651,688],[658,638],[629,651],[589,620],[568,576]],4)
	_piece("Waist","Body",Vector2(637,497),[[623,471],[700,486],[777,493],[816,477],[842,500],[819,534],[747,522],[687,520],[635,533]],4)
	_piece("Abdomen","Waist",Vector2(805,510),[[774,493],[823,474],[909,476],[1008,520],[1108,604],[1163,704],[1167,778],[1129,847],[1072,827],[1060,781],[1028,739],[973,703],[918,677],[866,646],[834,602],[815,552]],4)
	_piece("Needle","Abdomen",Vector2(1117,819),[[1065,789],[1169,789],[1177,850],[1049,963],[836,1067],[583,1104],[568,1091],[747,1066],[954,966],[1056,869]],4)


func _track(clip: Animation, node: Node, property: String, times: Array, values: Array) -> void:
	var index := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(index,NodePath("%s:%s" % [get_path_to(node),property]))
	clip.track_set_interpolation_type(index,Animation.INTERPOLATION_LINEAR)
	for i in times.size(): clip.track_insert_key(index,times[i],values[i])


func _rotation(clip: Animation, id: String, times: Array, values: Array) -> void:
	_track(clip,joints[id],"rotation",times,values)


func _build_animations() -> void:
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = LENGTH.idle
	idle.loop_mode = Animation.LOOP_LINEAR
	_rotation(idle,"Head",[0.0,1.2,2.4],[0.0,0.018,0.0])
	library.add_animation("idle",idle)
	for index in 3:
		var id: String = ["sting_a","sting_b","sting_c"][index]
		var clip := Animation.new()
		clip.length = LENGTH[id]
		var release: float = RELEASE[id]
		var t := [0.0,release * 0.65,release,release + 0.06,clip.length]
		var offset: float = [-12.0,12.0,-4.0][index]
		_track(clip,joints.Body,"position",t,[Vector2(505,492),Vector2(535,485),Vector2(415,480 + offset),Vector2(420,485 + offset),Vector2(505,492)])
		_rotation(clip,"Body",t,[0.0,-0.03,0.06,0.04,0.0])
		_rotation(clip,"Waist",t,[0.0,-0.10,0.25,0.24,0.0])
		_rotation(clip,"Abdomen",t,[0.0,-0.18,0.40,0.35,0.0])
		_rotation(clip,"Needle",t,[0.0,-0.12,0.30,0.22,0.0])
		_track(clip,self,"wing_rate",t,[7.0,8.5,10.0,9.0,7.0])
		_track(clip,self,"effect",t,[0.0,0.0,1.0,0.5,0.0])
		library.add_animation(id,clip)
	var charge := Animation.new()
	charge.length = LENGTH.charge
	var t := [0.0,0.25,0.70,1.0]
	_track(charge,joints.Body,"position",t,[Vector2(505,492),Vector2(545,470),Vector2(550,455),Vector2(505,492)])
	_rotation(charge,"Abdomen",t,[0.0,0.15,0.30,0.0])
	_rotation(charge,"Needle",t,[0.0,-0.10,-0.18,0.0])
	_track(charge,self,"wing_rate",t,[7.0,9.0,10.0,7.0])
	library.add_animation("charge",charge)
	var heavy := Animation.new()
	heavy.length = LENGTH.heavy
	t = [0.0,0.23,0.43,0.48,0.58,0.76,1.08]
	_track(heavy,joints.Body,"position",t,[Vector2(505,492),Vector2(555,475),Vector2(580,465),Vector2(355,485),Vector2(350,495),Vector2(445,500),Vector2(505,492)])
	_rotation(heavy,"Body",t,[0.0,-0.04,-0.06,0.15,0.12,-0.025,0.0])
	_rotation(heavy,"Waist",t,[0.0,-0.08,-0.14,0.38,0.35,0.12,0.0])
	_rotation(heavy,"Abdomen",t,[0.0,-0.15,-0.24,0.63,0.57,0.16,0.0])
	_rotation(heavy,"Needle",t,[0.0,-0.14,-0.20,0.38,0.29,0.08,0.0])
	_track(heavy,self,"wing_rate",t,[7.0,8.0,11.0,12.0,11.0,8.0,7.0])
	_track(heavy,self,"effect",t,[0.0,0.0,0.0,1.0,0.7,0.0,0.0])
	library.add_animation("heavy",heavy)
	var hit := Animation.new()
	hit.length = LENGTH.hit
	t = [0.0,0.055,0.13,0.27,0.42]
	_track(hit,joints.Body,"position",t,[Vector2(505,492),Vector2(555,480),Vector2(540,495),Vector2(498,495),Vector2(505,492)])
	_rotation(hit,"Body",t,[0.0,-0.12,0.05,0.015,0.0])
	_rotation(hit,"Abdomen",t,[0.0,0.15,-0.09,0.02,0.0])
	_rotation(hit,"Needle",t,[0.0,0.20,-0.13,0.035,0.0])
	library.add_animation("hit",hit)
	var death := Animation.new()
	death.length = LENGTH.death
	t = [0.0,0.15,0.40,0.75,1.15]
	_track(death,joints.Body,"position",t,[Vector2(505,492),Vector2(510,510),Vector2(535,600),Vector2(565,760),Vector2(580,850)])
	_rotation(death,"Body",t,[0.0,0.10,0.35,0.80,1.10])
	_rotation(death,"Abdomen",t,[0.0,0.15,0.35,0.50,0.65])
	_rotation(death,"Needle",t,[0.0,-0.15,-0.25,-0.40,-0.50])
	_track(death,self,"wing_rate",t,[7.0,5.0,2.0,0.0,0.0])
	_track(death,self,"wing_span",t,[1.0,0.8,0.35,0.05,0.02])
	_track(death,self,"hover_weight",t,[1.0,0.5,0.0,0.0,0.0])
	_track(death,self,"modulate:a",t,[1.0,1.0,1.0,0.5,0.0])
	library.add_animation("death",death)
	player.add_animation_library("",library)


func _reset_pose() -> void:
	player.stop()
	effect = 0.0
	wing_rate = 7.0
	wing_span = 1.0
	hover_weight = 1.0
	modulate = Color.WHITE
	for id in joints:
		joints[id].position = _rest[id].position
		joints[id].rotation = 0.0
		joints[id].scale = Vector2.ONE


func _update_flight() -> void:
	if Settings.reduced_motion:
		flight.position = Vector2.ZERO
		for id in WINGS:
			joints[id].rotation = 0.0
			joints[id].scale = Vector2.ONE
		return
	flight.position = Vector2(sin(wing_clock * 0.55) * 3.0,sin(wing_clock * 0.85) * 8.0) * hover_weight
	for i in WINGS.size():
		var phase := wing_clock * TAU + float(i) * 0.65
		var flap := sin(phase)
		var wing: Node2D = joints[WINGS[i]]
		wing.rotation = flap * 0.085 * wing_span
		wing.scale = Vector2(1.0,(0.22 + (flap * 0.5 + 0.5) * 0.88) * wing_span)
	joints.LegFront.rotation = sin(wing_clock * 0.45) * 0.035
	joints.LegMid.rotation = sin(wing_clock * 0.45 + 0.7) * 0.045
	joints.LegRear.rotation = sin(wing_clock * 0.45 + 1.4) * 0.04


func play_action(move: EnemyMoveData, hit_index := 0) -> Dictionary:
	var clip := ""
	if move.kind == EnemyMoveData.Kind.MULTI:
		clip = ["sting_a","sting_b","sting_c"][hit_index % 3]
	elif move.kind in [EnemyMoveData.Kind.ATTACK,EnemyMoveData.Kind.ATTACK_BLOCK]: clip = "heavy"
	elif move.kind == EnemyMoveData.Kind.SPECIAL: clip = "charge"
	if clip.is_empty(): return {}
	if Settings.reduced_motion or defeated: return {"release":0.04,"duration":0.04,"action":clip}
	_reset_pose()
	player.play(clip)
	return {"release":RELEASE[clip],"duration":LENGTH[clip],"action":clip}


func apply_feedback(event: Dictionary) -> void:
	if event.has("hp") and int(event.hp) <= 0:
		defeated = true
	elif not defeated and (int(event.get("hp_loss",0)) > 0 or int(event.get("blocked",0)) > 0) and not Settings.reduced_motion:
		_reset_pose()
		player.play("hit")


func action_global_position() -> Vector2:
	return joints.Needle.to_global(Vector2(583,1096) - Vector2(1117,819))


func sample(clip: String, seconds: float, flap_cycles: float) -> void:
	_reset_pose()
	wing_clock = flap_cycles
	player.play(clip)
	player.seek(clampf(seconds,0.0,LENGTH[clip]),true)
	_update_flight()
	queue_redraw()


func animation_length(clip: String) -> float:
	return LENGTH[clip]


func capture_sample(clip: String, seconds: float, delta: float) -> void:
	sample(clip,seconds,wing_clock + delta * wing_rate)


func _process(delta: float) -> void:
	if _resting != Settings.reduced_motion:
		_resting = Settings.reduced_motion
		_reset_pose()
		if defeated: modulate.a = 0.18
		elif not _resting: player.play("idle")
		_update_flight()
	if not _resting:
		wing_clock += delta * wing_rate
		_update_flight()
	queue_redraw()


func _on_finished(clip: StringName) -> void:
	if clip == "death" or defeated or Settings.reduced_motion: return
	_reset_pose()
	player.play("idle")


func _draw() -> void:
	if effect <= 0.0 or Settings.reduced_motion: return
	var tip := to_local(action_global_position())
	var thickness := 6.0 if player.current_animation == "heavy" else 3.5
	draw_polyline(PackedVector2Array([tip + Vector2(110,28),tip,tip + Vector2(-100,-12)]),Color(0.80,0.65,0.35,effect * 0.65),thickness,true)
