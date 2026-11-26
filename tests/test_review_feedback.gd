extends TestCase
## 參考同類遊戲玩家評論所做的改進：打法互剋、賽前情報、快速模擬、勝負關鍵、談判回價、挖角、委派。


func _session() -> GameSession:
	var s := GameSession.new()
	var errs = s.new_game(MODULE_DIR, 5, "harbor_lights")
	check(errs.is_empty(), "new game ok")
	s.manual_draft = true
	return s


func _to_match_day(s: GameSession) -> void:
	var guard := 0
	while s.advance_day() and guard < 80:
		guard += 1


func test_style_cycle_is_consistent() -> void:
	for a in StyleMatchup.CYCLE:
		check_eq(StyleMatchup.counters_of(a).size(), 2, "%s has two counters" % a)
		check_eq(StyleMatchup.beaten_by(a).size(), 2, "%s beats two styles" % a)
		for b in StyleMatchup.CYCLE:
			check_eq(StyleMatchup.relation(a, b), -StyleMatchup.relation(b, a), "relation antisymmetric %s/%s" % [a, b])
			if StyleMatchup.relation(a, b) != 0:
				check(StyleMatchup.reason(a, b) != "", "reason text for %s vs %s" % [a, b])
	check_eq(StyleMatchup.relation("flexible", "teamfight"), 0, "flexible has no fixed relation")
	check_eq(StyleMatchup.relation("teamfight", "split_push"), 1, "teamfight beats split push")


func test_style_counter_changes_win_rate() -> void:
	var w = make_world(7)
	var ids: Array = w.leagues.values().filter(func(l): return l.tier == 1)[0].club_ids
	var a: Club = w.clubs[ids[0]]
	var b: Club = w.clubs[ids[1]]
	var good := 0
	var bad := 0
	var n := 80
	for i in n:
		# 同一組亂數，只差在打法：teamfight 剋 split_push、被 poke_siege 剋
		for pair in [["teamfight", "split_push"], ["teamfight", "poke_siege"]]:
			var ta = TeamContext.from_club(w, a)
			var tb = TeamContext.from_club(w, b)
			ta.plan = pair[0]
			tb.plan = pair[1]
			var s = SeriesSim.play(ta, tb, 1, w.champions, w.patch, SimRng.new(500 + i), false)
			if s["winner"] == a.id:
				if pair[1] == "split_push":
					good += 1
				else:
					bad += 1
	check(good > bad + n * 0.08, "countering the opponent's style wins clearly more (%d vs %d of %d)" % [good, bad, n])


func test_ai_clubs_have_signature_styles() -> void:
	var w = make_world(8)
	for c in w.clubs.values():
		ClubAI.choose_style(w, c)
	var styles := {}
	for c in w.clubs.values():
		if not c.is_human:
			check(c.tactics["plan"] in StyleMatchup.CYCLE, "AI style is a concrete plan")
			styles[c.tactics["plan"]] = true
	check(styles.size() >= 3, "AI clubs play different styles (%d)" % styles.size())


func test_briefing_and_quick_sim() -> void:
	var s = _session()
	_to_match_day(s)
	check(s.has_match_ready(), "match day reached")
	var b = s.match_briefing()
	check(not b.is_empty(), "briefing exists on match day")
	check(b["win_series"] > 0.0 and b["win_series"] < 1.0, "win probability in range: %.2f" % b["win_series"])
	check_eq(b["factors"].size(), 5, "five factors")
	check(b["recommended"] in StyleMatchup.counters_of(b["opp_plan"]), "recommended plan counters the opponent")
	# 改打建議打法後，打法因素變成優勢
	s.set_tactics(b["recommended"], 0.5)
	var b2 = s.match_briefing()
	check_eq(b2["relation"], 1, "recommended plan now counters the opponent")
	var style_f = b2["factors"].filter(func(f): return f["id"] == "style")[0]
	check(style_f["points"] > 0.0, "style factor positive")
	check(b2["win_series"] > b["win_series"] or b["relation"] == 1, "counter plan raises the estimate")
	# 快速模擬：直接打完並有勝負關鍵
	var day = s.world.day
	var r = s.auto_play_match()
	check(r["fixture"]["played"], "quick sim plays the fixture")
	check_eq(s.world.day, day, "quick sim does not skip days")
	var g: Dictionary = r["series"]["games"][0]
	var side := "blue" if g["blue_club"] == s.world.human_club_id else "red"
	check(g.has("style_edge"), "game result carries style edge")
	var keys = MatchBriefing.key_factors(g, side)
	check(keys.size() >= 1, "key factors listed: %s" % str(keys))
	check(s.advance_day(), "world continues")


