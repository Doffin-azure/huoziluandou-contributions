extends Node2D
class_name FoldPageMothActor
## Approved left-facing v02, articulated book leaves and an independently folded page corner.
const TEXTURE_PATH := "res://assets/taopunk/enemies/fold_page_moth.png"
const REST_RECT := Rect2(0,0,1402,1122)
const BODY_PIVOT := Vector2(550,730)
const LENGTH := {"idle":3.0,"mark":1.10,"fold_attack":1.12,"attack":0.94,"hit":0.48,"death":1.12}
const RELEASE := {"mark":0.55,"fold_attack":0.50,"attack":0.34}
const CORNER_A := Vector2(1350,450)
const CORNER_B := Vector2(1020,760)
var player: AnimationPlayer
var body: Node2D
var joints: Dictionary = {}
var surfaces: Dictionary = {}
var wing_vertices: Dictionary = {}
var near_close := 0.0
var far_close := 0.0
var corner_fold := 0.0
var effect := 0.0
var clock_seconds := 0.0
var _texture: Texture2D
var _rest: Dictionary = {}
var _resting := false
var _accents: Node2D
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
	return "paper"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture = load(TEXTURE_PATH)
	body = Node2D.new()
	body.name = "BodyPose"
	body.position = BODY_PIVOT
	add_child(body)
	_build_rig()
	_build_animations()
	_accents = Node2D.new()
	_accents.name = "PaperAccents"
	_accents.z_index = 6
	add_child(_accents)
	_accents.draw.connect(_draw_accents)
	player.animation_finished.connect(_on_finished)
	_resting = Settings.reduced_motion
	if not _resting: player.play("idle")
	_sync_pose()


func _piece(id: String, pivot: Vector2, points: Array, layer: int, leaf := false) -> void:
	var joint := Node2D.new()
	joint.name = id
	joint.position = pivot - BODY_PIVOT
	body.add_child(joint)
	joints[id] = joint
	_rest[id] = {"position":joint.position,"pivot":pivot}
	var surface := Polygon2D.new()
	surface.name = "Painting"
	surface.texture = _texture
	surface.z_as_relative = false
	surface.z_index = layer
	joint.add_child(surface)
	surfaces[id] = surface
	var outline := PackedVector2Array()
	for point in points: outline.append(Vector2(point[0],point[1]))
	if leaf:
		var vertices := PackedVector2Array()
		var regions := [_clip_crease(outline,false),_clip_crease(outline,true)] if id == "WingNear" else [outline]
		for region: PackedVector2Array in regions:
			var indices := Geometry2D.triangulate_polygon(region)
			for index in indices: vertices.append(region[index])
		wing_vertices[id] = vertices
		var polygons: Array[PackedInt32Array] = []
		for i in range(0,vertices.size(),3): polygons.append(PackedInt32Array([i,i + 1,i + 2]))
		surface.polygons = polygons
		surface.uv = vertices
		var local := PackedVector2Array()
		for point in vertices: local.append(point - pivot)
		surface.polygon = local
	else:
		surface.uv = outline
		var local := PackedVector2Array()
		for point in outline: local.append(point - pivot)
		surface.polygon = local


func _clip_crease(outline: PackedVector2Array, positive: bool) -> PackedVector2Array:
	# Align triangle edges with the actual hinge so a thin triangle never straddles the fold.
	var output := PackedVector2Array()
	var line := (CORNER_B - CORNER_A).normalized()
	var outward := Vector2(line.y,-line.x)
	var previous := outline[outline.size() - 1]
	var previous_distance := (previous - CORNER_A).dot(outward)
	for point in outline:
		var distance := (point - CORNER_A).dot(outward)
		var inside := distance >= 0.0 if positive else distance <= 0.0
		var previous_inside := previous_distance >= 0.0 if positive else previous_distance <= 0.0
		if inside != previous_inside:
			var crossing := previous.lerp(point,previous_distance / (previous_distance - distance))
			if output.is_empty() or output[-1].distance_to(crossing) > 0.001: output.append(crossing)
		if inside and (output.is_empty() or output[-1].distance_to(point) > 0.001): output.append(point)
		previous = point
		previous_distance = distance
	if output.size() > 1 and output[0].distance_to(output[-1]) < 0.001: output.resize(output.size() - 1)
	return output


