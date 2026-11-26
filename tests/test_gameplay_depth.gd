extends TestCase
## 玩法層面的改進：關鍵抉擇、秘密武器與對手研究、經理生涯。


func _engine(w: WorldState, seed: int = 3) -> MatchEngine:
	var ids: Array = w.leagues.values().filter(func(l): return l.tier == 1)[0].club_ids
	var a = TeamContext.from_club(w, w.clubs[ids[0]])
	var b = TeamContext.from_club(w, w.clubs[ids[1]])
	var ds := DraftSession.new(a, b, w.champions, w.patch, SimRng.new(seed))
	ds.run_all()
	var e := MatchEngine.new(a, b, ds.result(), w.champions, SimRng.new(seed), true)
	e.manual_side = "blue"
	e.begin()
	return e


func test_baron_decision_card() -> void:
	var w = make_world(21)
	var e = _engine(w)
	e.run_until(21)
	if e.is_over():
		return
	e.next_baron = e.minute
	e.baron_until = {"blue": -1, "red": -1}
	var ds = MatchDecisions.available(e, "blue")
	check(not ds.is_empty() and ds[0]["id"] == "baron", "baron decision offered first: %s" % str(ds.map(func(d): return d["id"])))
	if ds.is_empty():
		return
	check_eq(ds[0]["options"].size(), 3, "three baron options")
	var before_b: int = e.barons["blue"] + e.barons["red"]
	var r = MatchDecisions.resolve(e, "blue", "baron", "trade")
	check(r["ok"], "resolved")
	check_eq(e.barons["red"] + e.barons["blue"], before_b + 1, "someone takes baron on a trade")
	check(e.events.any(func(x): return x["type"] == "decision"), "decision event logged")
	check(not MatchDecisions.available(e, "blue").any(func(d): return d["id"] == "baron"), "each decision only once per game")
	check(not MatchDecisions.resolve(e, "blue", "baron", "rush")["ok"], "cannot reuse a decision")


func test_behind_and_tilt_cards() -> void:
	var w = make_world(22)
	var e = _engine(w, 5)
	e.run_until(19)
	if e.is_over():
		return
	for u in e.units["blue"]:
		u["gold"] = 3000.0
		u["dead_until"] = 0  # 這個測試只關心經濟落後，不受當下團戰陣亡影響
	for u in e.units["red"]:
		u["gold"] = 6000.0
	e.units["blue"][2]["deaths"] = 6
	e.units["blue"][2]["kills"] = 0
	var ids: Array = MatchDecisions.available(e, "blue").map(func(d): return d["id"])
	check("behind" in ids, "behind card when far behind: %s" % str(ids))
	check("tilt" in ids, "tilt card for a player with 6 deaths: %s" % str(ids))
	var u: Dictionary = e.units["blue"][2]
	var f0 = float(u["form"])
	MatchDecisions.resolve(e, "blue", "tilt", "comfort")
	check(float(u["form"]) >= f0, "comforting does not hurt form")


func test_ai_makes_decisions_in_simulated_games() -> void:
	var w = make_world(23)
	var ids: Array = w.leagues.values().filter(func(l): return l.tier == 1)[0].club_ids
	var n := 0
	for i in 30:
		var s = SeriesSim.play(TeamContext.from_club(w, w.clubs[ids[i % 4]]), TeamContext.from_club(w, w.clubs[ids[4 + i % 4]]), 1, w.champions, w.patch, SimRng.new(i), false)
		n += s["games"][0]["decisions"].size()
	check(n >= 10, "AI shot-callers make clutch decisions (%d in 30 games)" % n)


func test_live_decide_through_session() -> void:
	var s := GameSession.new()
	s.new_game(MODULE_DIR, 5, "harbor_lights")
	var guard := 0
	while s.advance_day() and guard < 80:
		guard += 1
	var series = s.begin_match()
	var ds = series.new_draft()
	ds.run_all()
	var snap = s.start_live_game(ds)
	var decided := false
	var g2 := 0
	while not snap.get("done", false) and g2 < 12:
		g2 += 1
		if not snap.get("decisions", []).is_empty():
			var d: Dictionary = snap["decisions"][0]
			var r = s.live_decide(d["id"], d["options"][-1]["id"])
			check(r["ok"], "live decision accepted")
			decided = true
			snap = r["snap"]
			if snap.get("done", false):
				break
		snap = s.live_continue("")
	check(snap.get("done", false), "game finishes after decisions")
	check(decided, "at least one clutch decision offered during a live game")


