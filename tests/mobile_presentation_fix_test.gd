extends Control
## 真实战斗布局、分层立绘和手机庭院预算回归。
var _pass := 0
var _fail := 0


func _ready() -> void:
	Settings.storage_path = "user://mobile_presentation_fix_test-settings.cfg"
	_run.call_deferred()


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _ok(value: bool, message: String) -> void:
	if value:
		_pass += 1
		print("PASS ", message)
	else:
		_fail += 1
		push_error(message)


func _run() -> void:
	var saved_motion := Settings.reduced_motion
	Settings.reduced_motion = false
	get_window().size = Vector2i(1980, 792)
	await _frames()
	GameState.start_new_run("v03")
	var data := EnemyData.new()
	data.id = "needle_wasp"
	data.name = "连针蜂"
	data.max_hp = 100
	data.moves = [EnemyMoveData.new()]
	var node := MapNodeData.new()
	node.enemies = [data]
	Router.host = self
	Router.goto("res://src/screens/battle_screen.gd", {"node": node, "seed": 7})
	var screen: Control = Router.current
	await _frames(16)
	var enemy: EnemyView = screen._enemy_widgets[0]
	var actor: Node2D = enemy._visual._character_actor
	var strip: StatusStrip = screen._player_status
	screen.battle.player.heat = 3
	screen.battle.player.energy = 2
	screen._refresh_all()
	await _frames()
	var badge: Control = strip.item_for("heat")
	_ok(is_equal_approx(badge.size.x, badge.size.y), "桌面玩家状态图标保持正方形")
	_ok(strip.get_global_rect().encloses(badge.get_global_rect()), "桌面状态图标完整落在预留状态行内")
	for window_size in [Vector2i(1980, 792), Vector2i(844, 390), Vector2i(640, 360)]:
		get_window().size = window_size
		await _frames(12)
		enemy.combatant.statuses.clear()
		screen._refresh_all()
		await _frames()
		var portrait_before := enemy._portrait.get_rect()
		var actor_before := actor.transform
		enemy.combatant.add_status("vulnerable", 2)
		screen._refresh_all()
		await _frames()
		_ok(enemy._portrait.get_rect().is_equal_approx(portrait_before) and actor.transform.is_equal_approx(actor_before), str(window_size) + " 新增异常不改变立绘位置或缩放")
		enemy.combatant.statuses.clear()
		screen._refresh_all()
		await _frames()
		_ok(enemy._portrait.get_rect().is_equal_approx(portrait_before), str(window_size) + " 异常消失不改变立绘占位")
		_ok(not strip.get_global_rect().intersects(screen._preview_panel.get_global_rect()) and not strip.get_global_rect().intersects(screen._enemy_panel.get_global_rect()), str(window_size) + " 玩家状态行与词效、敌人区域分离")
		enemy.combatant.hp = 1000
		enemy.combatant.max_hp = 1000
		screen._refresh_all()
		await _frames()
		var hp_label: Label = enemy._hp_number
		var ink_width := hp_label.get_theme_font("font").get_string_size(hp_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hp_label.get_theme_font_size("font_size")).x
		_ok(ink_width <= hp_label.size.x + 1 and enemy.get_global_rect().encloses(hp_label.get_global_rect()), str(window_size) + " 四位数敌方血量完整显示且不越过敌人区域")
		if OS.get_cmdline_user_args().has("--capture"):
			await _shot("fix-status-%d" % window_size.x)
		screen._open_deck()
		await _frames()
		var overlay: CollectionOverlay
		for child in screen.get_children():
			if child is CollectionOverlay: overlay = child
		var highest_z := 0
		for surface in actor.surfaces.values():
			var z := 0
			var item: CanvasItem = surface
			while item != null:
				z += item.z_index
				item = item.get_parent() as CanvasItem
			highest_z = maxi(highest_z, z)
		_ok(overlay.z_index > highest_z, str(window_size) + " 字袋弹窗遮住所有怪物分层部件")
		overlay._show_tab("words")
		if OS.get_cmdline_user_args().has("--capture"):
			await _shot("fix-overlay-%d" % window_size.x)
		overlay._close()
		await _frames()
	Router.current.queue_free()
	await _frames()
	Router.current = null
	Router.host = null
	await _check_courtyard()
	Settings.reduced_motion = saved_motion
	print("[mobile_presentation_fix_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail else 0)


func _shot(filename: String) -> void:
	await _frames()
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % filename)


