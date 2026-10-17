extends Node
## 首领追逐模拟：每个主题若干张游戏用图，比较初见 / 熟图玩家被追上前拿到多少内容
## 用法：godot --headless --path . src/tools/chase_sim.tscn
const MAPS := 60          ## 每个主题的图数
const ROLLS := 8          ## 每张图掷几次首领骰子（概率追击）

func _ready() -> void:
	var themes := ["墨池", "熔铸坊", "潮汐渠", "雷池"]
	print("主题	初见(概率)	熟图(概率)	初见(旧匀加速)	初见(概率+旧节奏)	低于45%的图	初见被追上率	不追全拿步数	惊动步	起身步")
	for th in themes:
		var fog := 0.0; var omni := 0.0; var det := 0.0; var caught := 0.0; var full := 0.0
		var stir := 0.0; var rise := 0.0; var n := 0; var old := 0.0; var low := 0
		for i in MAPS:
			var m := MapGen.generate(1000 + i * 37, th)
			if m.is_empty():
				continue
			n += 1
			var c := float(m.content.size())
			var per := 0.0
			for r in ROLLS:
				var a := MapGen.sim(m, "fog", true, m.terr, MapGen.SLIDE_N, i * 101 + r)
				var b := MapGen.sim(m, "omni", true, m.terr, MapGen.SLIDE_N, i * 101 + r + 50)
				fog += a.got / c; omni += b.got / c; per += a.got / c
				caught += 1.0 if a.caught else 0.0
				stir += float(a.stir if a.stir != null else 0); rise += float(a.rise if a.rise != null else 0)
			if per / ROLLS < 0.45:
				low += 1
			# 旧节奏（约第 12 步惊动、缓冲 4 步）+ 概率追击，用来区分"节奏"和"概率"各自的影响
			var mo := m.duplicate()
			mo.wake = int(m.wake) + 3
			mo.buffer = 4
			for r in ROLLS:
				old += MapGen.sim(mo, "fog", true, m.terr, MapGen.SLIDE_N, i * 101 + r).got / c
			det += MapGen.sim(m, "fog", true, m.terr, MapGen.SLIDE_N).got / c
			full += MapGen.sim(m, "omni", false, m.terr, MapGen.SLIDE_N).t
		var k := float(n * ROLLS)
		print("%s	%d%%	%d%%	%d%%	%d%%	%d/%d	%d%%	%d	%.1f	%.1f" % [th, round(fog / k * 100), round(omni / k * 100), round(det / n * 100), round(old / k * 100), low, n,
			round(caught / k * 100), round(full / n), stir / k, rise / k])
	get_tree().quit()