func test_pick_history_and_secret_weapon() -> void:
	var w = make_world(24)
	var ids: Array = w.leagues.values().filter(func(l): return l.tier == 1)[0].club_ids
	var a: Club = w.clubs[ids[0]]
	var b: Club = w.clubs[ids[1]]
	var s = SeriesSim.play(TeamContext.from_club(w, a), TeamContext.from_club(w, b), 3, w.champions, w.patch, SimRng.new(4), false)
	LeagueEngine.record_picks(w, s)
	check(not a.pick_history.is_empty(), "picks recorded")
	var ta = TeamContext.from_club(w, a)
	var cid: String = a.pick_history.keys()[0]
	check(ta.exposure(cid) > 0.0, "played champion is exposed")
	# 秘密武器：熟練度高、沒用過的英雄 → 出場時有事件
	var mid: Player = w.players[a.lineup["MID"]]
	var pocket := ""
	for c in mid.top_champions(8):
		if not a.pick_history.has(c) and w.champions.has(c) and "MID" in w.champions[c].roles:
			pocket = c
			break
	check(pocket != "", "found an unplayed MID champion")
	if pocket == "":
		return
	mid.champion_pool[pocket] = 90.0
	var t1 = TeamContext.from_club(w, a)
	var t2 = TeamContext.from_club(w, b)
	t1.forced_picks = {"MID": pocket}
	var ds := DraftSession.new(t1, t2, w.champions, w.patch, SimRng.new(9))
	ds.run_all()
	check_eq(ds.result()["picks"]["blue"].get("MID", ""), pocket, "forced pocket pick")
	var e := MatchEngine.new(t1, t2, ds.result(), w.champions, SimRng.new(9), true)
	e.begin()
	check(e.events.any(func(x): return x["type"] == "surprise"), "secret weapon announced")


func test_exposed_champions_get_banned_more() -> void:
	var w = make_world(25)
	var ids: Array = w.leagues.values().filter(func(l): return l.tier == 1)[0].club_ids
	var a: Club = w.clubs[ids[0]]
	var b: Club = w.clubs[ids[1]]
	var adc: Player = w.players[a.lineup["ADC"]]
	var c2: String = adc.top_champions(3)[2]
	var banned_hidden := 0
	var banned_exposed := 0
	for i in 20:
		for exposed in [false, true]:
			a.pick_history = {"x": 1.0}
			if exposed:
				a.pick_history[c2] = 6.0
			var ds := DraftSession.new(TeamContext.from_club(w, b), TeamContext.from_club(w, a), w.champions, w.patch, SimRng.new(100 + i))
			ds.run_all()
			if c2 in ds.result()["bans"]["blue"]:
				if exposed:
					banned_exposed += 1
				else:
					banned_hidden += 1
	check(banned_exposed > banned_hidden, "a champion seen often is banned more (%d vs %d of 20)" % [banned_exposed, banned_hidden])


func test_manager_fired_and_rehired() -> void:
	var w = make_world(26, "harbor_lights")
	var me: Club = w.human_club()
	me.history.append({"year": w.year, "league_id": me.league_id, "tier": 1, "position": 8, "champion": false, "worlds": ""})
	me.board_confidence = 10.0
	ManagerCareer.season_review(w)
	var msg: Dictionary = {}
	for m in w.inbox:
		if m.get("kind") == "fired":
			msg = m
	check(not msg.is_empty(), "fired message")
	if msg.is_empty():
		return
	check(msg["options"].size() >= 1, "at least one club offers a job")
	var target: String = msg["options"][0].trim_prefix("job:")
	var r = ManagerCareer.respond(w, msg, msg["options"][0])
	check(r.get("switched", false), "switched club")
	check_eq(w.human_club_id, target, "human club updated")
	check(w.clubs[target].is_human and not me.is_human, "is_human flags swapped")
	check_eq(int(w.manager["fired"]), 1, "firing recorded")
	# 存讀檔保留生涯
	var w2 = SaveSystem.from_json(SaveSystem.to_json(w))
	check_eq(w2.human_club_id, target, "save keeps new club")
	check(not w2.manager.is_empty(), "save keeps manager career")


func test_manager_job_offer_after_overperforming() -> void:
	var w = make_world(27, "harbor_lights")
	var me: Club = w.human_club()
	me.reputation = 20.0
	ManagerCareer.data(w)["reputation"] = 80.0
	me.history.append({"year": w.year, "league_id": me.league_id, "tier": 1, "position": 1, "champion": true, "worlds": ""})
	me.board_confidence = 80.0
	ManagerCareer.season_review(w)
	var offers = w.inbox.filter(func(m): return m.get("kind") == "job_offer")
	check(offers.size() >= 1, "bigger clubs want to hire a champion manager")
	if offers.is_empty():
		return
	var before = me.board_confidence
	ManagerCareer.respond(w, offers[0], "job:decline")
	check(me.board_confidence > before, "declining raises board confidence")
	check_eq(w.human_club_id, me.id, "still at the same club")
