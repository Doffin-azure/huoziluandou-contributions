extends Node2D
class_name TiltingInkstoneActor
## Original v01 painting, rigid stone motion, planted viscous feet and a separate liquid surface.
const TEXTURE_PATH := "res://assets/taopunk/enemies/tilting_inkstone.png"
const REST_RECT := Rect2(0,0,1375,1144)
const PIVOT := Vector2(688,875)
const LENGTH := {"idle":3.6,"tilt":1.20,"rotate":1.10,"attack":1.05,"hit":0.48,"death":1.20}
const RELEASE := {"tilt":0.54,"rotate":0.52,"attack":0.40}
const ROWS := [0,100,200,300,400,430,460,490,520,550,600,650,700,750,800,830,860,880,900,920,940,960,980,1000,1010,1020,1030,1040,1055,1070,1085,1100,1120,1144]
var player: AnimationPlayer
var body: Node2D
var surface: Polygon2D
var liquid: ShaderMaterial
var rest_vertices := PackedVector2Array()
var liquid_time := 0.0
var liquid_angle := 0.0
var liquid_gain := 1.0
var ground_weight := 1.0
var effect := 0.0
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
	return {"rect":REST_RECT,"fill":0.80,"bottom":0.0}


func attack_effect() -> String:
	return "press"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	body = Node2D.new()
	body.name = "StonePose"
	body.position = PIVOT
	add_child(body)
	_build_surface()
	_build_animations()
	player.animation_finished.connect(_on_finished)
	_resting = Settings.reduced_motion
	if not _resting: player.play("idle")
	_sync_surface()


func _build_surface() -> void:
	surface = Polygon2D.new()
	surface.name = "InkstonePainting"
	surface.texture = load(TEXTURE_PATH)
	add_child(surface)
	for y in ROWS:
		for x in 26: rest_vertices.append(Vector2(float(x) * 55.0,float(y)))
	surface.polygon = rest_vertices
	surface.uv = rest_vertices
	var triangles: Array[PackedInt32Array] = []
	for y in ROWS.size() - 1:
		for x in 25:
			var a := y * 26 + x
			triangles.append(PackedInt32Array([a,a + 1,a + 27]))
			triangles.append(PackedInt32Array([a,a + 27,a + 26]))
	surface.polygons = triangles
	liquid = ShaderMaterial.new()
	liquid.shader = preload("res://src/shaders/inkstone_liquid.gdshader")
	surface.material = liquid


func _track(clip: Animation, node: Node, property: String, times: Array, values: Array, smooth := false) -> void:
	var index := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(index,NodePath("%s:%s" % [get_path_to(node),property]))
	clip.track_set_interpolation_type(index,Animation.INTERPOLATION_CUBIC if smooth else Animation.INTERPOLATION_LINEAR)
	for i in times.size(): clip.track_insert_key(index,times[i],values[i])


