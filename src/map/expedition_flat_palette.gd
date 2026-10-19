@tool
extends Resource
class_name ExpeditionFlatPalette
## Shared editable colors for flat-painted 3D assets.
@export var background := Color("192c28"):
	set(value):
		background = value
		emit_changed()
@export var ink := Color("162e28"):
	set(value):
		ink = value
		emit_changed()
@export var stone_top := Color("53675a"):
	set(value):
		stone_top = value
		emit_changed()
@export var stone_front := Color("354a3e"):
	set(value):
		stone_front = value
		emit_changed()
@export var stone_side := Color("2b4037"):
	set(value):
		stone_side = value
		emit_changed()
@export var wood_top := Color("64836e"):
	set(value):
		wood_top = value
		emit_changed()
@export var wood_front := Color("3e6357"):
	set(value):
		wood_front = value
		emit_changed()
@export var wood_side := Color("2e4c43"):
	set(value):
		wood_side = value
		emit_changed()
@export var bronze := Color("b6a073"):
	set(value):
		bronze = value
		emit_changed()
@export var seal := Color("a74c3c"):
	set(value):
		seal = value
		emit_changed()
@export_range(0.0, 6.0, 0.1) var outline_pixels := 2.2:
	set(value):
		outline_pixels = value
		emit_changed()
@export_group("Fire")
@export var fire_outer := Color("df6034"):
	set(value):
		fire_outer = value
		emit_changed()
@export var fire_inner := Color("ffb84c"):
	set(value):
		fire_inner = value
		emit_changed()
@export var fire_core := Color("fff0bd"):
	set(value):
		fire_core = value
		emit_changed()
@export var fire_light := Color("ffc078"):
	set(value):
		fire_light = value
		emit_changed()
@export_range(0.0, 2.0, 0.05) var fire_energy := 1.0:
	set(value):
		fire_energy = value
		emit_changed()
@export_range(0.7, 3.2, 0.05) var fire_radius := 2.2:
	set(value):
		fire_radius = value
		emit_changed()
@export_group("Inlaid glyphs")
@export var glyph_fill := Color("c8b681"):
	set(value):
		glyph_fill = value
		emit_changed()
@export var glyph_recess := Color("263c33"):
	set(value):
		glyph_recess = value
		emit_changed()
@export var glyph_edge := Color("82927a"):
	set(value):
		glyph_edge = value
		emit_changed()
@export var water := Color("315f60"):
	set(value):
		water = value
		emit_changed()


@export_group("Surroundings")
@export var patina := Color("294b45"):
	set(value):
		patina = value
		emit_changed()
@export var cloth := Color("71332f"):
	set(value):
		cloth = value
		emit_changed()
@export var architecture_top := Color("526b6d"):
	set(value):
		architecture_top = value
		emit_changed()
@export var architecture_front := Color("354f56"):
	set(value):
		architecture_front = value
		emit_changed()
@export var architecture_side := Color("263c46"):
	set(value):
		architecture_side = value
		emit_changed()
@export var roof := Color("2e464f"):
	set(value):
		roof = value
		emit_changed()
@export_range(0.0, 1.5, 0.05) var roof_light_response := 1.0:
	set(value):
		roof_light_response = value
		emit_changed()
@export var distant := Color("456b70"):
	set(value):
		distant = value
		emit_changed()
@export var mist := Color("5b8280"):
	set(value):
		mist = value
		emit_changed()
@export_group("Garden ground")
@export var garden_soil := Color("29392f"):
	set(value):
		garden_soil = value
		emit_changed()
@export var garden_grass := Color("385641"):
	set(value):
		garden_grass = value
		emit_changed()
@export var garden_grass_dark := Color("1b342e"):
	set(value):
		garden_grass_dark = value
		emit_changed()
@export var garden_moss := Color("53634b"):
	set(value):
		garden_moss = value
		emit_changed()
@export var garden_path_edge := Color("7b7559"):
	set(value):
		garden_path_edge = value
		emit_changed()
@export var garden_stone := Color("4f6359"):
	set(value):
		garden_stone = value
		emit_changed()
@export var garden_paper := Color("b7a46a"):
	set(value):
		garden_paper = value
		emit_changed()


