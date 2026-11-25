## AI 俱樂部經營：與玩家使用相同規則（TransferMarket / CareerAgent / LineupSelector）。
## 依經營哲學（win_now / develop / balanced / moneyball）產生不同決策。
class_name ClubAI
extends RefCounted


static func weekly(w: WorldState, club: Club) -> void:
	if not LineupSelector.is_valid(w, club) or w.rng.chance(0.25):
		LineupSelector.pick(w, club)
	# 招牌打法：每季依先發的英雄池決定；連敗時教練可能改打法
	if int(club.tactics.get("style_year", 0)) != w.year:
		choose_style(w, club, 0)
	elif club.streak <= -4 and w.rng.chance(0.3):
		choose_style(w, club, 1)
	# 不滿的選手：AI 會回應（解釋或承諾），長期不滿則掛牌
	for pid in club.roster.duplicate():
		var p: Player = w.players[pid]
		if p.happiness < Tuning.f("talk_threshold") and p.promises.filter(func(x): return not x.get("resolved", false)).is_empty():
			CareerAgent.respond(w, p, "explain_situation" if p.trust_in_management > 45 else "promise_playing_time")


## 休賽季：續約 → 補強 → 清理名單。每天只有部分俱樂部行動（分階段更新）。
static func offseason_step(w: WorldState, club: Club, stage: String) -> void:
	match stage:
		"renew":
			_renewals(w, club)
		"recruit":
			_recruit(w, club)
		"trim":
			_trim(w, club)


static func _renewals(w: WorldState, club: Club) -> void:
	var bill = 0
	for pid in club.roster:
		var q: Player = w.players[pid]
		if q.contract and q.contract.end_year > w.year:
			bill += q.contract.salary
	var ids: Array = club.roster.duplicate()
	# 先續約最重要的選手；薪資空間不夠時，其餘選手只能放走（王朝的代價）
	ids.sort_custom(func(x, y): return w.players[x].current_ability() > w.players[y].current_ability())
	for pid in ids:
		var p: Player = w.players[pid]
		if p.contract == null or p.contract.end_year > w.year:
			continue
		var keep = club.lineup.values().has(pid) or (p.age(w.year) <= 21 and p.potential > 65.0)
		if not keep or p.age(w.year) >= 31 and club.philosophy != "win_now":
			continue
		var demand = TransferMarket.wage_demand(w, p)
		var mult = {"win_now": 1.1, "balanced": 1.0, "develop": 0.95, "moneyball": 0.9}.get(club.philosophy, 1.0)
		var new_salary = int(demand * mult)
		if bill + new_salary > club.wage_budget:
			w.log.add("cannot_afford_renewal", w.day, [p.id, club.id], {"demand": new_salary}, ["薪資空間不足"])
			continue
		var r = TransferMarket.offer_contract(w, club, p, new_salary, w.rng.range_i(1, 3), "starter" if club.lineup.values().has(pid) else "rotation")
		if r["accepted"]:
			bill += new_salary


static func _needs(w: WorldState, club: Club) -> Array:
	var needs: Array = []
	var league: League = w.leagues.get(club.league_id)
	var avg = _league_starter_avg(w, league)
	# 期待與聲望相稱：豪門以聯賽頂尖為目標，小隊只求不墊底
	if league:
		var reps: Array = league.club_ids.map(func(c): return w.clubs[c].reputation)
		avg += (club.reputation - MathX.mean(reps)) * 0.12
	for role in Attr.ROLES:
		var best := 0.0
		for pid in club.roster:
			var p: Player = w.players[pid]
			if p.contract and p.contract.end_year < w.year + 1 and w.phase == WorldState.PHASE_OFFSEASON:
				continue  # 即將離隊
			best = maxf(best, p.current_ability(role))
		var target = avg + {"win_now": 4.0, "balanced": 0.0, "develop": -4.0, "moneyball": -2.0}.get(club.philosophy, 0.0)
		if best < target - 3.0 or best == 0.0:
			needs.append({"role": role, "gap": target - best, "current": best})
	needs.sort_custom(func(a, b): return a["gap"] > b["gap"])
	return needs


