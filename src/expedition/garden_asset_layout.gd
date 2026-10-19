extends RefCounted
## World XZ envelopes at production scales; checked against native meshes.
const WALK_SCALE := .60
# Raised floors are presentation only; the expedition still uses one walk grid.
# Keep their mesh placement, approach slopes, actor feet and ray picks together.
const DECK_Y := .07
const WALK_FLOOR_Y := DECK_Y - .17 * WALK_SCALE
const WALK_LANE_OFFSET := -.024
const LOCAL_BOUNDS := {
	"moon_gate":Rect2(-1.06,-.20,2.12,.45),"screen_wall":Rect2(-.92,-.24,1.84,.68),
	"covered_walk":Rect2(-1.41,-.62,2.82,1.31),"bridge":Rect2(-1.25,-.53,2.50,1.06),
	"grave_bed":Rect2(-.90,-.90,1.80,1.80),"休":Rect2(-.49,-.40,.98,.83),
	"市":Rect2(-.50,-.32,.95,.74),"谜":Rect2(-.45,-.32,.90,.75),
	"起":Rect2(-.50,-.23,1.00,.57),"巢":Rect2(-.58,-.27,1.16,.67)}


static func envelope(asset: String, at: Vector3, turn := 0.0) -> Rect2:
	var local: Rect2 = LOCAL_BOUNDS[asset]
	var result := Rect2()
	var first := true
	var basis := Basis(Vector3.UP,turn)
	for p in [local.position,Vector2(local.end.x,local.position.y),local.end,Vector2(local.position.x,local.end.y)]:
		var world: Vector3 = at+basis*Vector3(p.x,0,p.y)
		var point := Vector2(world.x,world.z)
		result = Rect2(point,Vector2.ZERO) if first else result.expand(point)
		first = false
	return result


static func walk_fixtures(asset: Node3D) -> void:
	for light in asset._lamps:
		(light.get_parent() as Node3D).position.z = -.56


## Local coordinates are already at production scale, relative to the asset root.
## A patch plane is y = height + gradient.dot(local_xz).
static func floor_patches(asset: String) -> Array[Dictionary]:
	if asset=="covered_walk":
		return [
			{"rect":Rect2(-1.278,-.486,2.556,.972),"height":DECK_Y-.018,"gradient":Vector2.ZERO},
			{"rect":Rect2(-1.224,-.426,2.448,.852),"height":DECK_Y,"gradient":Vector2.ZERO},
			{"rect":Rect2(-1.224,.426,2.448,.24),"height":DECK_Y+DECK_Y/.24*.426,"gradient":Vector2(0,-DECK_Y/.24)}]
	if asset=="bridge":
		return [
			{"rect":Rect2(-1.045,-.425,2.09,.85),"height":DECK_Y,"gradient":Vector2.ZERO},
			{"rect":Rect2(1.045,-.425,.18,.85),"height":DECK_Y+DECK_Y/.18*1.045,"gradient":Vector2(-DECK_Y/.18,0)},
			{"rect":Rect2(-1.225,-.425,.18,.85),"height":DECK_Y+DECK_Y/.18*1.045,"gradient":Vector2(DECK_Y/.18,0)}]
	return []


static func surface_patches(map: Dictionary) -> Array[Dictionary]:
	var patches: Array[Dictionary] = []
	if map.get("layout",{}).get("version","")!="garden_v2": return patches
	for entry in map.layout.structures:
		for patch in floor_patches(entry.asset):
			patch["origin"] = entry.at
			patch["basis"] = Basis(Vector3.UP,entry.turn)
			patches.append(patch)
	return patches


static func surface_height(patches: Array[Dictionary], point: Vector3) -> float:
	var result := 0.0
	for patch in patches:
		var local: Vector3 = patch.basis.transposed()*(point-patch.origin)
		var xz := Vector2(local.x,local.z)
		if patch.rect.grow(.000001).has_point(xz):
			result = maxf(result,patch.origin.y+patch.height+patch.gradient.dot(xz))
	return result


## Exact plane hits avoid changing the selected tile when zooming over a ramp.
static func ray_surface(patches: Array[Dictionary], origin: Vector3, direction: Vector3) -> Vector3:
	if direction.y>=-.0001: return Vector3.INF
	var nearest := -origin.y/direction.y
	for patch in patches:
		var normal: Vector3 = patch.basis*Vector3(-patch.gradient.x,1,-patch.gradient.y)
		var denominator := normal.dot(direction)
		if absf(denominator)<.000001: continue
		var on_plane: Vector3 = patch.origin+Vector3.UP*patch.height
		var distance := normal.dot(on_plane-origin)/denominator
		if distance<0 or distance>nearest: continue
		var local: Vector3 = patch.basis.transposed()*(origin+direction*distance-patch.origin)
		if patch.rect.grow(.000001).has_point(Vector2(local.x,local.z)): nearest = distance
	return origin+direction*nearest
