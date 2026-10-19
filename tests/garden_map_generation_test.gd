extends Node
var passed := 0
var failed := 0


func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)


func _ready() -> void:
	var source: Script = load("res://src/expedition/garden_layout.gd")
	var kinds := {}
	for theme: String in MapGen.THEME_ORDER:
		for seed_value in [5,11,83,310]:
			var m := MapGen.generate(seed_value,theme)
			check(m.has("layout"),"园林生成没有退回旧图：%s/%d" % [theme,seed_value])
			if not m.has("layout"): continue
			kinds[m.layout.kind] = true
			print("[GardenGen] ",theme," seed=",seed_value," tries=",m.tries," ",m.layout.kind," structures=",m.layout.structures.size())
			var valid := true
			for k in MapGen.N:
				valid = valid and (m.layout.walk_mask[k]==1)==(m.ink[k]==0)
			for structure in m.layout.structures:
				for k in structure.solid: valid = valid and m.ink[k]!=0 and m.layout.terrain_base[k]==2
				for k in structure.walk: valid = valid and m.ink[k]==0
			check(valid,"建筑实体、桥面、游廊与通行一致")
			check(MapGen._reach_ok(m,m.terr),"所有伏兵和门都阻挡时仍可到达关键地点")
			check(m.wake >= 7 and m.wake <= 10 and m.buffer >= 7 and m.buffer <= 10,"园林地图接入远程的首领惊动与起身节奏")
			var movers: Array = m.mech.keys().filter(func(k): return m.mech[k].kind in ["warp","hoist","wire","slide"])
			check(movers.size() >= 2 and movers.size() <= 3 and movers.all(func(k): return not m.layout.no_content.has(k) and (not m.mech[k].has("to") or not m.layout.no_content.has(m.mech[k].to))),"主题移动机关与落点避开园林建筑和通路净空")
			var clear := true
			for k in MapGen.N:
				if m.ink[k]!=0 or m.layout.bridges.has(k): continue
				var p := MapGen.rc(k)
				var point := Vector2(p.y+.5,p.x+.5)
				clear = clear and source.water_field(m,point)<0
				for n: int in MapGen.nbrs(k):
					if m.ink[n]!=0 or m.layout.bridges.has(n): continue
					var q := MapGen.rc(n)
					for i in 5: clear = clear and source.water_field(m,point.lerp(Vector2(q.y+.5,q.x+.5),i/4.0))<0
			check(clear,"所有允许的格心行走线保持干地")
			var mounted := true
			for k in m.node:
				if m.node[k].t not in ["休","市","谜"]: continue
				mounted = mounted and m.node[k].has("body_cell") and m.ink[k]==0 and m.ink[m.node[k].body_cell]!=0
			check(mounted,"功能设施实体退后，入口保留为可站立格")
			_check_courtyard(m,source)
	check(kinds.size()==3,"三种园林骨架均可生成")
	var a := MapGen.generate(11,"墨池")
	var b := MapGen.generate(11,"墨池")
	check(var_to_str(a)==var_to_str(b),"同种子含建筑与伏兵完整复现")
	for theme: String in MapGen.THEME_ORDER:
		var fallback := MapGen._garden_backup(0,theme,source,{})
		check(not fallback.is_empty() and fallback.layout.version=="garden_v2" and fallback.generation_report.curated_fallback,"候选耗尽仍有同主题园林保底："+theme)
		# Footprint changes can invalidate only one member of a backup pool.
		# Checking the member chosen by request 0 alone misses that failure.
		for seed_value in MapGen.GARDEN_BACKUPS[theme]:
			var builder := MapGen.Builder.new(seed_value,theme)
			builder.garden = source.plan(seed_value,theme)
			var map := builder.run()
			var valid: bool = not map.has("fail") and map.pass
			if valid:
				MapGen.roll_wake(map)
				valid = MapGen.place_movers(map) and MapGen.assign_ambush(map)
			check(valid,"石坡占地更新后全部保底种子仍有效：%s/%d" % [theme,seed_value])
	print("[GardenGeneration] PASS=%d FAIL=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)


func _check_courtyard(map: Dictionary, source: Script) -> void:
	var packed := true
	var occupants: Array = map.layout.occupancy
	for i in occupants.size():
		for j in range(i+1,occupants.size()):
			var a: Dictionary = occupants[i]
			var b: Dictionary = occupants[j]
			if not a.joint.is_empty() and a.joint==b.joint: continue
			packed = packed and not a.clearance.intersects(b.clearance)
	check(packed,"建筑、功能设施与非共用墙体的真实外包范围不相交")
	var registered := true
	for k in map.node:
		if map.node[k].t not in ["起","休","市","谜","巢"]: continue
		registered = registered and occupants.any(func(e): return e.get("entry",-1)==k and e.asset==map.node[k].t)
	check(registered,"所有功能建筑与起终点都写入同一份占地登记")
	var backs_closed := true
	for entry in map.layout.structures:
		if entry.asset=="covered_walk":
			for k in entry.walk: backs_closed = backs_closed and map.ink[k-MapGen.W]!=0
	check(backs_closed,"游廊后座有实体背景与逻辑阻挡，不能穿过座凳")
	var edges: Array = []
	var reached: Array[Vector3] = []
	for run in map.layout.wall_runs:
		for n in range(run.points.size()-1): edges.append([run.points[n],run.points[n+1]])
	for entry in map.layout.structures:
		if entry.asset=="moon_gate": edges.append([entry.at+Vector3.LEFT,entry.at+Vector3.RIGHT])
	for edge in edges:
		for p: Vector3 in edge:
			if is_zero_approx(p.x) or is_zero_approx(p.z) or is_equal_approx(p.x,MapGen.W) or is_equal_approx(p.z,MapGen.H): reached.append(p)
	for pass_index in edges.size():
		for edge in edges:
			if reached.has(edge[0]) or reached.has(edge[1]):
				for point: Vector3 in edge:
					if not reached.has(point): reached.append(point)
	check(edges.all(func(e): return reached.has(e[0]) and reached.has(e[1])),"每段内墙经门翼或连接点接回外围，不出现孤立墙组")
	var wet_centers := true
	var swept := true
	for k in MapGen.N:
		var p := MapGen.rc(k)
		var a := Vector2(p.y+.5,p.x+.5)
		if map.layout.terrain_base[k]==1 and not map.layout.bridges.has(k):
			var field: float = source.water_field(map,a)
			if field<=0: print("[DryWaterCell] seed=",map.seed," k=",k," raw=",source._pond_field(map.layout,a)," final=",field)
			wet_centers = wet_centers and field>0
		if map.ink[k]!=0 or map.layout.bridges.has(k): continue
		for n: int in MapGen.nbrs(k):
			if map.ink[n]!=0 or map.layout.bridges.has(n): continue
			var q := MapGen.rc(n)
			var b := Vector2(q.y+.5,q.x+.5)
			var side := (b-a).orthogonal()*.18
			for step in 5:
				for sign_value in [-1.0,1.0]: swept = swept and source.water_field(map,a.lerp(b,step/4.0)+side*sign_value)<0
	check(wet_centers,"逻辑水格的格心确实是水面，没有干地假封路")
	check(swept,"实际通行带具有宽度，桥头与凹岸不会切入脚下")
