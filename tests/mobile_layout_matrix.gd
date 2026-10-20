extends Node
## Exercises actual phone density and safe areas, not just small desktop windows.
const RUN = preload("res://src/expedition/room_run_state.gd")
const EVENTS = preload("res://src/core/event_effects.gd")
var checks := 0
var failures: Array = []
var results: Array = []
var profile: Dictionary
var _viewport: SubViewport
var _host: Control


func _ready() -> void: _run.call_deferred()


func frames(n := 8) -> void:
	for i in n: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append("%s: %s" % [profile.id,message])


func fresh(kind := "") -> RefCounted:
	var run = RUN.start(29)
	if not kind.is_empty():
		for id: String in run.graph.rooms:
			if run.graph.rooms[id].kind==kind: run._arrive(id); break
	return run


func open_screen(name: String, params: Dictionary = {}) -> Control:
	Router.goto("res://src/screens/"+name+".gd",params)
	await frames()
	return Router.current


func bounds(screen: Control, items: Array, label: String) -> void:
	var safe := screen.get_global_transform() * ScreenLayout.safe_rect(screen)
	var fit := true
	var touch := true
	for item: Control in items:
		if not item.is_visible_in_tree(): continue
		fit = fit and safe.grow(1).encloses(item.get_global_rect())
		if not safe.grow(1).encloses(item.get_global_rect()):
			print("[layout bounds] ",profile.id," ",label," ",item.name," rect=",item.get_global_rect()," safe=",safe)
		if item is Button:
			touch = touch and item.size.y / JourneyStyle.touch_scale(screen) >= 47.9
	check(fit,label+" fits the safe display area")
	check(touch,label+" retains 48dp touch height")


func capture(screen: Control, name: String) -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture"): return
	if profile.id not in ["vivo-y33","iqoo-u1x","reference-2664","desktop-720"]: return
	RenderingServer.force_draw(false)
	var target := "res://shots/mobile-layout"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	_viewport.get_texture().get_image().save_png(target.path_join(profile.id+"-"+name+".png"))


func _run() -> void:
	SaveManager.enabled = false
	GameState.set_meta("courtyard_preview",true)
	Settings.reduced_motion = true
	Engine.max_fps = 240
	get_window().size = Vector2i(1280,720)
	var profiles: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mobile_screen_profiles.json")).profiles
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): profiles = profiles.filter(func(p):return p.id==arg.trim_prefix("--profile="))
	for value: Dictionary in profiles:
		profile = value
		var start_failures := failures.size()
		ScreenLayout.preview_density = profile.density
		ScreenLayout.preview_window_size = Vector2i(profile.pixels[0],profile.pixels[1])
		ScreenLayout.preview_insets = Vector4(profile.insets[0],profile.insets[1],profile.insets[2],profile.insets[3])
		var pixels := Vector2(ScreenLayout.preview_window_size)
		var stretch := minf(pixels.x/1280.0,pixels.y/720.0)
		_viewport = SubViewport.new(); _viewport.size = Vector2i((pixels/stretch).round())
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)
		_host = Control.new(); _host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _viewport.add_child(_host)
		Router.host = _host
		var run = fresh()
		run.save_run(RUN.SAVE_PATH) # Include the extra continue action in the title budget.
		var screen := await open_screen("title_screen")
		bounds(screen,screen._buttons,"title buttons")
		check(not screen._wordmark.get_global_rect().intersects(screen._menu.get_global_rect()),"logo does not overlap title actions")
		check(not screen._menu.get_global_rect().intersects(screen._utilities.get_global_rect()),"primary and secondary title actions do not overlap")
		await capture(screen,"title")
		run = fresh()
		screen = await open_screen("room_map_screen")
		screen._select_node(run.next_rooms()[0]); await frames()
		bounds(screen,screen.find_children("*","Button",true,false),"map buttons")
		bounds(screen,[screen._stats,screen._act_title],"map header")
		var grid_fits := true
		var controls_clear := true
		for id: String in screen.map_view.points:
			var at: Vector2 = screen.map_view.points[id]
			var radius: float = 23*JourneyStyle.touch_scale(screen)
			grid_fits = grid_fits and at.y-radius>=0 and at.y+radius<=screen.map_view.size.y
			var rect := Rect2(screen.map_view.global_position+at-Vector2.ONE*radius,Vector2.ONE*radius*2)
			controls_clear = controls_clear and not rect.intersects(screen._tools.get_global_rect())
		check(grid_fits,"all four map lanes remain inside the map")
		check(controls_clear,"map nodes do not overlap travel controls")
		await capture(screen,"map")
		for event_id in ["old_bookshop","delete_poems"]:
			run = fresh("event"); run.event_data = EVENTS.get_event(event_id).duplicate(true); run.event_node = "start"; run._sync_content()
			screen = await open_screen("event_screen",{"room_run":true})
			var buttons: Array = screen._buttons.duplicate()
			if is_instance_valid(screen._leave_button): buttons.append(screen._leave_button)
			bounds(screen,buttons,"event "+event_id)
			# A smaller story viewport must retain the whole story through scrolling.
			var story: ScrollContainer = screen._body_scroll
			story.scroll_vertical = ceili(story.get_v_scroll_bar().max_value)
			await frames(2)
			check(story.scroll_vertical>0 or story.size.y+1>=screen._body.size.y,"event story remains readable: "+event_id)
			story.scroll_vertical = 0
			if event_id=="delete_poems":
				screen._restore_choices("字袋中没有符合条件的字，请重新选择。")
				await frames()
				var restored: Array[Control] = []
				restored.assign(screen._buttons)
				restored.append(screen._notice)
				if is_instance_valid(screen._leave_button): restored.append(screen._leave_button)
				bounds(screen,restored,"event error notice")
				screen._restore_choices(); await frames()
			await capture(screen,event_id)
		run = fresh("shop")
		screen = await open_screen("shop_screen",{"room_run":true})
		var shop_controls: Array = [screen._hud.action_button,screen._hud.secondary_button,screen._hud.tertiary_button,screen._hud.status_label]
		shop_controls.append_array(screen._hud.find_children("*","Label",true,false).filter(func(c):return c.text==screen._hud.heading))
		bounds(screen,shop_controls,"shop actions and header")
		await capture(screen,"shop")
		run = fresh("battle"); run.begin_live_battle(); run.finish_live_battle(true)
		screen = await open_screen("reward_screen",{"room_run":true,"node":run.node})
		var reward_controls: Array = [screen._hud.action_button,screen._hud.secondary_button,screen._hud.status_label]
		reward_controls.append_array(screen._hud.find_children("*","Label",true,false).filter(func(c):return c.text==screen._hud.heading))
		bounds(screen,reward_controls,"reward actions and header")
		await capture(screen,"reward")
		run = fresh("rest")
		screen = await open_screen("rest_screen",{"room_run":true})
		bounds(screen,screen.find_children("*","Button",true,false),"rest actions")
		await capture(screen,"rest")
		results.append({"id":profile.id,"checks":checks,"failures":failures.slice(start_failures)})
		print("[mobile_layout] ",profile.id," failures=",failures.size()-start_failures)
		Router.current = null; Router.host = null
		_viewport.queue_free(); await frames(2)
	ScreenLayout.preview_density = 0.0; ScreenLayout.preview_window_size = Vector2i.ZERO; ScreenLayout.preview_insets = Vector4.ZERO
	Music.stop()
	var report := FileAccess.open("user://mobile-layout-results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"profiles":results},"\t")); report.close()
	for message: String in failures: print("FAIL ",message)
	print("[mobile_layout_matrix] CHECKS=%d FAIL=%d" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
