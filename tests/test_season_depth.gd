extends TestCase
## 第四輪：年度宿敵、本季目標、搶人大戰、選手風格標籤。


func _session(seed_v: int = 11, club_id: String = "crimson_tide_gaming") -> GameSession:
	var s := GameSession.new()
	var errs = s.new_game(MODULE_DIR, seed_v, club_id)
	check(errs.is_empty(), "new game ok")
	s.manual_draft = false
	return s


func test_rival_is_same_league_and_stable() -> void:
	var s := _session()
	var w := s.world
	var r := Rivalry.current(w)
	check(not r.is_empty(), "a rival is picked")
	var rc: Club = w.clubs[r["club_id"]]
	check(rc.id != s.club().id, "rival is another club")
	check_eq(rc.league_id, s.club().league_id, "rival plays in the same league")
	check_eq(Rivalry.current(w)["club_id"], rc.id, "rival does not change mid-season")
	check(Rivalry.is_rival(w, rc.id), "is_rival agrees")


func test_rival_series_swings_morale_and_board() -> void:
	var s := _session()
	var w := s.world
	var me := s.club()
	var opp: Club = w.clubs[Rivalry.current(w)["club_id"]]
	me.board_confidence = 50.0
	var p: Player = w.players[me.roster[0]]
	p.morale = 50.0
	Rivalry.on_series(w, me, opp, {"winner": me.id, "score": {me.id: 2, opp.id: 0}})
	check(me.board_confidence > 50.0, "beating the rival lifts the board")
	check(p.morale > 50.0, "beating the rival lifts morale")
	check_eq(int(Rivalry.current(w)["w"]), 1, "rival win counted")
	var b := me.board_confidence
	Rivalry.on_series(w, opp, me, {"winner": opp.id, "score": {me.id: 1, opp.id: 2}})
	check(me.board_confidence < b, "losing to the rival hurts the board")
	check_eq(int(Rivalry.current(w)["l"]), 1, "rival loss counted")
	# 不是宿敵的比賽沒有額外效果
	var other: Club = null
	for cid in w.leagues[me.league_id].club_ids:
		if cid != me.id and cid != opp.id:
			other = w.clubs[cid]
			break
	b = me.board_confidence
	Rivalry.on_series(w, me, other, {"winner": me.id, "score": {me.id: 2, other.id: 0}})
	check_eq(me.board_confidence, b, "ordinary match has no rivalry effect")


func test_season_goals_generated_and_evaluated() -> void:
	var w := make_world(7, "harbor_lights")
	var g := SeasonGoals.current(w)
	check_eq(g["list"].size(), 3, "three season goals")
	var ids: Array = g["list"].map(func(x): return x["id"])
	check("rank" in ids, "rank goal")
	check("playoffs" in ids or "intl" in ids, "stage goal")
	var guard := 0
	while w.phase != WorldState.PHASE_OFFSEASON and guard < 500:
		WorldSimulator.advance_day(w)
		guard += 1
	var msg := w.inbox.filter(func(m): return m.get("kind") == "season_goals")
	check_eq(msg.size(), 1, "goal review message sent")
	for goal in ManagerCareer.data(w)["goals"]["list"]:
		check(goal.has("met"), "goal %s evaluated" % goal["id"])
	check(w.log.of_type("season_goals").size() == 1, "logged")


func test_goal_results_move_board_confidence() -> void:
	var s := _session()
	var w := s.world
	var me := s.club()
	SeasonGoals.current(w)
	me.history.append({"year": w.year, "league_id": me.league_id, "tier": 1, "position": 1, "champion": true, "worlds": "champion"})
	me.board_confidence = 50.0
	for goal in ManagerCareer.data(w)["goals"]["list"]:
		goal["id"] = "rank"
		goal["target"] = 3
	var r := SeasonGoals.evaluate(w)
	check_eq(int(r["met"]), 3, "all goals met")
	check_eq(me.board_confidence, 65.0, "+5 per goal")
	me.history[-1]["position"] = 8
	me.board_confidence = 50.0
	r = SeasonGoals.evaluate(w)
	check_eq(int(r["met"]), 0, "all goals failed")
	check_eq(me.board_confidence, 35.0, "-5 per goal")


func _star_free_agent(w: WorldState) -> Player:
	var p: Player = w.players[w.free_agents[0]]
	for sk in Attr.SKILLS:
		p.skills[sk] = 80.0
	p.goals = []
	p.home_region = w.human_club().region
	for c in w.clubs.values():
		c.wage_budget += 5000000
		c.cash += 5000000
	return p


func test_bidding_war_creates_message_and_raise_signs() -> void:
	var s := _session()
	var w := s.world
	var me := s.club()
	var p := _star_free_agent(w)
	var demand := TransferMarket.wage_demand(w, p)
	var r := BiddingWar.maybe_start(w, me, p, 0, demand, 2, "rotation", true)
	check(r.get("bidding", false), "a rival club joins the bidding")
	if not r.get("bidding", false):
		return
	var msg := s.find_message(r["message_id"])
	check_eq(msg["kind"], "bidding", "bidding message in inbox")
	check("bid:raise" in msg["options"] and "bid:withdraw" in msg["options"], "raise / withdraw options")
	check(int(msg["raise_salary"]) > demand, "raise costs more than the original offer")
	var out := s.respond_to_message(msg["id"], "bid:raise")
	check(out.get("signed", false), "raise wins the player")
	check_eq(p.club_id, me.id, "player joined us")
	check_eq(p.contract.salary, int(msg["raise_salary"]), "signed at the raised salary")


func test_bidding_war_withdraw_lets_rival_sign() -> void:
	var s := _session()
	var w := s.world
	var me := s.club()
	var p := _star_free_agent(w)
	var r := BiddingWar.maybe_start(w, me, p, 0, TransferMarket.wage_demand(w, p), 2, "rotation", true)
	if not r.get("bidding", false):
		check(false, "bidding war expected")
		return
	var msg := s.find_message(r["message_id"])
	var out := s.respond_to_message(msg["id"], "bid:withdraw")
	check(not out.get("signed", true), "we did not sign him")
	check_eq(p.club_id, msg["rival_id"], "rival signed the player")
	check(not w.free_agents.has(p.id), "no longer a free agent")


func test_weak_players_do_not_start_bidding() -> void:
	var s := _session()
	var w := s.world
	var p: Player = w.players[w.free_agents[0]]
	for sk in Attr.SKILLS:
		p.skills[sk] = 40.0
	check(BiddingWar.maybe_start(w, s.club(), p, 0, 999999, 2, "starter", true).is_empty(), "no bidding war for weak players")
	check_eq(BiddingWar.entry_chance(90.0), 0.7, "entry chance capped")


func test_archetype_labels_standout_skill() -> void:
	var w := make_world(3)
	var p: Player = w.players.values()[0]
	for sk in Attr.SKILLS:
		p.skills[sk] = 60.0
	p.champion_pool = {}
	check_eq(PlayerArchetype.of(p)["name"], "全能型", "flat profile is an all-rounder")
	p.skills["clutch"] = 85.0
	check_eq(PlayerArchetype.of(p)["name"], "大賽型", "standout clutch")
	p.skills["shotcalling"] = 95.0
	check_eq(PlayerArchetype.of(p)["name"], "指揮官", "largest standout wins")