func _build_animations() -> void:
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = LENGTH.idle
	idle.loop_mode = Animation.LOOP_LINEAR
	_track(idle,body,"rotation",[0.0,0.9,1.8,2.7,3.6],[0.0,0.075,0.0,-0.075,0.0],true)
	_track(idle,body,"position",[0.0,0.9,1.8,2.7,3.6],[PIVOT,PIVOT + Vector2(6,3),PIVOT,PIVOT + Vector2(-6,3),PIVOT],true)
	library.add_animation("idle",idle)
	var tilt := Animation.new()
	tilt.length = LENGTH.tilt
	var t := [0.0,0.26,0.54,0.72,0.94,1.20]
	_track(tilt,body,"rotation",t,[0.0,0.07,-0.20,-0.19,0.035,0.0])
	_track(tilt,body,"position",t,[PIVOT,PIVOT + Vector2(15,-6),PIVOT + Vector2(-28,15),PIVOT + Vector2(-25,15),PIVOT + Vector2(6,-2),PIVOT])
	_track(tilt,self,"liquid_gain",t,[1.0,1.2,2.0,1.8,1.2,1.0])
	_track(tilt,self,"effect",t,[0.0,0.0,1.0,0.6,0.0,0.0])
	library.add_animation("tilt",tilt)
	var rotate := Animation.new()
	rotate.length = LENGTH.rotate
	t = [0.0,0.22,0.45,0.52,0.68,0.88,1.10]
	_track(rotate,body,"rotation",t,[0.0,-0.08,-0.15,0.16,0.13,-0.03,0.0])
	_track(rotate,body,"position",t,[PIVOT,PIVOT,PIVOT,PIVOT,PIVOT,PIVOT,PIVOT])
	_track(rotate,body,"scale",t,[Vector2.ONE,Vector2(0.97,1),Vector2(0.83,1),Vector2(0.94,1),Vector2(1.02,1),Vector2.ONE,Vector2.ONE])
	_track(rotate,self,"liquid_gain",t,[1.0,1.0,1.5,2.2,1.8,1.1,1.0])
	_track(rotate,self,"effect",t,[0.0,0.0,0.0,1.0,0.6,0.0,0.0])
	library.add_animation("rotate",rotate)
	var attack := Animation.new()
	attack.length = LENGTH.attack
	t = [0.0,0.22,0.34,0.40,0.50,0.74,1.05]
	_track(attack,body,"rotation",t,[0.0,0.10,0.12,-0.24,-0.20,0.04,0.0])
	_track(attack,body,"position",t,[PIVOT,PIVOT + Vector2(30,0),PIVOT + Vector2(36,-10),PIVOT + Vector2(-80,15),PIVOT + Vector2(-76,18),PIVOT + Vector2(10,0),PIVOT])
	_track(attack,self,"liquid_gain",t,[1.0,1.0,1.1,2.8,2.5,1.6,1.0])
	_track(attack,self,"effect",t,[0.0,0.0,0.0,1.0,0.5,0.0,0.0])
	library.add_animation("attack",attack)
	var hit := Animation.new()
	hit.length = LENGTH.hit
	t = [0.0,0.06,0.17,0.32,0.48]
	_track(hit,body,"rotation",t,[0.0,0.13,-0.055,0.02,0.0])
	_track(hit,body,"position",t,[PIVOT,PIVOT + Vector2(35,5),PIVOT + Vector2(10,0),PIVOT + Vector2(-5,0),PIVOT])
	_track(hit,self,"liquid_gain",t,[1.0,3.0,2.4,1.6,1.0])
	library.add_animation("hit",hit)
	var death := Animation.new()
	death.length = LENGTH.death
	t = [0.0,0.18,0.48,0.78,1.20]
	_track(death,body,"rotation",t,[0.0,-0.10,0.26,0.42,0.44])
	_track(death,body,"position",t,[PIVOT,PIVOT + Vector2(0,20),PIVOT + Vector2(15,110),PIVOT + Vector2(25,160),PIVOT + Vector2(25,160)])
	_track(death,self,"liquid_gain",t,[1.0,3.0,2.0,0.5,0.0])
	_track(death,self,"ground_weight",t,[1.0,0.3,0.0,0.0,0.0])
	_track(death,self,"modulate:a",t,[1.0,1.0,0.9,0.5,0.0])
	library.add_animation("death",death)
	player.add_animation_library("",library)


func _reset_pose() -> void:
	player.stop()
	body.position = PIVOT
	body.rotation = 0.0
	body.scale = Vector2.ONE
	liquid_gain = 1.0
	ground_weight = 1.0
	effect = 0.0
	modulate = Color.WHITE


func transformed_point(point: Vector2) -> Vector2:
	var rigid := body.transform * (point - PIVOT)
	# The stone stays rigid; only the viscous legs below its rim bend to planted soles.
	var sole := lerpf(1008.0,1080.0,smoothstep(600.0,1000.0,point.x))
	var weight := 1.0 - smoothstep(900.0,sole - 8.0,point.y)
	return point.lerp(rigid,lerpf(1.0,weight,ground_weight))