@export_group("Tree")
@export var tree_bark := Color("53615b"):
	set(value):
		tree_bark = value
		emit_changed()
@export var tree_bark_shadow := Color("293c3b"):
	set(value):
		tree_bark_shadow = value
		emit_changed()
@export var tree_bark_light := Color("758071"):
	set(value):
		tree_bark_light = value
		emit_changed()
@export var tree_leaf := Color("354f48"):
	set(value):
		tree_leaf = value
		emit_changed()
@export var tree_leaf_shadow := Color("233b38"):
	set(value):
		tree_leaf_shadow = value
		emit_changed()
@export var tree_leaf_light := Color("536b59"):
	set(value):
		tree_leaf_light = value
		emit_changed()
@export var tree_ink := Color("102125"):
	set(value):
		tree_ink = value
		emit_changed()
@export_range(0.8, 4.0, 0.1) var tree_outline_pixels := 1.7:
	set(value):
		tree_outline_pixels = value
		emit_changed()


@export_group("Tombstones")
@export var tomb_stone := Color("304746"):
	set(value):
		tomb_stone = value
		emit_changed()
@export var tomb_cut := Color("4b5b50"):
	set(value):
		tomb_cut = value
		emit_changed()
@export var tomb_engraving := Color("102423"):
	set(value):
		tomb_engraving = value
		emit_changed()
@export var tomb_moss := Color("293f30"):
	set(value):
		tomb_moss = value
		emit_changed()


func tones(role: String) -> Array[Color]:
	match role:
		"stone": return [stone_top, stone_front, stone_side]
		"wood": return [wood_top, wood_front, wood_side]
		"bronze": return [bronze, bronze.darkened(0.13), bronze.darkened(0.28)]
		"seal": return [seal.lightened(0.08), seal, seal.darkened(0.24)]
		"architecture": return [architecture_top, architecture_front, architecture_side]
		"roof": return [roof, roof.darkened(.15), roof.darkened(.25)]
		"cloth": return [cloth.lightened(.025), cloth, cloth.darkened(.20)]
		"copper_dark": return [bronze.darkened(.15), bronze.darkened(.28), bronze.darkened(.40)]
		"patina": return [patina.lightened(.06),patina,patina.darkened(.24)]
		"distant": return _solid(distant)
		"distant_back": return _solid(distant.lerp(mist,.45))
		"foliage": return [seal.darkened(.12), seal.darkened(.24), seal.darkened(.38)]
		"foreground": return [ink.lightened(.035), ink, ink.darkened(.12)]
		"tree_bark": return _solid(tree_bark)
		"tree_bark_shadow": return _solid(tree_bark_shadow)
		"tree_bark_light": return _solid(tree_bark_light)
		"tree_leaf": return _solid(tree_leaf)
		"tree_leaf_shadow": return _solid(tree_leaf_shadow)
		"tree_leaf_light": return _solid(tree_leaf_light)
		"tombstone": return [tomb_stone.lightened(.08),tomb_stone,tomb_stone.darkened(.22)]
		"tomb_cut": return [tomb_cut,tomb_cut.darkened(.08),tomb_cut.darkened(.20)]
		"tomb_recess": return _solid(tomb_stone.darkened(.18))
		"tomb_moss": return _solid(tomb_moss)
		"slab_light": return _solid(stone_top.lightened(0.025))
		"slab_dark": return _solid(stone_top.darkened(0.025))
		"joint": return _solid(stone_front.lightened(0.10))
		"garden_grass": return _solid(garden_grass)
		"garden_grass_dark": return _solid(garden_grass_dark)
		"garden_moss": return _solid(garden_moss)
		"garden_path_edge": return _solid(garden_path_edge)
		"garden_stone": return [garden_stone.lightened(.06),garden_stone,garden_stone.darkened(.18)]
		"garden_paper": return [garden_paper.lightened(.10),garden_paper,garden_paper.darkened(.20)]
		"shadow": return _solid(Color(ink.r, ink.g, ink.b, 0.28))
		"contact": return _solid(Color(ink.r, ink.g, ink.b, 0.45))
		_: return _solid(ink)


func _solid(color: Color) -> Array[Color]:
	return [color, color, color]