func _build_rig() -> void:
	_piece("WingFar",Vector2(540,697),[[540,697],[470,647],[410,607],[365,530],[341,438],[324,341],[312,250],[320,167],[351,94],[374,70],[392,76],[458,134],[529,213],[608,293],[680,361],[704,389],[693,427],[651,491],[606,573],[565,641]],0,true)
	_piece("AntennaFar",Vector2(414,663),[[260,496],[286,495],[281,517],[326,537],[365,558],[390,598],[410,644],[421,659],[410,670],[395,642],[374,609],[339,577],[291,561],[267,546],[251,523]],1)
	_piece("RibbonIvory",Vector2(704,885),[[693,874],[715,881],[748,924],[781,949],[829,962],[864,987],[868,1030],[890,1056],[863,1049],[837,1025],[832,1004],[812,995],[784,1001],[758,982],[727,962],[705,934],[694,904]],1)
	_piece("RibbonRed",Vector2(720,860),[[700,838],[737,850],[770,877],[839,900],[894,910],[950,923],[991,943],[1010,970],[1017,999],[1035,1030],[1025,1086],[1008,1096],[994,1047],[960,1013],[915,986],[865,970],[813,956],[770,932],[739,896],[710,875]],2)
	_piece("Body",BODY_PIVOT,[[365,641],[407,638],[460,660],[502,662],[540,680],[544,716],[548,747],[579,776],[630,807],[679,830],[719,847],[731,867],[707,883],[681,879],[634,855],[576,821],[527,791],[475,762],[424,737],[390,716],[379,690]],3)
	_piece("AntennaNear",Vector2(392,675),[[141,548],[170,544],[190,574],[239,590],[300,607],[350,634],[380,653],[394,673],[380,677],[360,648],[300,626],[239,617],[192,610],[157,591],[145,570]],4)
	_piece("WingNear",Vector2(548,727),[[539,728],[540,697],[582,627],[630,558],[705,450],[790,367],[890,282],[1000,199],[1120,117],[1220,55],[1255,18],[1280,20],[1295,43],[1303,83],[1300,130],[1310,183],[1320,220],[1316,264],[1330,320],[1355,400],[1369,460],[1360,494],[1346,517],[1317,570],[1306,615],[1240,652],[1138,715],[1004,770],[858,831],[790,878],[708,850],[620,800],[549,757]],5,true)


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
	var t := [0.0,0.75,1.5,2.25,3.0]
	_track(idle,self,"near_close",t,[0.0,0.24,0.12,0.03,0.0],true)
	_track(idle,self,"far_close",t,[0.0,0.10,0.20,0.08,0.0],true)
	_track(idle,body,"position",t,[BODY_PIVOT,BODY_PIVOT + Vector2(0,-8),BODY_PIVOT + Vector2(0,-3),BODY_PIVOT + Vector2(0,4),BODY_PIVOT],true)
	library.add_animation("idle",idle)
	var mark := Animation.new()
	mark.length = LENGTH.mark
	t = [0.0,0.24,0.55,0.76,1.10]
	_track(mark,self,"corner_fold",t,[0.0,0.35,1.0,1.0,0.0])
	_track(mark,self,"near_close",t,[0.0,0.06,0.16,0.16,0.0])
	_track(mark,self,"far_close",t,[0.0,0.08,0.12,0.12,0.0])
	_track(mark,body,"position",t,[BODY_PIVOT,BODY_PIVOT + Vector2(10,-8),BODY_PIVOT + Vector2(12,-12),BODY_PIVOT + Vector2(8,-8),BODY_PIVOT])
	_track(mark,self,"effect",t,[0.0,0.0,1.0,0.6,0.0])
	library.add_animation("mark",mark)
	for folded in [false,true]:
		var id := "fold_attack" if folded else "attack"
		var clip := Animation.new()
		clip.length = LENGTH[id]
		var release: float = RELEASE[id]
		t = [0.0,release * 0.50,release * 0.83,release,release + 0.07,clip.length * 0.78,clip.length]
		_track(clip,self,"near_close",t,[0.0,0.04,0.0,0.96,0.92,0.14,0.0])
		_track(clip,self,"far_close",t,[0.0,0.03,0.0,0.88,0.83,0.21,0.0])
		_track(clip,self,"corner_fold",t,[0.0,0.65,1.0,1.0,0.7,0.12,0.0] if folded else [0.0,0.0,0.0,0.0,0.0,0.0,0.0])
		_track(clip,body,"position",t,[BODY_PIVOT,BODY_PIVOT + Vector2(25,-12),BODY_PIVOT + Vector2(30,-16),BODY_PIVOT + Vector2(-95,-4),BODY_PIVOT + Vector2(-90,0),BODY_PIVOT + Vector2(8,4),BODY_PIVOT])
		_track(clip,body,"rotation",t,[0.0,0.03,0.04,-0.08,-0.06,0.02,0.0])
		_track(clip,self,"effect",t,[0.0,0.0,0.0,1.0,0.5,0.0,0.0])
		library.add_animation(id,clip)
	var hit := Animation.new()
	hit.length = LENGTH.hit
	t = [0.0,0.06,0.16,0.31,0.48]
	_track(hit,self,"near_close",t,[0.0,0.48,0.12,0.16,0.0])
	_track(hit,self,"far_close",t,[0.0,0.12,0.38,0.08,0.0])
	_track(hit,body,"position",t,[BODY_PIVOT,BODY_PIVOT + Vector2(38,4),BODY_PIVOT + Vector2(12,-5),BODY_PIVOT + Vector2(-6,0),BODY_PIVOT])
	_track(hit,body,"rotation",t,[0.0,0.10,-0.04,0.015,0.0])
	library.add_animation("hit",hit)
	var death := Animation.new()
	death.length = LENGTH.death
	t = [0.0,0.18,0.46,0.78,1.12]
	_track(death,self,"near_close",t,[0.0,0.25,0.95,1.0,1.0])
	_track(death,self,"far_close",t,[0.0,0.12,0.72,0.90,0.90])
	_track(death,self,"corner_fold",t,[0.0,0.3,0.8,1.0,1.0])
	_track(death,body,"position",t,[BODY_PIVOT,BODY_PIVOT + Vector2(8,12),BODY_PIVOT + Vector2(20,45),BODY_PIVOT + Vector2(35,105),BODY_PIVOT + Vector2(45,150)])
	_track(death,body,"rotation",t,[0.0,0.05,0.14,0.25,0.32])
	_track(death,self,"modulate:a",t,[1.0,1.0,1.0,0.5,0.0])
	library.add_animation("death",death)
	player.add_animation_library("",library)


