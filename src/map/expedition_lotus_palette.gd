extends Resource
class_name ExpeditionLotusPalette
## Restrained botanical paints, separate from the shared stone/architecture palette.
@export var water_deep := Color("172730"):
	set(value): water_deep = value; emit_changed()
@export var water_light := Color("2a3d44"):
	set(value): water_light = value; emit_changed()
@export var ripple := Color("3c5155"):
	set(value): ripple = value; emit_changed()
@export var leaf := Color("3c5148"):
	set(value): leaf = value; emit_changed()
@export var leaf_light := Color("556458"):
	set(value): leaf_light = value; emit_changed()
@export var leaf_shadow := Color("253a35"):
	set(value): leaf_shadow = value; emit_changed()
@export var withered := Color("6a624c"):
	set(value): withered = value; emit_changed()
@export var petal_base := Color("6f3443"):
	set(value): petal_base = value; emit_changed()
@export var petal_tip := Color("9c6570"):
	set(value): petal_tip = value; emit_changed()
@export var petal_inner := Color("b4a08b"):
	set(value): petal_inner = value; emit_changed()
@export var seed := Color("aa8952"):
	set(value): seed = value; emit_changed()
