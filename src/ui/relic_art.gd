extends RefCounted
class_name RelicArt
## Transparent renders of the same specimens used on the shop counter.
const TEXTURES := {
	"strike": preload("res://assets/relics/icons/strike.png"),
	"breach": preload("res://assets/relics/icons/breach.png"),
	"slab": preload("res://assets/relics/icons/slab.png"),
	"press": preload("res://assets/relics/icons/press.png"),
	"sleep": preload("res://assets/relics/icons/sleep.png"),
	"clean": preload("res://assets/relics/icons/clean.png"),
	"wheel": preload("res://assets/relics/icons/wheel.png"),
	"powerbank": preload("res://assets/relics/icons/powerbank.png"),
	"fireman": preload("res://assets/relics/icons/fireman.png"),
	"fertilizer": preload("res://assets/relics/icons/fertilizer.png"),
	"skyfire": preload("res://assets/relics/icons/skyfire.png"),
	"blitz": preload("res://assets/relics/icons/blitz.png"),
	"egg": preload("res://assets/relics/icons/egg.png"),
	"buckler": preload("res://assets/relics/icons/buckler.png"),
	"barrier": preload("res://assets/relics/icons/barrier.png"),
	"empty_case": preload("res://assets/relics/icons/empty_case.png"),
	"stay_wax": preload("res://assets/relics/icons/stay_wax.png"),
	"amber": preload("res://assets/relics/icons/amber.png"),
	"ghost_hand": preload("res://assets/relics/icons/ghost_hand.png"),
	"cracked_bottle": preload("res://assets/relics/icons/cracked_bottle.png"),
	"rotting_fruit": preload("res://assets/relics/icons/rotting_fruit.png"),
	"chaos_dice": preload("res://assets/relics/icons/chaos_dice.png"),
	"black_water": preload("res://assets/relics/icons/black_water.png"),
	"life_lantern": preload("res://assets/relics/icons/life_lantern.png"),
	"life_debt": preload("res://assets/relics/icons/life_debt.png"),
	"chain": preload("res://assets/relics/icons/chain.png"),
	"question": preload("res://assets/relics/icons/question.png"),
	"goldleaf": preload("res://assets/relics/icons/goldleaf.png"),
	"moon": preload("res://assets/relics/icons/moon.png"),
	"slot": preload("res://assets/relics/icons/slot.png"),
	"death": preload("res://assets/relics/icons/death.png"),
	"ruin": preload("res://assets/relics/icons/ruin.png"),
	"rubbing": preload("res://assets/relics/icons/rubbing.png"),
	"midas": preload("res://assets/relics/icons/midas.png"),
	"monkey": preload("res://assets/relics/icons/monkey.png"),
	"palindrome": preload("res://assets/relics/icons/palindrome.png"),
	"binding": preload("res://assets/relics/icons/binding.png"),
	"proof": preload("res://assets/relics/icons/proof.png"),
}


static func texture(id: String) -> Texture2D:
	return TEXTURES.get(id)


static func icon(id: String, extent := 64.0) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture(id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2.ONE * extent
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_meta("relic_id", id)
	return picture


static func apply_button(button: Button, id: String, extent := 48.0) -> void:
	button.icon = texture(id)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", int(extent))
	button.set_meta("relic_id", id)