func test_series_probability() -> void:
	check(absf(MatchBriefing.series_prob(0.5, 3) - 0.5) < 0.001, "even Bo3")
	check(MatchBriefing.series_prob(0.6, 5) > MatchBriefing.series_prob(0.6, 3), "longer series favours favourite")
	check(absf(MatchBriefing.series_prob(0.7, 1) - 0.7) < 0.001, "Bo1 equals game prob")


func test_contract_counter_offer() -> void:
	var w = make_world(9, "harbor_lights")
	var me: Club = w.human_club()
	var p: Player = null
	for pid in w.free_agents:
		p = w.players[pid]
		break
	check(p != null, "has a free agent")
	var low = int(TransferMarket.wage_demand(w, p) * 0.4)
	var r = TransferMarket.offer_contract(w, me, p, low, 2, "backup")
	check(not r["accepted"], "lowball refused")
	check(r.has("counter"), "agent makes a counter offer")
	var c: Dictionary = r["counter"]
	if not c.get("refuse", false):
		var r2 = TransferMarket.offer_contract(w, me, p, int(c["salary"]), 2, c["role_promise"])
		check(r2["accepted"], "accepting the counter works")


func test_seller_counter_fee() -> void:
	var w = make_world(10, "harbor_lights")
	var me: Club = w.human_club()
	me.cash = 50000000
	var target: Player = null
	for c in w.clubs.values():
		if c.id != me.id and not c.lineup.is_empty() and c.league_id == me.league_id:
			target = w.players[c.lineup.values()[0]]
			break
	var r = TransferMarket.make_transfer_offer(w, me, target, 1000, 50000, 2, "starter")
	check(not r["accepted"], "low fee refused")
	check(r.has("counter_fee") and int(r["counter_fee"]) > 1000, "seller names its price")


func test_poaching_and_blocked_move() -> void:
	var w = make_world(11, "harbor_lights")
	var me: Club = w.human_club()
	me.reputation = 20.0
	w.phase = WorldState.PHASE_OFFSEASON
	for c in w.clubs.values():
		if not c.is_human:
			c.cash = 80000000
	var star: Player = w.players[me.lineup["MID"]]
	star.goals = ["WIN_TITLES"]
	var found := {}
	for i in 60:
		Poaching.weekly(w)
		for m in w.inbox:
			if m.get("poach", false) and not m.get("resolved", false):
				found = m
		if not found.is_empty():
			break
	check(not found.is_empty(), "a bigger club bids for one of our starters")
	if found.is_empty():
		return
	var p: Player = w.players[found["player_id"]]
	p.goals = ["WIN_TITLES"]
	found["keen"] = Poaching.player_keen(w, p, w.clubs[found["from_club"]], int(found["salary"]))
	check(found["keen"], "title-hungry player wants the move")
	var before = p.happiness
	var r = TransferMarket.respond_to_offer(w, found, false)
	check(p.happiness < before, "blocking a wanted move upsets the player")
	check(r.has("note"), "rejection explains the consequence")


func test_delegation_handles_routine_only() -> void:
	var s = _session()
	var w = s.world
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "press", "text": "記者會", "resolved": false,
		"options": PressConference.ANSWERS.keys().map(func(k): return "press:" + k), "won": true, "opponent": ""})
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "info", "text": "通知", "resolved": false, "options": ["acknowledge"]})
	var pid: String = s.club().roster[0]
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "transfer_offer", "player_id": pid, "from_club": "x", "fee": 1, "text": "報價", "resolved": false, "options": ["accept_offer", "reject_offer"]})
	var n = s.delegate_routine(0)
	check_eq(n, 2, "assistant handles the two routine messages")
	var open = s.open_messages()
	check(open.any(func(m): return m["kind"] == "transfer_offer"), "transfer offer left for the player")
	check(not open.any(func(m): return m["kind"] == "press"), "press conference handled")
	s.set_delegate(true)
	check(Delegation.enabled(s.club()), "delegate setting saved on club")
	var d = s.club().to_dict()
	check(d["settings"]["delegate"], "setting serialised")
