extends TestCase


func _season(w: WorldState) -> void:
	var guard := 0
	while w.phase != WorldState.PHASE_OFFSEASON and guard < 500:
		WorldSimulator.advance_day(w)
		guard += 1


func test_tier2_leagues_exist() -> void:
	var w = make_world()
	var tiers := {}
	for lg in w.leagues.values():
		tiers[lg.tier] = int(tiers.get(lg.tier, 0)) + 1
		for cid in lg.club_ids:
			check(LineupSelector.is_valid(w, w.clubs[cid]), "%s fields a lineup" % cid)
	check_eq(int(tiers.get(1, 0)), 2, "two tier-1 leagues")
	check_eq(int(tiers.get(2, 0)), 2, "two tier-2 leagues")
	check(w.international != null, "world championship defined")
	check(not w.leagues.has("worlds"), "worlds is not a domestic league")


func test_worlds_after_domestic_season() -> void:
	var w = make_world(31)
	var saw_worlds := false
	var guard := 0
	while w.phase != WorldState.PHASE_OFFSEASON and guard < 500:
		WorldSimulator.advance_day(w)
		if w.phase == WorldState.PHASE_INTERNATIONAL:
			saw_worlds = true
		guard += 1
	check(saw_worlds, "international phase happened")
	var s: Dictionary = w.history["seasons"][0]
	check(s.has("international"), "worlds recorded in history")
	var I: Dictionary = s["international"]
	check_eq(I["teams"].size(), 8, "4 teams from each tier-1 league")
	for cid in I["teams"]:
		check_eq(w.leagues[w.clubs[cid].league_id].tier, 1, "only tier-1 clubs qualify")
	check(w.clubs[I["champion"]].world_titles == 1, "champion credited")
	check(I["runner_up"] != "" and I["runner_up"] != I["champion"], "runner-up recorded")
	# 世界賽比賽的重要性更高
	var fx: Dictionary = w.international.fixtures[0]
	check(LeagueEngine.stakes_of(fx) >= 1.4, "worlds stakes are high")
	print("  worlds champion %s, runner-up %s, ended day %d" % [w.clubs[I["champion"]].short_name, w.clubs[I["runner_up"]].short_name, w.day])


func test_promotion_and_relegation() -> void:
	var w = make_world(41)
	_season(w)
	var s: Dictionary = w.history["seasons"][0]
	check_eq(s["movements"].size(), 2, "one swap per region")
	for mv in s["movements"]:
		var up: Club = w.clubs[mv["up"]]
		var down: Club = w.clubs[mv["down"]]
		check_eq(w.leagues[up.league_id].tier, 1, "%s promoted" % up.short_name)
		check_eq(w.leagues[down.league_id].tier, 2, "%s relegated" % down.short_name)
		check(w.leagues[up.league_id].club_ids.has(up.id), "promoted club listed in its new league")
		check(not w.leagues[mv["from"]].club_ids.has(up.id), "promoted club removed from old league")
	for lg in w.leagues.values():
		check_eq(lg.club_ids.size(), 8 if lg.tier == 1 else 6, "%s keeps its size" % lg.id)
	# 下一季賽程包含新成員
	WorldSimulator.advance_to_year(w, w.year + 1)
	var mv0: Dictionary = s["movements"][0]
	var lg1: League = w.leagues[mv0["to"]]
	check(lg1.fixtures.any(func(f): return f["home"] == mv0["up"] or f["away"] == mv0["up"]), "promoted club scheduled in tier 1")


func test_media_and_opinion() -> void:
	var w = make_world(51, "harbor_lights")
	WorldSimulator.advance_days(w, 45)
	check(w.news.size() > 0, "news generated")
	var hc: Club = w.human_club()
	check(not Media.club_news(w, hc.id).is_empty(), "human club appears in news")
	var moved = w.clubs.values().filter(func(c): return absf(c.opinion) > 1.0).size()
	check(moved > 4, "public opinion moves with results (%d clubs)" % moved)
	# 評價差 → 壓力上升
	var c: Club = w.clubs.values().filter(func(c): return not c.is_human)[0]
	var p: Player = w.players[c.roster[0]]
	c.opinion = -90.0
	var before = p.stress
	var lg: League = w.leagues[c.league_id]
	Media.weekly(w, c)
	check(p.stress > before or lg.standings[c.id]["w"] + lg.standings[c.id]["l"] < 2, "bad press raises stress")


func test_random_event_choice() -> void:
	var w = make_world(61, "harbor_lights")
	var hc: Club = w.human_club()
	var ev = RandomEvents.find_def(w, "equipment_failure")
	check(not ev.is_empty(), "event defined in module")
	RandomEvents.fire(w, hc, ev, null)
	var msg: Dictionary = w.inbox[-1]
	check_eq(msg["kind"], "event", "human gets an event message")
	check(msg["options"].has("ev:repair"), "event options offered")
	var cash = hc.cash
	var s := GameSession.new()
	s.world = w
	var r = s.respond_to_message(msg["id"], "ev:repair")
	check(msg["resolved"], "message resolved")
	check_eq(hc.cash, cash - 80000, "repair cost paid")
	check(r["note"] != "", "result note")
	# AI 俱樂部自動處理
	var ai: Club = w.clubs.values().filter(func(c): return not c.is_human)[0]
	var n = w.inbox.size()
	var fired := 0
	for i in 30:
		if RandomEvents.trigger_random(w, ai) != "":
			fired += 1
	check(fired > 0, "AI clubs get events")
	check_eq(w.inbox.size(), n, "AI events do not reach the player's inbox")


func test_save_keeps_phase3_state() -> void:
	var w = make_world(71, "harbor_lights")
	WorldSimulator.advance_days(w, 30)
	w.clubs["harbor_lights"].opinion = 12.5
	var copy = SaveSystem.from_json(SaveSystem.to_json(w))
	check_eq(copy.news.size(), w.news.size(), "news saved")
	check_eq(copy.event_defs.size(), w.event_defs.size(), "event definitions saved")
	check(copy.international != null, "worlds definition saved")
	check_eq(copy.clubs["harbor_lights"].opinion, 12.5, "opinion saved")