func _check_courtyard() -> void:
	get_window().size = Vector2i(1920, 1080)
	Settings.reduced_motion = false
	await _frames()
	for mobile in [false, true]:
		var view := preload("res://src/title/courtyard_view.gd").new()
		view.mobile_quality = mobile
		add_child(view)
		await _frames(20)
		var stage: Node3D = view.stage
		if mobile:
			_ok(view.viewport.size.x <= 960 and view.viewport.size.y <= 540, "手机庭院渲染尺寸限制为 960×540，UI 分辨率保持独立")
			_ok(view.viewport.msaa_3d == Viewport.MSAA_DISABLED and view.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "手机背景按需以 30 帧更新，停用多重采样")
			_ok(stage.mirror_viewport == null and stage.contours == null and stage.atmosphere.fog_volumes.is_empty(), "手机不创建倒影、屏幕描边和体积雾额外通道")
			_ok(not stage.key.shadow_enabled and not stage.environment.ssao_enabled and stage.render_style.outlined_count == 0, "手机停用实时阴影、SSAO 和部件重复描边")
			_ok(stage.atmosphere.petals.multimesh.visible_instance_count == 28, "手机只更新 28 片可见落花")
			var before: float = stage.atmosphere.elapsed
			await _frames()
			_ok(stage.atmosphere.elapsed > before, "手机画质保留庭院动态")
			if OS.get_cmdline_user_args().has("--capture"):
				await _shot("fix-title-mobile")
			Settings.reduced_motion = true
			Settings.changed.emit()
			before = stage.atmosphere.elapsed
			await _frames()
			_ok(not view.is_processing() and stage.atmosphere.elapsed == before and not stage.atmosphere.petals.visible, "减少动效时手机背景停止持续渲染并隐藏落花")
			var duration := view.enter()
			_ok(duration == 0.05 and stage.inspection == 1.0 and view.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "减少动效入场仍请求绘制最终镜头")
			view.reset_camera()
			Settings.reduced_motion = false
			Settings.changed.emit()
			view.enter()
			await stage._motion.finished
			_ok(stage.inspection > 0.99 and view.is_processing(), "手机背景恢复更新并完成入场镜头")
			view.reset_camera()
			_ok(is_zero_approx(stage.inspection), "手机取消入场能恢复镜头")
			view.set_active(false)
			before = stage.atmosphere.elapsed
			Settings.changed.emit()
			view._layout()
			await _frames()
			_ok(not view.can_process() and stage.atmosphere.elapsed == before, "隐藏手机庭院停止整棵子树的动画处理")
			_ok(view.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "隐藏手机庭院不会因设置或布局变化重新渲染")
			view.set_active(true)
			_ok(view.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "恢复手机庭院立即请求首帧")
			await _frames()
			_ok(view.can_process() and view.is_processing() and stage.atmosphere.elapsed > before, "恢复手机庭院继续限频渲染和环境动画")
		else:
			_ok(stage.mirror_viewport != null and stage.key.shadow_enabled and view.viewport.msaa_3d == Viewport.MSAA_4X, "桌面保留原有倒影、阴影和抗锯齿")
			if OS.get_cmdline_user_args().has("--capture"):
				await _shot("fix-title-desktop")
		if DisplayServer.get_name() != "headless":
			var calls := 0
			var started := Time.get_ticks_usec()
			for i in 30:
				await get_tree().process_frame
				calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			print("COURTYARD mobile=%s size=%s peak_draw_calls=%d frame_ms=%.2f" % [mobile, view.viewport.size, calls, (Time.get_ticks_usec() - started) / 30000.0])
		view.queue_free()
		await _frames()
