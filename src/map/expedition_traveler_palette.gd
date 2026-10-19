extends Resource
## Costume colors are independent of the level palette. All are editable in Godot.
@export var coat := Color("293c40"):
	set(value):
		coat = value
		emit_changed()
@export var coat_fold := Color("203035"):
	set(value):
		coat_fold = value
		emit_changed()
@export var scarf := Color("963b30"):
	set(value):
		scarf = value
		emit_changed()
@export var bone := Color("a99b76"):
	set(value):
		bone = value
		emit_changed()
@export var hem := Color("707260"):
	set(value):
		hem = value
		emit_changed()
@export var gold := Color("967943"):
	set(value):
		gold = value
		emit_changed()
@export var leather := Color("343733"):
	set(value):
		leather = value
		emit_changed()
@export var recess := Color("101b20"):
	set(value):
		recess = value
		emit_changed()
@export var lamp := Color("e4502c"):
	set(value):
		lamp = value
		emit_changed()
