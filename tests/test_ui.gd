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
