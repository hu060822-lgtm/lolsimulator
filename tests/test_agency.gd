extends TestCase
## 選手是有獨立意志的角色：同樣的處境，不同目標/個性的選手反應不同。


func _young_ambitious_bench(w: WorldState, club: Club) -> Player:
	var p = PlayerGenerator.generate(w, w.rng, club.region, "MID", 0.6, true)
	p.birth_year = w.year - 19
	p.personality["ambition"] = 90.0
	p.personality["loyalty"] = 30.0
	p.goals = PlayerGenerator.derive_goals(p, w.year)
	# 讓他是隊上最強的中路，因此他「認為自己應該先發」
	for s in p.skills:
		p.skills[s] = 85.0
	w.players[p.id] = p
	TransferMarket._move(w, p, null, club, 0)
	p.contract = Contract.new()
	p.contract.club_id = club.id
	p.contract.salary = TransferMarket.wage_demand(w, p)
	p.contract.end_year = w.year + 2
	return p


func test_benched_prodigy_requests_transfer() -> void:
	var w = make_world(42, "harbor_lights")
	var club: Club = w.clubs["harbor_lights"]
	var p = _young_ambitious_bench(w, club)
	w.phase = WorldState.PHASE_REGULAR
	for week in 12:
		p.season_stats["team_games"] += 2  # 球隊出賽，但他沒有上場
		CareerAgent.weekly(w, p)
	print("  sat=%s happiness=%.2f weeks_unhappy=%d goals=%s" % [p.satisfaction, p.happiness, p.weeks_unhappy, p.goals])
	check(p.transfer_requested, "benched ambitious youngster eventually asks to leave (happiness %.2f)" % p.happiness)
	var msgs = w.inbox.filter(func(m): return m["player_id"] == p.id)
	check(msgs.size() >= 1, "the manager is told (inbox)")
	var logged = w.log.of_type("transfer_request")
	check(logged.size() >= 1 and not logged[0]["causes"].is_empty(), "request is logged with causes")


func test_loyal_veteran_rejects_bigger_offer_abroad() -> void:
	var w = make_world()
	var home: Club = w.clubs["jade_dragons"]
	var abroad: Club = w.clubs["atlas_vanguard"]
	var vet: Player = w.players[home.lineup["TOP"]]
	vet.birth_year = w.year - 28
	vet.personality["loyalty"] = 95.0
	vet.personality["ambition"] = 40.0
	vet.goals = ["RETIRE_AT_CLUB"]
	var merc: Player = w.players[home.lineup["MID"]]
	merc.personality["loyalty"] = 10.0
	merc.goals = ["MONEY"]
	var u_vet_abroad: float = TransferMarket.contract_utility(w, vet, abroad, int(TransferMarket.wage_demand(w, vet) * 1.4), "starter")["utility"]
	var u_vet_home: float = TransferMarket.contract_utility(w, vet, home, TransferMarket.wage_demand(w, vet), "starter")["utility"]
	var u_merc_abroad: float = TransferMarket.contract_utility(w, merc, abroad, int(TransferMarket.wage_demand(w, merc) * 1.4), "starter")["utility"]
	var u_merc_home: float = TransferMarket.contract_utility(w, merc, home, TransferMarket.wage_demand(w, merc), "starter")["utility"]
	print("  veteran: home %.2f vs abroad(+40%%) %.2f | mercenary: home %.2f vs abroad %.2f" % [u_vet_home, u_vet_abroad, u_merc_home, u_merc_abroad])
	check(u_vet_home > u_vet_abroad, "loyal veteran prefers staying for less money")
	check(u_merc_abroad > u_merc_home, "money-driven player prefers the bigger offer")


func test_broken_promise_costs_trust() -> void:
	var w = make_world(1, "harbor_lights")
	var club: Club = w.clubs["harbor_lights"]
	var p = _young_ambitious_bench(w, club)
	var before = p.trust_in_management
	CareerAgent.respond(w, p, "promise_playing_time")
	w.day += 50
	p.season_stats["team_games"] = 10
	p.season_stats["starts"] = 1
	CareerAgent.weekly(w, p)
	check(p.trust_in_management < before - 10.0, "broken promise reduces trust (%.1f -> %.1f)" % [before, p.trust_in_management])
	check(w.log.of_type("promise_broken").size() == 1, "broken promise is recorded")


func test_same_words_different_people() -> void:
	var w = make_world()
	var a: Player = w.players[w.clubs["iron_lotus"].lineup["ADC"]]
	var b: Player = w.players[w.clubs["iron_lotus"].lineup["SUPPORT"]]
	a.personality["temperament"] = 90.0
	b.personality["temperament"] = 10.0
	a.happiness = -0.3
	b.happiness = -0.3
	var ra = CareerAgent.respond(w, a, "demand_patience")
	var rb = CareerAgent.respond(w, b, "demand_patience")
	check(ra["effect"] > rb["effect"], "calm player tolerates 'be patient', hot-headed one does not")


func test_veterans_retire_and_youth_do_not() -> void:
	var w = make_world()
	var rng := SimRng.new(9)
	var old := 0
	var young := 0
	for i in 200:
		var p = PlayerGenerator.generate(w, rng, "EAST", "TOP", 0.5)
		p.birth_year = w.year - 33
		if CareerAgent.retirement_check(w, p, rng):
			old += 1
		p.birth_year = w.year - 20
		if CareerAgent.retirement_check(w, p, rng):
			young += 1
	check(old > 80 and young == 0, "33-year-olds often retire (%d/200), 20-year-olds don't (%d)" % [old, young])
