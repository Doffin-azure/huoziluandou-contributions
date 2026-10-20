extends RefCounted
class_name TaopunkArt
## 已校准的独立插画；墨灵保留原图，其余角色先按场景画法绘制再拆分。
const ROOT := "res://assets/taopunk/"
const ENEMIES := ["ink_spirit", "bronze_seal", "iron_seal", "paper_guard", "rust_scribe",
	"ember_imp", "boss_lead_plate", "boss_word_demon", "boss_chaos_press",
	"paper_shell", "needle_bee", "tilting_inkwell", "fold_moth", "blank_child", "corrosion_beetle",
	"glutton", "furnace_beast", "charge_badger", "ink_creditor", "double_slip", "nest_moth", "bomb_press",
	"copy_master", "seal_officer", "wheel_master", "leech", "proof_boss", "rail_boss", "compiler_boss"]
const PORTRAIT_FILES := {
	"paper_shell":"paper_shell_soldier", "needle_bee":"needle_wasp", "tilting_inkwell":"tilting_inkstone", "fold_moth":"fold_page_moth",
	"ink_creditor":"object_creatures/ink_creditor", "copy_master":"object_creatures/copy_master",
	"seal_officer":"object_creatures/seal_officer", "wheel_master":"object_creatures/wheel_master",
	"proof_boss":"object_creatures/proof_boss", "compiler_boss":"object_creatures/compiler_boss",
	"blank_child":"human_repaint/blank_child",
}
## 去掉透明留白后按形体落在台面上；四周保留 4 像素抗锯齿余量。
const PORTRAIT_REGIONS := {
	"bronze_seal": Rect2(9, 148, 1386, 880),
	"iron_seal": Rect2(15, 125, 1379, 937),
	"paper_guard": Rect2(9, 0, 1392, 1122),
	"rust_scribe": Rect2(24, 173, 1378, 872),
	"ember_imp": Rect2(24, 9, 1375, 1112),
	"boss_lead_plate": Rect2(9, 51, 1382, 1016),
	"boss_word_demon": Rect2(27, 63, 1360, 1017),
	"boss_chaos_press": Rect2(5, 261, 1397, 744),
}
static var _portraits: Dictionary = {}


static func background() -> Texture2D:
	return load(ROOT + "ritual_courtyard.png")


static func frame() -> Texture2D:
	return load(ROOT + "bronze_frame.png")


static func portrait(enemy_id: String) -> Texture2D:
	var index := ENEMIES.find(enemy_id)
	if index < 0: return null
	if _portraits.has(enemy_id): return _portraits[enemy_id]
	if enemy_id == "ink_spirit":
		_portraits[enemy_id] = load(ROOT + "ink_guardian.png")
		return _portraits[enemy_id]
	var atlas: Texture2D = load(ROOT + "enemies/%s.png" % PORTRAIT_FILES.get(enemy_id,enemy_id))
	if atlas == null: return null
	if not PORTRAIT_REGIONS.has(enemy_id):
		_portraits[enemy_id] = atlas
		return atlas
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = PORTRAIT_REGIONS[enemy_id]
	texture.filter_clip = true
	_portraits[enemy_id] = texture
	return texture
