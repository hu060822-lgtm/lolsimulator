extends TestCase
## UI 冒煙測試：每個畫面都能建立與刷新（不需要實際渲染）。


func test_every_screen_builds() -> void:
	var s := GameSession.new()
	s.new_game(MODULE_DIR, 3, "iron_lotus")
	var sh := Shell.new()
	sh.setup(s, null)
	for p in Shell.PAGES:
		sh.open(p[0])
		check(sh.page != null and sh.page_id == p[0], "opened %s" % p[0])
	sh.free()


func test_new_game_screen_builds() -> void:
	var s := GameSession.new()
	var scr := NewGameScreen.new()
	scr.setup(s, null)
	var total := 0
	for l in scr.leagues:
		scr._filter_league(str(l["id"]))
		total += scr.cards.size()
	check_eq(total, scr.clubs.size(), "every club is reachable from a league tab")
	check(scr.module_dir.ends_with("lol_world"), "real-esports module is the default")
	scr.free()


func test_draft_screen_plays_a_series() -> void:
	var s := GameSession.new()
	s.new_game(MODULE_DIR, 4, "iron_lotus")
	var guard := 0
	while s.advance_day() and guard < 60:
		guard += 1
	var sh := Shell.new()
	sh.setup(s, null)
	var d := DraftScreen.new()
	sh.open_screen(d, "draft")
	var steps := 0
	while not s.pending.is_empty() and steps < 10:
		steps += 1
		d._auto_draft()
		d._play()
		if d.series.is_done():
			d._finish()
		else:
			d._new_game()
	check(s.pending.is_empty(), "series finished through the UI")
	sh.free()


func test_draft_search_finds_bard() -> void:
	var s := GameSession.new()
	s.new_game("res://data/modules/lol_world", 4, "t_one")
	var bard: Champion = s.world.champions.get("bard")
	check(bard != null, "Bard is in the champion pool")
	check(DraftScreen.champ_matches(bard, "巴德"), "search by Chinese name")
	check(DraftScreen.champ_matches(bard, "bar"), "search by English prefix")
	check(not DraftScreen.champ_matches(bard, "雷玟"), "non-matching search")


func test_post_game_stats() -> void:
	var s := GameSession.new()
	s.new_game(MODULE_DIR, 4, "iron_lotus")
	var guard := 0
	while s.advance_day() and guard < 60:
		guard += 1
	var sh := Shell.new()
	sh.setup(s, null)
	var d := DraftScreen.new()
	sh.open_screen(d, "draft")
	d._auto_draft()
	d._play()
	var g: Dictionary = d.game
	check_eq(g["gold_curve"].size(), int(g["duration"]) + 1, "one gold sample per minute")
	for pid in g["players"]:
		check(int(g["players"][pid]["damage"]) > 0, "damage estimate recorded")
	var pg := PostGame.make(s, g)
	check(pg.get_child_count() >= 2, "post-game panel builds")
	pg.free()
	sh.free()


func test_series_score_hidden_until_game_ends() -> void:
	var s := GameSession.new()
	s.new_game(MODULE_DIR, 4, "iron_lotus")
	var guard := 0
	while s.advance_day() and guard < 60:
		guard += 1
	var sh := Shell.new()
	sh.setup(s, null)
	var d := DraftScreen.new()
	sh.open_screen(d, "draft")
	d._auto_draft()
	d._play()  # 測試環境不在場景樹內，會直接跳到結果
	check(d.score_label.text in ["1 : 0", "0 : 1"], "score updates when the game ends")
	d._open_center()  # 播放中（本局已模擬完）的計分列
	check_eq(d.score_label.text, "0 : 0", "score does not reveal the game being watched")
	sh.free()


func test_tokens_do_not_cross_map_for_trades() -> void:
	# 交換資源時只有那一路的選手與打野移動，不會整隊在一分鐘內橫越地圖再回來
	var s := GameSession.new()
	s.new_game("res://data/modules/lol_world", 4, "t_one")
	var guard := 0
	while s.advance_day() and guard < 60:
		guard += 1
	var sh := Shell.new()
	sh.setup(s, null)
	var d := DraftScreen.new()
	sh.open_screen(d, "draft")
	d._auto_draft()
	d._play()
	var fr: Array = d.game["frames"]
	var bounces := 0
	for i in range(1, mini(fr.size() - 1, 14)):
		for side in ["blue", "red"]:
			for k in [0, 2, 3, 4]:  # 打野以外
				var a = fr[i - 1]["pos"][side][k]
				var b = fr[i]["pos"][side][k]
				var c = fr[i + 1]["pos"][side][k]
				if int(a[2]) + int(b[2]) + int(c[2]) < 3:
					continue
				var ab = Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1]))
				var ac = Vector2(a[0], a[1]).distance_to(Vector2(c[0], c[1]))
				if ab > 0.7 and ac < 0.2:
					bounces += 1
	check(bounces <= 2, "laners rarely bounce across the map and back (%d)" % bounces)
	sh.free()