static func _league_starter_avg(w: WorldState, league: League) -> float:
	var vals: Array = []
	if league == null:
		return 55.0
	for cid in league.club_ids:
		var c: Club = w.clubs[cid]
		for pid in c.lineup.values():
			if w.players.has(pid):
				vals.append(w.players[pid].current_ability())
	return MathX.mean(vals) if vals.size() > 0 else 55.0


static func _recruit(w: WorldState, club: Club) -> void:
	var needs = _needs(w, club)
	if needs.is_empty() and club.roster.size() >= Tuning.i("min_roster"):
		return
	var wage_room = club.wage_budget - TransferMarket.wage_bill(w, club)
	for need in needs.slice(0, 2):
		var role: String = need["role"]
		var scored: Array = []
		var candidates: Array = w.free_agents.map(func(pid): return w.players[pid])
		var my_lg: League = w.leagues.get(club.league_id)
		var my_tier = my_lg.tier if my_lg else 1
		for c in w.clubs.values():
			if c.id == club.id:
				continue
			var c_lg: League = w.leagues.get(c.league_id)
			var lower_tier = c_lg != null and c_lg.tier > my_tier  # 次級聯賽的先發可以被一級隊伍買走
			for pid in c.roster:
				var o: Player = w.players[pid]
				# 挖角對手先發：只在缺口夠大時考慮合約將到期者
				var poachable = o.contract and o.contract.years_left(w.year) <= 1 and need["gap"] >= 6.0
				if o.transfer_requested or poachable or lower_tier or not c.lineup.values().has(pid):
					candidates.append(o)
		for p in candidates:
			if p.retired or p.primary_role != role or TransferMarket.import_blocked(w, club, p):
				continue
			if p.club_id != "" and int(p.career.get("last_move_year", -1)) == w.year:
				continue  # 剛轉會的選手不會再走
			var ca = p.current_ability(role)
			if ca <= need["current"] + 1.0:
				continue
			var cost = TransferMarket.wage_demand(w, p)
			var fee = 0 if p.club_id == "" else TransferMarket.asking_price(w, w.clubs[p.club_id], p)
			if cost > wage_room or fee > club.cash * 0.5:
				continue
			var score = ca - need["current"]
			match club.philosophy:
				"develop":
					score += maxf(p.potential - ca, 0.0) * 0.6 - maxf(p.age(w.year) - 22, 0) * 1.5
				"moneyball":
					score -= (cost / 20000.0 + fee / 60000.0)
				"win_now":
					score += ca * 0.1
			scored.append([score, p])
		# 依評分嘗試前三名：第一人選拒絕時找下一位
		scored.sort_custom(func(a, b): return a[0] > b[0])
		for pair in scored.slice(0, 3):
			var best: Player = pair[1]
			var fee = 0 if best.club_id == "" else TransferMarket.asking_price(w, w.clubs[best.club_id], best)
			var salary := int(TransferMarket.wage_demand(w, best) * w.rng.range_f(1.0, 1.2))
			if salary > wage_room:
				continue
			var r = TransferMarket.make_transfer_offer(w, club, best, fee, salary, w.rng.range_i(1, 3), "starter")
			if r.get("accepted", false):
				wage_room -= salary
				break
	fill_roster(w, club)