func _reset_pose() -> void:
	player.stop()
	body.position = BODY_PIVOT
	body.rotation = 0.0
	near_close = 0.0
	far_close = 0.0
	corner_fold = 0.0
	effect = 0.0
	modulate = Color.WHITE
	for id in joints:
		joints[id].position = _rest[id].position
		joints[id].rotation = 0.0
		joints[id].scale = Vector2.ONE
		surfaces[id].modulate = Color.WHITE


func folded_source_point(point: Vector2) -> Vector2:
	var line := (CORNER_B - CORNER_A).normalized()
	var outward := Vector2(line.y,-line.x)
	var distance := (point - CORNER_A).dot(outward)
	if distance <= 0.0: return point
	return point - outward * distance * (1.0 - cos(corner_fold * 1.25))


func leaf_point(id: String, source: Vector2) -> Vector2:
	var pivot: Vector2 = _rest[id].pivot
	var close := clampf(near_close if id == "WingNear" else far_close,0.0,1.0)
	var direction := Vector2(0.71,-0.70).normalized() if id == "WingNear" else Vector2(-0.26,-0.97).normalized()
	var across := direction.orthogonal()
	var point := folded_source_point(source) if id == "WingNear" else source
	var offset := point - pivot
	return direction * offset.dot(direction) * lerpf(1.0,0.70,close) + across * offset.dot(across) * lerpf(1.0,0.24,close)


