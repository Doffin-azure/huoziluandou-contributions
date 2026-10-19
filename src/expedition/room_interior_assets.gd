extends RefCounted
## Shared placement/navigation dimensions for the new native interior assets.
## Values are unscaled local world units, including usable pavilion floors.
const MODELS := {
	"red_maple":{"scene":"red_maple","half":Vector2(.65,.625),"crown":Vector2(2.35,1.35),"height":3.9},
	"leaning_maple":{"scene":"leaning_red_maple","half":Vector2(.65,.625),"crown":Vector2(2.65,1.35),"height":3.9},
	"crooked_pine":{"scene":"crooked_pine","half":Vector2(.75,.725),"crown":Vector2(2.55,1.05),"height":3.6},
	"willow":{"scene":"weeping_willow","half":Vector2(.675,.65),"crown":Vector2(1.8,1.6),"height":3.6},
	"bare_locust":{"scene":"bare_locust","half":Vector2(.85,.8),"crown":Vector2(1.9,1.3),"height":3.7},
	"square_pavilion":{"scene":"square_pavilion","half":Vector2(1.35,1.45),"crown":Vector2(1.58,1.51),"height":2.6},
	"hex_pavilion":{"scene":"hex_pavilion","half":Vector2(1.35,1.5),"crown":Vector2(1.62,1.62),"height":2.8},
	"low_rockery":{"scene":"low_rockery","half":Vector2(1.45,.95),"height":1.5},
	"hollow_rockery":{"scene":"hollow_rockery","half":Vector2(1.375,.95),"height":2.8},
	"small_loft":{"scene":"small_loft","half":Vector2(1.75,1.625),"crown":Vector2(1.86,1.65),"height":3.9},
	"stone_table":{"furnishing":4,"half":Vector2(.90,.475),"height":.65},
	"writing_desk":{"furnishing":5,"half":Vector2(.675,.35),"height":.75},
	"stone_bench":{"furnishing":6,"half":Vector2(.75,.26),"height":.45},
	"incense":{"furnishing":7,"half":Vector2(.34,.30),"height":.80},
	"lotus_tub":{"furnishing":8,"half":Vector2(.45,.45),"height":.65},
	"type_rack":{"furnishing":9,"half":Vector2(.56,.25),"height":1.35},
	"type_cabinet":{"furnishing":2,"half":Vector2(.56,.36),"height":1.35},
	"lamp":{"half":Vector2(.29,.29),"height":1.65},
	"screen":{"half":Vector2(1.9,.4),"crown":Vector2(2.1,.6),"height":2.5},
}


static func has_asset(asset: String) -> bool: return MODELS.has(asset)


static func is_tree(asset: String) -> bool:
	return asset in ["red_maple","leaning_maple","crooked_pine","willow","bare_locust"]


static func local_blocks(asset: String) -> Array:
	if asset=="square_pavilion":
		return [Rect2(-1.16,-1.12,.28,2.28),Rect2(.88,-1.12,.28,2.28),Rect2(-.88,-1.13,1.76,.30)]
	if asset=="hex_pavilion":
		var result: Array = [Rect2(-.38,-.38,.76,.76),Rect2(-.66,.08,.34,.35),Rect2(.32,.08,.34,.35),Rect2(-.9,-1.0,1.8,.35)]
		for n in 6:
			var angle := PI/6+TAU*n/6.0
			result.append(Rect2(Vector2(cos(angle),sin(angle))*1.07-Vector2.ONE*.15,Vector2.ONE*.30))
		return result
	var half: Vector2 = MODELS[asset].half
	return [Rect2(-half,half*2)]


static func floor_patches(prop: Dictionary) -> Array:
	if prop.asset=="square_pavilion":
		return [{"rect":Rect2(-1.24,-1.18,2.48,2.36),"y":.17},{"rect":Rect2(-.65,1.12,1.30,.22),"y":.13},{"rect":Rect2(-.65,1.34,1.30,.13),"y":.07}]
	if prop.asset=="hex_pavilion":
		# The central round table is solid; this patch only raises walkable cells.
		return [{"rect":Rect2(-1.1,-1.08,2.2,2.16),"y":.173},{"rect":Rect2(-.55,1.08,1.1,.45),"y":.08}]
	return []


static func placed_rect(prop: Dictionary, visual := false) -> Rect2:
	var data: Dictionary = MODELS.get(prop.asset,{})
	var existing: Vector2 = {"rock_bed":Vector2(.65,.525),"type_cabinet":Vector2(.56,.36),"chest":Vector2(.55,.36),"lamp":Vector2(.16,.16)}.get(prop.asset,Vector2(.3,.3))
	var half: Vector2 = data.get("crown",data.get("half",existing)) if visual else data.get("half",existing)
	return transform_rect(Rect2(-half,half*2),prop)


static func transform_rect(rect: Rect2, prop: Dictionary) -> Rect2:
	var transform := Transform2D(-float(prop.turn),Vector2(prop.at.x,prop.at.z))
	var result := Rect2(transform*(rect.position*float(prop.scale)),Vector2.ZERO)
	for point in [Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		result = result.expand(transform*(point*float(prop.scale)))
	return result
