extends RefCounted
const ROOT := "res://assets/title/courtyard/materials/"
var wood: StandardMaterial3D
var paint: StandardMaterial3D
var dark_paint: StandardMaterial3D
var stone: StandardMaterial3D
var plaster: StandardMaterial3D
var roof: StandardMaterial3D
var brass: StandardMaterial3D
var paper: StandardMaterial3D
var red: StandardMaterial3D


func _init() -> void:
	wood = _textured("weathered_planks", Color("969184"), 0.82, 0.5)
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint = _textured("weathered_planks", Color("84d9c3"), 0.7, 0.7)
	dark_paint = _textured("weathered_planks", Color("344944"), 0.82, 0.7)
	stone = _textured("slate_floor", Color("b8c6bb"), 0.42, 0.45)
	plaster = _textured("white_plaster_rough_01", Color("c9c5b4"), 0.94, 0.35)
	roof = _textured("roof_slates_02", Color("789b90"), 0.67, 0.5)
	roof.cull_mode = BaseMaterial3D.CULL_DISABLED
	brass = plain(Color("8f7950"), 0.58)
	brass.metallic = 0.55
	paper = plain(Color("d6cbb0"), 0.88)
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	red = plain(Color("a6584d"), 0.85)


func _textured(asset: String, tint: Color, roughness: float, metre_scale: float) -> StandardMaterial3D:
	var material := plain(tint, roughness)
	material.albedo_texture = load(ROOT + asset + "_diffuse.jpg")
	material.normal_enabled = true
	material.normal_texture = load(ROOT + asset + "_nor_gl.jpg")
	material.normal_scale = 0.38
	material.roughness_texture = load(ROOT + asset + "_rough.jpg")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * metre_scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func plain(tint: Color, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	return material
