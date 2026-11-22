extends TestCase
## 經紀人（抽成、加薪要求）與租借（費用、薪資分擔、歸隊）。


func _bench_player(w: WorldState, club: Club) -> Player:
	for pid in club.roster:
		if not club.lineup.values().has(pid):
			return w.players[pid]
	return null


func test_agent_is_stable_and_shapes_wages() -> void:
	var w = make_world(5)
	var p: Player = w.players.values()[0]
	check_eq(Agents.of(p)["name"], Agents.of(p)["name"], "same agent every time")
	for q in w.players.values().slice(0, 50):
		var f = Agents.wage_factor(q)
		check(f >= 0.9 and f <= 1.1, "wage factor in range")
	var names := {}
	for q in w.players.values():
		names[Agents.of(q)["name"]] = true
	check(names.size() >= 8, "players spread over many agencies")


func test_signing_pays_agent_fee() -> void:
	var w = make_world(6)
	var club: Club = w.clubs.values()[0]
	var fa: Player = w.players[w.free_agents[0]]
	var before = int(club.ledger.get("expense", {}).get("agent_fees", 0))
	var r = TransferMarket.offer_contract(w, club, fa, TransferMarket.wage_demand(w, fa) * 2, 2, "starter")
	check(r["accepted"], "generous offer accepted")
	var after = int(club.ledger.get("expense", {}).get("agent_fees", 0))
	check_eq(after - before, Agents.fee(fa, TransferMarket.wage_demand(w, fa) * 2), "agent commission charged")


func test_agent_demands_raise_for_underpaid_player() -> void:
	var w = make_world(7, "crimson_tide_gaming")
	w.phase = WorldState.PHASE_REGULAR
	var club: Club = w.human_club()
	var star: Player = w.players[club.lineup["MID"]]
	star.contract.salary = 1000
	star.contract.end_year = w.year + 2
	var msg := {}
	for i in 400:
		w.day += 7
		Agents.weekly(w, club)
		var found = w.inbox.filter(func(m): return m.get("kind") == "agent_raise" and not m.get("resolved", false))
		if not found.is_empty():
			msg = found[0]
			break
	check(not msg.is_empty(), "agent eventually asks for a raise")
	if msg.is_empty():
		return
	var r = Agents.resolve_raise(w, msg, true)
	check_eq(star.contract.salary, int(msg["new_salary"]), "raise applied: %s" % r["note"])
	check(msg["resolved"], "message resolved")


func test_loan_moves_player_and_splits_wages() -> void:
	var w = make_world(8, "crimson_tide_gaming")
	w.phase = WorldState.PHASE_PRESEASON
	var me: Club = w.human_club()
	var owner: Club = null
	var p: Player = null
	for c in w.clubs.values():
		if c.is_human or c.roster.size() <= Tuning.i("min_roster"):
			continue
		var b = _bench_player(w, c)
		if b and b.contract and Loans.player_willing(w, b, me) and not TransferMarket.import_blocked(w, me, b):
			owner = c
			p = b
			break
	check(p != null, "found a loanable bench player")
	if p == null:
		return
	var bill_me = TransferMarket.wage_bill(w, me)
	var bill_owner = TransferMarket.wage_bill(w, owner)
	var r = Loans.request(w, me, p, 0.5)
	check(r["accepted"], "loan accepted: %s" % r.get("reason", ""))
	check(me.roster.has(p.id) and not owner.roster.has(p.id), "player moved to borrower")
	check(owner.loaned_out.has(p.id) and p.club_id == me.id, "owner keeps the contract")
	var half = int(p.contract.salary * 0.5)
	check_eq(TransferMarket.wage_bill(w, me) - bill_me, half, "borrower pays its share")
	check_eq(bill_owner - TransferMarket.wage_bill(w, owner), p.contract.salary - int(p.contract.salary * 0.5), "owner pays the rest")
	var other: Club = w.clubs.values().filter(func(c): return c != me and c != owner)[0]
	check(not TransferMarket.make_transfer_offer(w, other, p, 99999999, 999999, 2, "starter")["accepted"], "no transfers while on loan")
	# 季末歸隊
	Loans.return_all(w)
	check(owner.roster.has(p.id) and not me.roster.has(p.id) and p.club_id == owner.id, "player returns after the season")
	check(not Loans.is_loaned(p) and not owner.loaned_out.has(p.id), "loan cleared")


func test_starters_are_not_loaned_by_ai_clubs() -> void:
	var w = make_world(9, "crimson_tide_gaming")
	w.phase = WorldState.PHASE_PRESEASON
	var me: Club = w.human_club()
	for c in w.clubs.values():
		if c.is_human:
			continue
		var starter: Player = w.players[c.lineup.values()[0]]
		var r = Loans.request(w, me, starter, 0.5)
		check(not r["accepted"], "AI keeps its starter")
		break


func test_session_loan_out_finds_a_club() -> void:
	var s := GameSession.new()
	s.new_game(MODULE_DIR, 10, "crimson_tide_gaming")
	var b = _bench_player(s.world, s.club())
	check(b != null, "human club has a bench player")
	if b == null:
		return
	var r = s.loan_out(b.id)
	if r.get("accepted", false):
		check(s.club().loaned_out.has(b.id), "loaned out")
	else:
		check(r.get("reason", "") != "", "clear reason when nobody takes him")
