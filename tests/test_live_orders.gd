extends TestCase
## 臨場指令：指定目標（物件／兵線）與換線。


func _ctx(w: WorldState, club_id: String, tag: String) -> TeamContext:
	var t = TeamContext.from_club(w, w.clubs[club_id])
	t.club_id = tag
	t.name = tag
	t.short_name = tag
	return t


func _games(w: WorldState, setup: Callable, n: int) -> Array:
	var out: Array = []
	for i in n:
		var a = _ctx(w, "northstar_esports", "A")
		var b = _ctx(w, "iron_lotus", "B")
		setup.call(a)
		var s = SeriesSim.play(a, b, 1, w.champions, w.patch, SimRng.new(100 + i))
		out.append(s["games"][0])
	return out


func _side_of_a(g: Dictionary) -> String:
	return "blue" if g["blue_club"] == "A" else "red"


func test_dragon_focus_takes_more_dragons() -> void:
	var w = make_world()
	var base := 0.0
	var focused := 0.0
	var n := 30
	for g in _games(w, func(a): pass, n):
		base += g["dragons"][_side_of_a(g)]
	for g in _games(w, func(a): a.focus = {"14": "dragon"}, n):
		focused += g["dragons"][_side_of_a(g)]
		check(g["events"].any(func(e): return e["type"] == "order" and "小龍" in e["text"]), "focus shows in the log")
	print("  dragons: base %.2f  focused %.2f" % [base / n, focused / n])
	check(focused > base, "focusing dragons secures more dragons")


## 從最後一格地圖紀錄讀出某方某路被摧毀的建築數。
func _lost(g: Dictionary, side: String, lane: String) -> int:
	return int(g["frames"][-1]["st"][side].get(lane, 0))


func test_lane_focus_pushes_that_lane() -> void:
	var w = make_world()
	var top_base := 0
	var top_focus := 0
	for g in _games(w, func(a): pass, 20):
		var enemy = "red" if _side_of_a(g) == "blue" else "blue"
		top_base += _lost(g, enemy, "top")
	for g in _games(w, func(a): a.focus = {"14": "top"}, 20):
		var enemy = "red" if _side_of_a(g) == "blue" else "blue"
		top_focus += _lost(g, enemy, "top")
	print("  enemy top structures lost: base %d  focused %d" % [top_base, top_focus])
	check(top_focus > top_base, "top focus takes more top-lane structures")


func test_lane_swap_moves_bot_duo_top_early() -> void:
	var w = make_world()
	var games = _games(w, func(a): a.lane_swap = true, 1)
	var g: Dictionary = games[0]
	var side = _side_of_a(g)
	var f: Dictionary = g["frames"][3]
	# 位置順序與 units 相同：TOP, JUNGLE, MID, ADC, SUPPORT
	var adc: Array = f["pos"][side][3]
	var top: Array = f["pos"][side][0]
	if int(adc[2]) == 1:
		check(adc[1] < 0.5 and adc[0] < 0.5, "ADC is in the top lane at minute 3 (%s)" % str(adc))
	if int(top[2]) == 1:
		check(top[1] > 0.5 and top[0] > 0.5, "top laner is in the bot lane at minute 3 (%s)" % str(top))
