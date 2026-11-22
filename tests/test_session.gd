extends TestCase
## GameSession：玩家視角的完整流程（手動 BP、收件匣、轉會窗口、存檔槽位）。


func _session(manual: bool = true) -> GameSession:
	var s := GameSession.new()
	var errs = s.new_game(MODULE_DIR, 5, "harbor_lights")
	check(errs.is_empty(), "new game ok")
	s.manual_draft = manual
	return s


func test_manual_draft_blocks_until_match_played() -> void:
	var s = _session()
	var guard := 0
	while s.advance_day() and guard < 60:
		guard += 1
	check(s.has_match_ready(), "advance stops on match day")
	var day = s.world.day
	check(not s.advance_day(), "cannot skip a pending match")
	check_eq(s.world.day, day, "day did not move")
	var series = s.begin_match()
	check(series != null, "series created")
	var hs = s.human_side(series)
	var ds = series.new_draft()
	# 玩家每一步都採用分析師第一建議；AI 一方自動
	var guard2 := 0
	while not ds.is_done() and guard2 < 40:
		guard2 += 1
		if ds.current_side() == hs:
			var sug = ds.suggestions(hs, 1)[0]
			check(ds.can_apply(sug["champion"], sug["role"]), "suggestion is legal")
			ds.apply(sug["champion"], sug["role"], "test")
		else:
			ds.ai_step()
	check(ds.is_done(), "draft completes")
	s.play_game(ds)
	var r = s.finish_match()
	check(r["fixture"]["played"], "fixture recorded")
	check(s.advance_day(), "world continues after match")


func test_custom_club_replaces_weakest() -> void:
	var s := GameSession.new()
	var custom = {"id": "custom_phoenix", "name": "Rising Phoenix", "short_name": "RPX", "league_id": "ecl", "region": "EAST",
		"reputation": 35, "cash": 800000, "wage_budget": 600000, "fanbase": 20000, "philosophy": "balanced", "replace": "mountain_echo"}
	check(s.new_game(MODULE_DIR, 9, "", custom).is_empty(), "custom game starts")
	check(not s.world.clubs.has("mountain_echo"), "replaced club removed")
	check(s.club().id == "custom_phoenix" and LineupSelector.is_valid(s.world, s.club()), "custom club has a full lineup")
	check_eq(s.world.leagues["ecl"].fixtures.size(), 56, "schedule still complete")


func test_transfer_window_and_ai_offer_flow() -> void:
	var s = _session(false)
	var p_id: String = s.club().lineup["MID"]
	check(not s.bid(s.world.clubs["jade_dragons"].lineup["TOP"], 1, 1, 1, "starter")["accepted"], "no transfers mid-season")
	# 模擬 AI 報價抵達收件匣
	var buyer: Club = s.world.clubs["jade_dragons"]
	s.world.phase = WorldState.PHASE_OFFSEASON
	var p: Player = s.world.players[p_id]
	TransferMarket.make_transfer_offer(s.world, buyer, p, 900000, int(TransferMarket.wage_demand(s.world, p) * 1.6), 3, "starter")
	TransferMarket.make_transfer_offer(s.world, buyer, p, 900000, int(TransferMarket.wage_demand(s.world, p) * 1.6), 3, "starter")
	var offers = s.open_messages().filter(func(m): return m["kind"] == "transfer_offer")
	check_eq(offers.size(), 1, "duplicate offers are not spammed")
	var cash_before = s.club().cash
	var r = s.respond_to_message(offers[0]["id"], "accept_offer")
	if r["accepted"]:
		check(p.club_id == "jade_dragons" and s.club().cash == cash_before + 900000, "sale completes and fee is paid")
	else:
		check(p.club_id == s.world.human_club_id, "player who refuses stays")
	check(s.open_messages().filter(func(m): return m["kind"] == "transfer_offer").is_empty(), "offer resolved")


func test_save_slots_roundtrip() -> void:
	var s = _session(false)
	s.advance_days(10)
	check_eq(s.save_slot(3), OK, "save slot")
	var info = GameSession.slot_info(3)
	check(info.get("club", "") == "Harbor Lights", "slot metadata")
	var s2 := GameSession.new()
	check(s2.load_slot(3), "load slot")
	check_eq(s2.world.day, s.world.day, "same day after load")


func test_scouting_ranges_narrow_with_knowledge() -> void:
	var s = _session(false)
	var target: Player = s.world.players[s.world.clubs["atlas_vanguard"].lineup["ADC"]]
	var r0 = Scouting.range_of(s.world, target, "mechanics")
	Scouting.observe(s.world, target.id, 0.6)
	var r1 = Scouting.range_of(s.world, target, "mechanics")
	check(r1[1] - r1[0] < r0[1] - r0[0], "more knowledge -> narrower range (%s -> %s)" % [r0, r1])
	var own: Player = s.world.players[s.club().lineup["ADC"]]
	var ro = Scouting.range_of(s.world, own, "mechanics")
	check_eq(ro[0], ro[1], "own players are known exactly")
