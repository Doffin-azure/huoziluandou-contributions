extends "res://src/map/expedition_building_base.gd"
## Standalone garden scenes can supply their own paint; a shared setup() wins.
const GARDEN_PALETTE = preload("res://assets/expedition/palettes/mochi_night.tres")
@export var palette_source: ExpeditionFlatPalette = GARDEN_PALETTE
var _own_style: ExpeditionFlatStyle
var _outline_time := 0.0


func _ready() -> void:
	_ensure_style.call_deferred()


func setup(painter: ExpeditionFlatStyle) -> void:
	super.setup(painter)
	var points: Array = get_meta("sockets",get_meta("connections",[]))
	for i in points.size():
		var socket := Marker3D.new()
		socket.name = "Socket%d" % i
		socket.position = points[i]
		add_child(socket)


func _ensure_style() -> void:
	if style!=null: return
	_own_style = ExpeditionFlatStyle.new(palette_source.duplicate(true))
	_own_style.set_scene_lighting(true)
	setup(_own_style)


func _process(delta: float) -> void:
	if _own_style==null: return
	_outline_time += delta
	if _outline_time<.12: return
	_outline_time = 0.0
	_own_style.camera = get_viewport().get_camera_3d()
	if _own_style.camera!=null: _own_style.refresh_outlines()


func _exit_tree() -> void:
	super._exit_tree()
	if _own_style!=null: _own_style.dispose()
