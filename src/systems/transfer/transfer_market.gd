## 轉會市場與合約：市場價值、薪資要求、合約評估（選手意願）與轉會流程。
## 玩家俱樂部與 AI 俱樂部呼叫完全相同的函式。
class_name TransferMarket
extends RefCounted


static func market_value(w: WorldState, p: Player) -> int:
	var ca = p.current_ability()
	var a = p.age(w.year)
	var v = 8000.0 * pow(1.10, ca - 40.0)
	if a <= 21:
		v *= 1.0 + maxf(p.potential - ca, 0.0) / 40.0  # 潛力溢價（以真實潛力近似；球探系統於第二階段提供誤差）
	elif a >= 27:
		v *= maxf(1.0 - (a - 26) * 0.12, 0.25)
	var years = p.contract.years_left(w.year) if p.contract else 0
	v *= 0.5 + 0.25 * years
	v *= 0.8 + p.reputation / 250.0
	return int(v)


static func wage_demand(w: WorldState, p: Player) -> int:
	var ca = p.current_ability()
	var base = 18000.0 + 7000.0 * pow(1.075, ca - 40.0)
	# 頂尖選手是稀缺資源：超過 72 的能力薪資要求急遽上升，冠軍光環也會抬高身價。
	# 這讓王朝在薪資預算內難以長期維持全明星陣容。
	base *= 1.0 + maxf(ca - 72.0, 0.0) * 0.07
	base *= 0.8 + p.reputation / 200.0
	if "MONEY" in p.goals:
		base *= 1.15
	base *= Agents.wage_factor(p)
	return int(base)


## 選手對一份合約的主觀效用（約 -2..2）。
static func contract_utility(w: WorldState, p: Player, club: Club, salary: int, role_promise: String) -> Dictionary:
	var parts := {}
	parts["money"] = clampf((float(salary) / maxf(wage_demand(w, p), 1.0) - 1.0) * 2.5, -1.5, 1.0)
	parts["competitive"] = (club.reputation - 50.0) / 50.0
	# 次級聯賽的舞台較小：除了想要上場時間的新人，選手不太願意去
	var lg: League = w.leagues.get(club.league_id)
	if lg and lg.tier >= 2:
		parts["competitive"] -= 0.7 * (0.5 if p.age(w.year) <= 19 else 1.0)
	parts["playing"] = {"starter": 0.8, "rotation": 0.0, "backup": -0.6, "prospect": -0.2 if p.age(w.year) <= 19 else -0.6}.get(role_promise, 0.0)
	parts["loyalty"] = (p.trait_value("loyalty") / 100.0) if club.id == p.club_id else 0.0
	parts["home"] = 0.25 if club.region == p.home_region else (-0.1 if "GO_ABROAD" in p.goals else -0.3)
	if "GO_ABROAD" in p.goals and club.region != p.home_region:
		parts["home"] = 0.3
	var weights = {"money": 1.0, "competitive": 0.6, "playing": 0.8, "loyalty": 0.6, "home": 0.5}
	for g in p.goals:
		match g:
			"MONEY": weights["money"] += 1.5
			"WIN_TITLES": weights["competitive"] += 1.2
			"PLAYING_TIME": weights["playing"] += 1.2
			"RETIRE_AT_CLUB": weights["loyalty"] += 2.5
			"STABILITY": weights["home"] += 0.5
	if club.id == p.club_id and p.refuses_renewal:
		parts["loyalty"] = -1.0
	var u := 0.0
	var wsum := 0.0
	for k in parts:
		u += parts[k] * weights[k]
		wsum += weights[k]
	return {"utility": u / wsum * 2.0, "parts": parts}


## 提出合約（續約或簽約）。回傳 {accepted, reason, utility}
static func offer_contract(w: WorldState, club: Club, p: Player, salary: int, years: int, role_promise: String) -> Dictionary:
	var ev = contract_utility(w, p, club, salary, role_promise)
	var u: float = ev["utility"]
	var threshold = -0.15 if p.club_id == "" else 0.0
	if p.club_id != "" and p.club_id != club.id:
		threshold = 0.1  # 離開現有球隊需要更好的條件
	var accepted = u > threshold
	var reason := ""
	if not accepted:
		var parts: Dictionary = ev["parts"]
		var worst := "money"
		for k in parts:
			if parts[k] < parts[worst]:
				worst = k
		reason = {"money": "薪資不足", "competitive": "球隊競爭力不足", "playing": "出場承諾不夠", "loyalty": "不願意留在這支隊伍", "home": "不想離開家鄉賽區"}.get(worst, worst)
	w.log.add("contract_offer", w.day, [p.id, club.id], {"salary": salary, "years": years, "accepted": accepted, "utility": u}, [reason] if reason != "" else ["條件符合期待"])
	if accepted:
		var c := Contract.new()
		c.club_id = club.id
		c.salary = salary
		c.start_year = w.year if w.phase != WorldState.PHASE_OFFSEASON else w.year + 1
		c.end_year = c.start_year + years - 1
		c.role_promise = role_promise
		p.contract = c
		p.refuses_renewal = false
		var agent_fee = Agents.fee(p, salary)
		if agent_fee > 0:
			Finance.spend(club, "agent_fees", agent_fee)
	return {"accepted": accepted, "reason": reason, "utility": u}


## 外援名額：聯賽 format.import_limit（未設定＝不限）。非本賽區出身的選手算外援。
static func import_limit(w: WorldState, club: Club) -> int:
	var lg: League = w.leagues.get(club.league_id)
	if lg == null:
		return -1
	return int(lg.format.get("import_limit", -1))


static func import_count(w: WorldState, club: Club) -> int:
	var n := 0
	for pid in club.roster:
		if w.players[pid].home_region != club.region:
			n += 1
	return n


static func import_blocked(w: WorldState, club: Club, p: Player) -> bool:
	if p.home_region == club.region or p.club_id == club.id:
		return false
	var lim := import_limit(w, club)
	return lim >= 0 and import_count(w, club) >= lim


static func asking_price(w: WorldState, seller: Club, p: Player) -> int:
	var v := float(market_value(w, p))
	if seller.lineup.values().has(p.id):
		v *= 1.5
	if p.transfer_requested:
		v *= 0.7
	if p.contract and p.contract.release_clause > 0:
		v = minf(v, p.contract.release_clause)
	return int(v)


## 轉會報價：賣方評估轉會費 → 選手評估合約 → 完成轉會。
static func make_transfer_offer(w: WorldState, buyer: Club, p: Player, fee: int, salary: int, years: int, role_promise: String) -> Dictionary:
	if import_blocked(w, buyer, p):
		return {"accepted": false, "reason": "外援名額已滿"}
	if Loans.is_loaned(p):
		return {"accepted": false, "reason": "選手租借中，季後才能轉會"}
	if p.club_id == "":
		var r = offer_contract(w, buyer, p, salary, years, role_promise)
		if r["accepted"]:
			_move(w, p, null, buyer, 0)
		return r
	var seller: Club = w.clubs[p.club_id]
	if int(p.career.get("last_move_year", -1)) == w.year and p.club_id != "":
		return {"accepted": false, "reason": "選手剛轉會，不考慮再次離隊"}
	if seller.is_human:
		var dup = w.inbox.any(func(m): return m.get("kind") == "transfer_offer" and m.get("player_id") == p.id and m.get("from_club") == buyer.id and not m.get("resolved", false))
		if dup:
			return {"accepted": false, "reason": "等待玩家回覆"}
		w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "transfer_offer", "player_id": p.id, "from_club": buyer.id,
			"fee": fee, "salary": salary, "years": years, "role_promise": role_promise,
			"text": "%s 對 %s 提出 %d 的轉會報價" % [buyer.name, p.handle, fee], "resolved": false,
			"options": ["accept_offer", "reject_offer"]})
		return {"accepted": false, "reason": "等待玩家回覆"}
	if fee < asking_price(w, seller, p) or buyer.cash < fee:
		return {"accepted": false, "reason": "賣方拒絕轉會費"}
	var r = offer_contract(w, buyer, p, salary, years, role_promise)
	if r["accepted"]:
		_move(w, p, seller, buyer, fee)
	return r


static func _move(w: WorldState, p: Player, from: Club, to: Club, fee: int) -> void:
	if from:
		from.roster.erase(p.id)
		if fee > 0:
			Finance.earn(from, "transfer_in", fee)
		for role in from.lineup.keys():
			if from.lineup[role] == p.id:
				from.lineup.erase(role)
	else:
		w.free_agents.erase(p.id)
	if fee > 0:
		Finance.spend(to, "transfer_out", fee)
	to.roster.append(p.id)
	p.club_id = to.id
	p.squad_status = p.contract.role_promise if p.contract else "rotation"
	p.transfer_requested = false
	p.weeks_unhappy = 0
	p.happiness = 0.3
	p.trust_in_management = 55.0
	p.promises.clear()
	if from:
		p.career["last_move_year"] = w.year
	Relationships.on_leave(w, p.id)
	var rec = {"year": w.year, "day": w.day, "player_id": p.id, "handle": p.handle, "from": from.id if from else "", "to": to.id, "fee": fee}
	w.history["transfers"].append(rec)
	Media.on_transfer(w, p, from, to, fee)
	w.log.add("transfer", w.day, [p.id, to.id] + ([from.id] if from else []), rec, [])


static func release(w: WorldState, club: Club, p: Player, reason: String) -> void:
	club.roster.erase(p.id)
	for role in club.lineup.keys():
		if club.lineup[role] == p.id:
			club.lineup.erase(role)
	p.club_id = ""
	p.contract = null
	p.squad_status = "rotation"
	w.free_agents.append(p.id)
	w.log.add("release", w.day, [p.id, club.id], {}, [reason])


static func wage_bill(w: WorldState, club: Club) -> int:
	var total := 0
	for pid in club.roster:
		total += Loans.wage_for(w, club, w.players[pid])
	for pid in club.loaned_out:
		total += Loans.wage_for(w, club, w.players[pid])
	return total


## 玩家回覆 AI 俱樂部的轉會報價。接受後仍需選手本人同意新合約。
static func respond_to_offer(w: WorldState, msg: Dictionary, accept: bool) -> Dictionary:
	msg["resolved"] = true
	var p: Player = w.players.get(msg.get("player_id", ""))
	var buyer: Club = w.clubs.get(msg.get("from_club", ""))
	if p == null or buyer == null or p.club_id != w.human_club_id:
		return {"accepted": false, "reason": "報價已失效"}
	if not accept:
		w.log.add("offer_rejected", w.day, [p.id, buyer.id], {"fee": msg["fee"]}, ["玩家拒絕報價"])
		# 選手想走卻被拒絕 → 不滿
		if p.transfer_requested:
			p.happiness -= 0.2
			p.trust_in_management -= 8.0
		return {"accepted": false, "reason": "已拒絕"}
	if buyer.cash < int(msg["fee"]):
		return {"accepted": false, "reason": "買方資金不足"}
	var r = offer_contract(w, buyer, p, int(msg.get("salary", wage_demand(w, p))), int(msg.get("years", 2)), msg.get("role_promise", "starter"))
	if r["accepted"]:
		_move(w, p, w.clubs[p.club_id], buyer, int(msg["fee"]))
	return r
