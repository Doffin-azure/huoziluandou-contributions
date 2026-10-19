extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const PLAN = preload("res://src/expedition/garden_bridge_plan.gd")
const SURFACE = preload("res://src/expedition/garden_asset_layout.gd")
var failures: Array = []
var count := 0
func check(value: bool, message: String) -> void:
	count += 1
	if not value: failures.append(message); push_error(message)

func _ready() -> void:
	var run := RUN.new(); run.reset({"seed":17})
	var rng_before := GameState.rng.state
	var spans := PLAN.generate(run.layout,run.graph)
	check(GameState.rng.state==rng_before,"bridge art must not consume gameplay RNG")
	var types := {}
	for span in spans: types[span.kind] = true
	check(types.has("arch") and types.has("covered") and types.has("pier") and types.has("gallery"),"all four span families present")
	var patches := PLAN.surface_patches(spans)
	for span in spans:
		check(absf(PLAN.elevation(span.kind,0,span.length))<.000001 and absf(PLAN.elevation(span.kind,span.length,span.length))<.000001,"both bridge approaches meet zero-height ground")
		if span.kind!="arch": continue
		var p: Vector2 = span.start+span.direction*span.length*.43
		var expected := PLAN.height_at(spans,p)
		var position := Vector3(p.x,0,p.y)
		check(expected>.20,"arch has an actual raised walking surface")
		check(absf(SURFACE.surface_height(patches,position)-expected)<.00001,"feet follow constructed arch profile")
		var hit := SURFACE.ray_surface(patches,position+Vector3.UP*8,Vector3.DOWN)
		check(absf(hit.y-expected)<.00001,"ray picks the same arch deck")
	var bends := 0
	for corridor in run.layout.corridors: bends += maxi(0,corridor.points.size()-2)
	check(bends<run.layout.corridors.size()*4,"bridge layout uses long orthogonal spans instead of staircases")
	print("[GardenBridge] checks=",count," failures=",failures.size()," spans=",spans.size()," families=",types," bends=",bends)
	get_tree().quit(0 if failures.is_empty() else 1)