## 名單不足：簽便宜的自由選手或提拔新人（不挖角，因此不會連鎖影響其他隊伍），最後重選先發。
static func fill_roster(w: WorldState, club: Club) -> void:
	while club.roster.size() < Tuning.i("min_roster"):
		var role = _thinnest_role(w, club)
		var pool = w.free_agents.map(func(pid): return w.players[pid]).filter(func(p): return p.primary_role == role and not p.retired and not TransferMarket.import_blocked(w, club, p))
		pool.sort_custom(func(a, b): return a.current_ability() > b.current_ability())
		var signed := false
		for p in pool.slice(0, 3):
			if TransferMarket.make_transfer_offer(w, club, p, 0, int(TransferMarket.wage_demand(w, p) * 1.1), 1, "rotation").get("accepted", false):
				signed = true
				break
		if not signed:
			var q = clampf((club.reputation - 30.0) / 80.0, 0.05, 0.8)
			var youth = PlayerGenerator.generate(w, w.rng, club.region, role, q, true)
			w.players[youth.id] = youth
			w.free_agents.append(youth.id)
			TransferMarket.offer_contract(w, club, youth, int(TransferMarket.wage_demand(w, youth) * 1.3), 2, "prospect")
			if youth.contract:
				TransferMarket._move(w, youth, null, club, 0)
			else:
				break
	if not LineupSelector.is_valid(w, club):
		LineupSelector.pick(w, club)


static func _thinnest_role(w: WorldState, club: Club) -> String:
	var counts := {}
	for r in Attr.ROLES:
		counts[r] = 0
	for pid in club.roster:
		counts[w.players[pid].primary_role] += 1
	var best: String = Attr.ROLES[0]
	for r in Attr.ROLES:
		if counts[r] < counts[best]:
			best = r
	return best


static func _trim(w: WorldState, club: Club) -> void:
	while club.roster.size() > Tuning.i("max_roster"):
		var worst: Player = null
		for pid in club.roster:
			var p: Player = w.players[pid]
			if club.lineup.values().has(pid):
				continue
			if worst == null or TransferMarket.market_value(w, p) < TransferMarket.market_value(w, worst):
				worst = p
		if worst == null:
			break
		TransferMarket.release(w, club, worst, "名單超額")


## 賽季結束評估：表現遠低於期待 → 解雇主教練（第二階段擴充為完整教練團）。
static func review_coach(w: WorldState, club: Club, position: int, teams: int) -> void:
	var expected = clampf(1.0 - club.reputation / 100.0, 0.0, 1.0) * teams
	if position > expected + teams * 0.35 and w.rng.chance(0.6):
		var old: Staff = w.staff.get(club.coach_id)
		StaffSystem.dismiss(w, club, "head_coach")
		StaffSystem.ai_fill(w, club)
		var coach: Staff = w.staff.get(club.coach_id)
		w.log.add("coach_fired", w.day, [club.id], {"old": old.name if old else "", "new": coach.name if coach else ""}, ["排名第 %d，低於預期" % position])


## AI 俱樂部的招牌打法：取先發各自最拿手的兩隻英雄，找最契合的戰術方向。
## rank = 0 取最契合者；1 = 換成第二契合（連敗後求變）。玩家可在賽前情報看到並針對。
static func choose_style(w: WorldState, club: Club, rank: int = 0) -> String:
	if club.is_human:
		return str(club.tactics.get("plan", "flexible"))
	var champs: Array = []
	for role in club.lineup:
		var p: Player = w.players.get(club.lineup[role])
		if p == null:
			continue
		for cid in p.top_champions(2):
			if w.champions.has(cid):
				champs.append(w.champions[cid])
	var plan = "flexible"
	if champs.size() >= 5:
		var comp = CompAnalyzer.analyze(champs)
		var ranked: Array = StyleMatchup.CYCLE.duplicate()
		ranked.sort_custom(func(a, b): return CompAnalyzer.plan_fit(a, comp) > CompAnalyzer.plan_fit(b, comp))
		var old: String = str(club.tactics.get("plan", "flexible"))
		plan = ranked[mini(rank, ranked.size() - 1)]
		if rank > 0 and plan == old:
			plan = ranked[0]
	var prev: String = str(club.tactics.get("plan", "flexible"))
	club.tactics["plan"] = plan
	club.tactics["style_year"] = w.year
	if rank > 0 and prev != plan:
		w.log.add("style_change", w.day, [club.id], {"from": prev, "to": plan}, ["連敗後調整打法"])
	return plan
