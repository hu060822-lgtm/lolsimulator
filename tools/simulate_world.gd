## 多年世界模擬報告：godot --headless --path . -s tools/simulate_world.gd -- --years=10 --seed=7
extends SceneTree


func _init() -> void:
	var years := 10
	var world_seed := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--years="):
			years = int(a.substr(8))
		elif a.begins_with("--seed="):
			world_seed = int(a.substr(7))
	var w = WorldBuilder.build(DataModule.load_from_dir("res://data/modules/fictional_base"), world_seed)
	var start: int = w.year
	var t0 = Time.get_ticks_msec()
	WorldSimulator.advance_to_year(w, start + years)
	print("模擬 %d 個賽季，耗時 %.1f 秒\n" % [years, (Time.get_ticks_msec() - t0) / 1000.0])
	for s in w.history["seasons"]:
		var line = "%d  " % s["year"]
		for lid in s["leagues"]:
			var L: Dictionary = s["leagues"][lid]
			var mvp: String = w.players[L["mvp"]].handle if L["mvp"] != "" else "-"
			line += "%s 冠軍 %-20s MVP %-12s  " % [lid.to_upper(), w.clubs[L["champion"]].name, mvp]
		print(line)
	print("\n俱樂部冠軍數：")
	var clubs: Array = w.clubs.values()
	clubs.sort_custom(func(a, b): return a.titles > b.titles)
	for c in clubs:
		print("  %-20s 冠軍 %d  聲望 %.0f  現金 %d" % [c.name, c.titles, c.reputation, c.cash])
	print("\n退役 %d 人、轉會 %d 筆、現役選手 %d 人、英雄 %d 隻" % [w.history["retirements"].size(), w.history["transfers"].size(), w.active_players().size(), w.champions.size()])
	var legends: Array = w.players.values().filter(func(p): return p.career.get("titles", 0) >= 2)
	legends.sort_custom(func(a, b): return a.career["titles"] > b.career["titles"])
	print("\n多冠選手：")
	for p in legends.slice(0, 10):
		print("  %-12s %-8s 冠軍 %d  MVP %d  出賽 %d  %s" % [p.handle, p.primary_role, p.career["titles"], p.career.get("mvps", 0), p.career["games"], "已退役(%d)" % p.retired_year if p.retired else "現役"])
	quit()