func _sync_surface() -> void:
	if ground_weight > 0.99:
		# A planted viscous leg may compress, but the heavy slab cannot pass through its sole.
		var lift := 0.0
		for x in 26:
			var point := Vector2(float(x) * 55.0,900.0)
			var top: Vector2 = body.transform * (point - PIVOT)
			var sole := lerpf(1008.0,1080.0,smoothstep(600.0,1000.0,point.x))
			lift = maxf(lift,top.y - (sole - 60.0))
		body.position.y -= lift
	var vertices := PackedVector2Array()
	for point in rest_vertices: vertices.append(transformed_point(point))
	surface.polygon = vertices
	if Settings.reduced_motion:
		liquid_angle = 0.0
		liquid.set_shader_parameter("liquid_slope",0.0)
		liquid.set_shader_parameter("ripple_size",0.0)
	else:
		var phase := liquid_time * TAU / LENGTH.idle
		if player.current_animation == "idle": phase = player.current_animation_position * TAU / LENGTH.idle
		liquid_angle = -body.rotation + sin(phase - 0.8) * 0.055 * liquid_gain
		liquid.set_shader_parameter("liquid_slope",tan(clampf(liquid_angle,-0.38,0.38)))
		liquid.set_shader_parameter("ripple_phase",phase * 2.0)
		liquid.set_shader_parameter("ripple_size",4.5 * liquid_gain)
	queue_redraw()


func play_action(move: EnemyMoveData, _hit_index := 0) -> Dictionary:
	var clip := ""
	if move.kind in [EnemyMoveData.Kind.ATTACK,EnemyMoveData.Kind.ATTACK_BLOCK,EnemyMoveData.Kind.MULTI]: clip = "attack"
	elif move.kind == EnemyMoveData.Kind.SPECIAL:
		var tag := String(move.get_meta("visual_action",""))
		if tag in ["tilt","rotate"]: clip = tag
	if clip.is_empty(): return {}
	if Settings.reduced_motion or defeated: return {"release":0.04,"duration":0.04,"action":clip}
	_reset_pose()
	player.play(clip)
	return {"release":RELEASE[clip],"duration":LENGTH[clip],"action":clip}


func apply_feedback(event: Dictionary) -> void:
	if event.has("hp") and int(event.hp) <= 0: defeated = true
	elif not defeated and (int(event.get("hp_loss",0)) > 0 or int(event.get("blocked",0)) > 0) and not Settings.reduced_motion:
		_reset_pose()
		player.play("hit")


func action_global_position() -> Vector2:
	return to_global(transformed_point(Vector2(265,600)))


func sample(clip: String, seconds: float, clock_seconds: float) -> void:
	_reset_pose()
	liquid_time = clock_seconds
	player.play(clip)
	player.seek(clampf(seconds,0.0,LENGTH[clip]),true)
	_sync_surface()


func animation_length(clip: String) -> float:
	return LENGTH[clip]


func capture_sample(clip: String, seconds: float, delta: float) -> void:
	sample(clip,seconds,liquid_time + delta)


func _process(delta: float) -> void:
	if _resting != Settings.reduced_motion:
		_resting = Settings.reduced_motion
		_reset_pose()
		if defeated: modulate.a = 0.18
		elif not _resting: player.play("idle")
	if not _resting: liquid_time += delta
	_sync_surface()


func _on_finished(clip: StringName) -> void:
	if clip == "death" or defeated or Settings.reduced_motion: return
	_reset_pose()
	player.play("idle")


func _draw() -> void:
	if effect <= 0.0 or Settings.reduced_motion: return
	var ink := Color(0.10,0.15,0.16,effect * 0.65)
	if player.current_animation == "rotate":
		draw_arc(Vector2(690,970),240.0,-2.8,-0.2,28,ink,5.0,true)
	elif player.current_animation == "tilt":
		draw_line(Vector2(470,990),Vector2(220,990),ink,5.0,true)
	else:
		var contact := to_local(action_global_position())
		draw_line(contact + Vector2(60,-55),contact + Vector2(-70,30),ink,8.0,true)
