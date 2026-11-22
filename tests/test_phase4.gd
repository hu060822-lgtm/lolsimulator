extends TestCase
## 第四階段：即時戰術指揮、對話、組織危機與法律事件、品牌。


func _session() -> GameSession:
	var s := GameSession.new()
	var errs = s.new_game(MODULE_DIR, 5, "harbor_lights")
	check(errs.is_empty(), "new game ok")
	s.manual_draft = true
	var guard := 0
	while s.advance_day() and guard < 80:
		guard += 1
	return s


func test_stepped_engine_matches_simulate() -> void:
	var w = make_world(91)
	var a = TeamContext.from_club(w, w.clubs["crimson_tide_gaming"])
	var b = TeamContext.from_club(w, w.clubs["jade_dragons"])
	var s1 := SeriesState.new(a, b, 1, w.champions, w.patch, SimRng.new(5))
	var g1 = s1.play_game(s1.new_draft())
	var s2 := SeriesState.new(a, b, 1, w.champions, w.patch, SimRng.new(5))
	var eng = s2.begin_game(s2.new_draft())
	var pauses := 0
	while not eng.is_over():
		var at = eng.next_shotcall()
		eng.run_until(at - 1 if at != -1 else MatchEngine.MAX_MINUTE)
		pauses += 1
		if pauses > 20:
			break
	var g2 = s2.finish_game(eng)
	check_eq(g2["winner"], g1["winner"], "same winner when paused without orders")
	check_eq(g2["duration"], g1["duration"], "same duration")
	check(pauses >= 2, "paused at shotcall points (%d)" % pauses)


func test_live_tactics_orders_apply() -> void:
	var s = _session()
	check(s.has_match_ready(), "match ready")
	var series = s.begin_match()
	var snap = s.start_live_game(series.new_draft())
	check(not snap.get("done", true), "paused before the first shotcall")
	check_eq(int(snap["next_call"]), 14, "first decision at 14'")
	check(int(snap["minute"]) == 13, "engine stopped at 13'")
	var orders := 0
	var guard := 0
	while not snap.get("done", false) and guard < 12:
		snap = s.live_continue("press")
		orders += 1
		guard += 1
	check(snap.get("done", false), "game finished")
	var g: Dictionary = snap["game"]
	var order_events = g["events"].filter(func(e): return e["type"] == "order")
	check(order_events.size() >= 1, "player orders appear in the match log")
	check_eq(series.games.size(), 1, "game recorded in series")
	s.finish_match()


func test_player_talks() -> void:
	var s = _session()
	var c = s.club()
	var p: Player = s.world.players[c.lineup["MID"]]
	p.season_stats["games"] = 5
	p.season_stats["rating_sum"] = 37.0  # 平均 7.4：表現很好
	var morale = p.morale
	var r = s.talk_to_player(p.id, "praise")
	check(r["ok"], "talk ok")
	check(p.morale > morale, "praise after good form lifts morale")
	check(r["tone"] > 0.3, "positive reply")
	var r2 = s.talk_to_player(p.id, "criticize")
	check(not r2["ok"], "cooldown: one talk per week")
	var q: Player = s.world.players[c.lineup["TOP"]]
	q.season_stats["games"] = 5
	q.season_stats["rating_sum"] = 37.0
	var trust = q.trust_in_management
	s.talk_to_player(q.id, "criticize")
	check(q.trust_in_management < trust, "criticizing a player in form costs trust")
	var f = s.talk_to_player(s.world.players[c.lineup["ADC"]].id, "future")
	check(f["reply"] != "", "contract talk gives an answer")


func test_team_talk_once_per_game() -> void:
	var s = _session()
	s.begin_match()
	check(s.can_team_talk(), "team talk available before game 1")
	var r = s.team_talk("calm")
	check(r["ok"] and r["reactions"].size() == 5, "five reactions")
	check(not s.can_team_talk(), "only once per game")
	check(not s.team_talk("fire_up")["ok"], "second talk refused")


func test_financial_crisis_and_board() -> void:
	var w = make_world(93, "harbor_lights")
	var hc: Club = w.human_club()
	hc.cash = -800000
	Organization.weekly(w, hc)
	var msgs = w.inbox.filter(func(m): return m.get("kind") == "crisis" and m.get("crisis") == "finance")
	check_eq(msgs.size(), 1, "human gets a financial crisis message")
	Organization.weekly(w, hc)
	check_eq(w.inbox.filter(func(m): return m.get("crisis") == "finance").size(), 1, "crisis not repeated")
	var s := GameSession.new()
	s.world = w
	var conf = hc.board_confidence
	s.respond_to_message(msgs[0]["id"], "crisis:investor")
	check_eq(hc.cash, -800000 + 1500000, "investor money arrives")
	check(hc.board_confidence < conf, "board confidence drops")
	# AI 俱樂部自動出售高薪選手
	var ai: Club = w.clubs["crimson_tide_gaming"]
	var n = ai.roster.size()
	ai.cash = -900000
	Organization.weekly(w, ai)
	check(ai.roster.size() < n or w.players.values().any(func(p): return p.transfer_requested and p.club_id == ai.id), "AI sells or lists a star")
	# 董事會信心過低 → 介入
	hc.board_confidence = 5.0
	var budget = hc.wage_budget
	Organization.weekly(w, hc)
	check(hc.wage_budget < budget, "board takeover cuts the budget")


func test_suspension_keeps_player_out() -> void:
	var w = make_world(95, "harbor_lights")
	var hc: Club = w.human_club()
	var pid: String = hc.lineup["MID"]
	var p: Player = w.players[pid]
	var ev = RandomEvents.find_def(w, "chat_ban")
	check(not ev.is_empty(), "legal event defined")
	RandomEvents.apply_option(w, hc, ev, "accept", p)
	check(not p.is_available(w.day + 1), "player suspended")
	check(not hc.lineup.values().has(pid), "suspended player removed from lineup")
	check(LineupSelector.is_valid(w, hc), "lineup still valid")
	w.day += 8
	LineupSelector.pick(w, hc)
	check(p.is_available(w.day + 1), "suspension ends")


func test_brand_campaign() -> void:
	var w = make_world(97, "harbor_lights")
	var hc: Club = w.human_club()
	var v0 = Finance.sponsor_value(hc, "main")
	var brand = hc.brand
	var cash = hc.cash
	var r = Organization.run_campaign(w, hc, "fan_fest")
	check(r["ok"], "campaign ran")
	check_eq(hc.cash, cash - 400000, "campaign cost")
	check(hc.brand > brand, "brand grows")
	check(Finance.sponsor_value(hc, "main") > v0, "stronger brand, bigger sponsor offers")