func _sync_pose() -> void:
	var phase := clock_seconds * TAU / LENGTH.idle
	if player.current_animation == "idle": phase = player.current_animation_position * TAU / LENGTH.idle
	for id in ["WingFar","WingNear"]:
		var close := clampf(near_close if id == "WingNear" else far_close,0.0,1.0)
		joints[id].rotation = (-0.64 if id == "WingNear" else 0.48) * close
		var points := PackedVector2Array()
		for point in wing_vertices[id]: points.append(leaf_point(id,point))
		surfaces[id].polygon = points
		if id == "WingNear":
			var colors := PackedColorArray()
			var line := (CORNER_B - CORNER_A).normalized()
			var outward := Vector2(line.y,-line.x)
			for point in wing_vertices[id]:
				var distance: float = (point - CORNER_A).dot(outward)
				colors.append(Color.WHITE.darkened(corner_fold * 0.15 * smoothstep(0.0,12.0,distance)))
			surfaces[id].vertex_colors = colors
		surfaces[id].modulate = Color(1.0,1.0,1.0,1.0).darkened(close * 0.10)
	if not Settings.reduced_motion:
		joints.AntennaFar.rotation = sin(phase - 0.35) * 0.045 + body.rotation * -0.25
		joints.AntennaNear.rotation = sin(phase - 0.65) * 0.065 + body.rotation * -0.35
		joints.RibbonRed.rotation = sin(phase - 0.80) * 0.10 - body.rotation * 0.80 + near_close * 0.16
		joints.RibbonIvory.rotation = sin(phase - 1.25) * 0.13 - body.rotation * 0.55 + far_close * 0.10
	_accents.queue_redraw()


func play_action(move: EnemyMoveData, _hit_index := 0) -> Dictionary:
	var clip := ""
	var tag := String(move.get_meta("visual_action",""))
	if move.kind in [EnemyMoveData.Kind.ATTACK,EnemyMoveData.Kind.ATTACK_BLOCK,EnemyMoveData.Kind.MULTI]: clip = "fold_attack" if tag == "fold_attack" else "attack"
	elif move.kind == EnemyMoveData.Kind.SPECIAL and tag == "mark": clip = "mark"
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
	return joints.WingFar.to_global(leaf_point("WingFar",Vector2(374,70)))


func sample(clip: String, seconds: float, clock: float) -> void:
	_reset_pose()
	clock_seconds = clock
	player.play(clip)
	player.seek(clampf(seconds,0.0,LENGTH[clip]),true)
	_sync_pose()


func animation_length(clip: String) -> float:
	return LENGTH[clip]


func capture_sample(clip: String, seconds: float, delta: float) -> void:
	sample(clip,seconds,clock_seconds + delta)


func _process(delta: float) -> void:
	if _resting != Settings.reduced_motion:
		_resting = Settings.reduced_motion
		_reset_pose()
		if defeated: modulate.a = 0.18
		elif not _resting: player.play("idle")
	if not _resting: clock_seconds += delta
	_sync_pose()


func _on_finished(clip: StringName) -> void:
	if clip == "death" or defeated or Settings.reduced_motion: return
	_reset_pose()
	player.play("idle")


func _draw_accents() -> void:
	if effect <= 0.0 or Settings.reduced_motion: return
	if player.current_animation == "mark":
		var a := to_local(joints.WingNear.to_global(leaf_point("WingNear",CORNER_A)))
		var b := to_local(joints.WingNear.to_global(leaf_point("WingNear",CORNER_B)))
		_accents.draw_line(a,b,Color(0.64,0.46,0.22,effect * 0.75),3.0,true)
	else:
		var tip := to_local(action_global_position())
		_accents.draw_polyline(PackedVector2Array([tip + Vector2(80,-30),tip,tip + Vector2(-85,25)]),Color(0.90,0.83,0.65,effect * 0.70),5.0,true)
