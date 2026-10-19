extends Node
## Regression: inventory UI must not reframe the map or send clicks through it.
const RUN = preload("res://src/expedition/room_run_state.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-18-inventory-overlay"
var failures: Array = []
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)


func _ready() -> void:
	get_window().size = Vector2i(1280,720)
	await frames(2)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var run := RUN.new(); run.reset({"seed":17}); run.autosave = false
	run.tray = ["火","电","击"]
	run._arrive("opening_1")
	run.position = run.layout.rooms.opening_1.stand_cell
	Router.goto(RUN.MAP_SCREEN)
	await frames(4)
	var screen: Control = Router.current
	var view: Control = screen.map_view
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,1000)]:
		get_window().size = resolution
		await frames(100)
		var safe: Rect2 = view.safe_area()
		var distance: float = view._distance
		var zoom: float = view._zoom
		var camera: Transform3D = view.camera.global_transform
		var position: Vector2i = run.position
		var rng: int = GameState.rng.state
		check(screen.drawer.visible,"encounter drawer present before opening")
		# Use the real character hit region and normal GUI dispatch.
		var actor_at: Vector2 = view.global_position+view.screen_point(view.walker.position+Vector3.UP*.45)
		click(actor_at)
		await frames(12)
		check(screen.inventory.visible and screen.inventory_layer.visible,"character click opens inventory")
		check(safe.is_equal_approx(view.safe_area()) and is_equal_approx(distance,view._distance),"opening inventory preserves map framing")
		check(camera.origin.distance_to(view.camera.global_transform.origin)<.02,"opening inventory keeps settled camera position")
		check(Rect2(Vector2.ZERO,screen.size).encloses(screen.inventory.get_rect()),"inventory fits window")
		check(run.position==position and GameState.rng.state==rng,"opening inventory does not move player or consume RNG")
		# Updating inventory contents used to leave its layout out of sync.
		screen._selected = 0; screen._refresh_inventory()
		await frames(8)
		check(Rect2(Vector2.ZERO,screen.size).encloses(screen.inventory.get_rect()),"expanded inventory contents remain within window")
		check(safe.is_equal_approx(view.safe_area()),"inventory content changes do not shrink map")
		if OS.get_cmdline_user_args().has("--capture") and resolution==Vector2i(1280,720):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OUTPUT.path_join("01-inventory-open.png"))
		# Scroll over the world is captured by the overlay, not the map camera.
		var outside := Vector2(screen.size.x-8,screen.size.y*.7)
		mouse_button(outside,MOUSE_BUTTON_WHEEL_DOWN,true)
		await frames(3)
		check(is_equal_approx(view._zoom,zoom) and not view._moving,"inventory blocks map zoom and movement")
		click(outside)
		await frames(8)
		check(not screen.inventory.visible and not screen.inventory_layer.visible,"outside click closes inventory")
		check(not view._moving and run.position==position,"closing click never starts a walk")
		check(safe.is_equal_approx(view.safe_area()) and is_equal_approx(distance,view._distance),"outside close preserves map framing")
		# The actual close button must restore all overlay state, not just visibility.
		screen._toggle_inventory(); await frames(6)
		for child in screen.inventory_box.get_children():
			if child is Button and child.text=="收起行囊": child.pressed.emit(); break
		await frames(6)
		check(not screen.inventory.visible and not view._interaction_blocked,"close button restores map interaction")
		check(safe.is_equal_approx(view.safe_area()),"close button leaves no stale reserved area")
		# Inventory owns Escape even while the route overview is active.
		view.show_overview(); screen._toggle_inventory(); await frames(6)
		key(KEY_ESCAPE); await frames(6)
		check(not screen.inventory.visible and view._overview,"Escape closes inventory before changing overview")
		view.recenter(); await frames(4)
		key(KEY_I); await frames(5)
		check(screen.inventory.visible,"I opens inventory")
		key(KEY_M); await frames(3)
		check(not view._overview,"inventory blocks map shortcuts")
		key(KEY_I); await frames(5)
		check(not screen.inventory.visible and not view._interaction_blocked,"I closes inventory")
		print("[InventoryUI] window=",resolution," safe=",safe," distance=",distance," panel=",screen.inventory.get_rect())
	# Resize while open and keep the same framing as the closed state at that size.
	screen._toggle_inventory()
	get_window().size = Vector2i(1280,720); await frames(30)
	var resized_safe: Rect2 = view.safe_area(); var resized_distance: float = view._distance
	check(Rect2(Vector2.ZERO,screen.size).encloses(screen.inventory.get_rect()),"open inventory responds to window resize")
	screen._toggle_inventory(); await frames(8)
	check(resized_safe.is_equal_approx(view.safe_area()) and is_equal_approx(resized_distance,view._distance),"close after resize does not reframe map")
	print("[InventoryUI] checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func click(at: Vector2) -> void:
	mouse_button(at,MOUSE_BUTTON_LEFT,true)
	mouse_button(at,MOUSE_BUTTON_LEFT,false)


func mouse_button(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at; event.global_position = at; event.button_index = button; event.pressed = pressed
	get_viewport().push_input(event,true)


func key(code: Key) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	get_viewport().push_input(event,true)
	var release := InputEventKey.new(); release.keycode = code; release.pressed = false
	get_viewport().push_input(release,true)


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame
