## 租借：選手暫時到另一支俱樂部效力到本季結束，合約仍屬原俱樂部。
## 租入方付租借費並分擔一部分薪資；休賽季開始時選手自動歸隊。
class_name Loans
extends RefCounted


static func is_loaned(p: Player) -> bool:
	return not p.loan.is_empty()


## 本季剩餘可否租借（例行賽結束前、或休賽季／季前）。
static func window_open(w: WorldState) -> bool:
	return w.phase in [WorldState.PHASE_OFFSEASON, WorldState.PHASE_PRESEASON, WorldState.PHASE_REGULAR]


static func loan_fee(w: WorldState, p: Player) -> int:
	return int(TransferMarket.market_value(w, p) * 0.08)


## 選手是否願意被租借到 to：能打先發、或年輕需要上場時間就願意。
static func player_willing(w: WorldState, p: Player, to: Club) -> bool:
	var cur: Player = w.players.get(to.lineup.get(p.primary_role, ""))
	var would_start = cur == null or p.current_ability(p.primary_role) > cur.current_ability(p.primary_role) - 1.0
	return would_start or p.age(w.year) <= 20


## 擁有方是否放人：非先發才會出借（玩家俱樂部由玩家自行決定）。
static func owner_willing(w: WorldState, owner: Club, p: Player) -> bool:
	if owner.is_human:
		return true
	return not owner.lineup.values().has(p.id) and owner.roster.size() > Tuning.i("min_roster")


static func request(w: WorldState, to: Club, p: Player, wage_share: float = 0.5) -> Dictionary:
	if not window_open(w):
		return {"accepted": false, "reason": "季後賽期間不能租借"}
	if p.club_id == "" or p.club_id == to.id or p.contract == null:
		return {"accepted": false, "reason": "只能租借其他俱樂部有合約的選手"}
	if is_loaned(p):
		return {"accepted": false, "reason": "選手已在租借中"}
	if TransferMarket.import_blocked(w, to, p):
		return {"accepted": false, "reason": "外援名額已滿"}
	var owner: Club = w.clubs[p.club_id]
	if not owner_willing(w, owner, p):
		return {"accepted": false, "reason": "%s 不願出借先發選手" % owner.short_name}
	if not player_willing(w, p, to):
		return {"accepted": false, "reason": "選手認為在 %s 拿不到上場時間" % to.short_name}
	var fee = loan_fee(w, p)
	if to.cash < fee:
		return {"accepted": false, "reason": "資金不足以支付租借費"}
	start(w, p, owner, to, fee, clampf(wage_share, 0.0, 1.0))
	return {"accepted": true, "reason": "", "fee": fee}


static func start(w: WorldState, p: Player, owner: Club, to: Club, fee: int, wage_share: float) -> void:
	owner.roster.erase(p.id)
	for role in owner.lineup.keys():
		if owner.lineup[role] == p.id:
			owner.lineup.erase(role)
	owner.loaned_out.append(p.id)
	to.roster.append(p.id)
	p.club_id = to.id
	p.loan = {"from": owner.id, "to": to.id, "until": w.year, "wage_share": wage_share, "fee": fee}
	if fee > 0:
		Finance.spend(to, "loan_fees", fee)
		Finance.earn(owner, "loan_fees", fee)
	Relationships.on_leave(w, p.id)
	w.log.add("loan", w.day, [p.id, to.id, owner.id], {"fee": fee, "wage_share": wage_share}, ["租借到本季結束"])
	Media.post(w, "loan", "%s 將 %s 租借給 %s 至本季結束" % [owner.short_name, p.handle, to.short_name], [p.id, owner.id, to.id], 0.0)


static func end(w: WorldState, p: Player) -> void:
	if not is_loaned(p):
		return
	var to: Club = w.clubs.get(p.loan["to"])
	var owner: Club = w.clubs.get(p.loan["from"])
	if to:
		to.roster.erase(p.id)
		for role in to.lineup.keys():
			if to.lineup[role] == p.id:
				to.lineup.erase(role)
	p.loan = {}
	if owner:
		owner.loaned_out.erase(p.id)
		owner.roster.append(p.id)
		p.club_id = owner.id
	else:
		p.club_id = ""
		w.free_agents.append(p.id)
	Relationships.on_leave(w, p.id)
	w.log.add("loan_end", w.day, [p.id] + ([owner.id] if owner else []), {}, ["租借結束歸隊"])


## 休賽季第一天：所有租借到期歸隊。
static func return_all(w: WorldState) -> void:
	for p in w.players.values():
		if is_loaned(p) and int(p.loan.get("until", 0)) <= w.year:
			end(w, p)


## 這支俱樂部要負擔的租借選手薪資調整（租入：只付分擔比例；租出：付剩下的部分）。
static func wage_for(w: WorldState, club: Club, p: Player) -> int:
	if p.contract == null:
		return 0
	if not is_loaned(p):
		return p.contract.salary
	var share = float(p.loan.get("wage_share", 0.5))
	if p.loan["to"] == club.id:
		return int(p.contract.salary * share)
	return int(p.contract.salary * (1.0 - share))


## AI：休賽季把坐板凳的年輕選手租到同賽區、該位置較弱的次級聯賽隊伍。
static func ai_loan_out(w: WorldState, club: Club) -> void:
	if club.is_human:
		return
	var lg: League = w.leagues.get(club.league_id)
	if lg == null or lg.tier != 1:
		return
	for pid in club.roster.duplicate():
		var p: Player = w.players[pid]
		if club.lineup.values().has(pid) or p.age(w.year) > 20 or is_loaned(p) or p.contract == null:
			continue
		if club.roster.size() <= Tuning.i("min_roster"):
			return
		for c in w.clubs.values():
			var clg: League = w.leagues.get(c.league_id)
			if c.is_human or clg == null or clg.tier != 2 or c.region != club.region:
				continue
			var cur: Player = w.players.get(c.lineup.get(p.primary_role, ""))
			if cur != null and cur.current_ability(p.primary_role) >= p.current_ability(p.primary_role):
				continue
			if request(w, c, p, 0.6).get("accepted", false):
				LineupSelector.pick(w, c)
				return
