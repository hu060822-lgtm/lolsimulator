## 搶人大戰：你看上的好選手，AI 強隊也會出手。
##
## - 觸發：你提出的合約（自由球員簽約或轉會報價）本來會被接受，但對方能力 >= MIN_ABILITY，
##   且有一支一級聯賽 AI 俱樂部需要這個位置、薪資空間夠，便有機率加入競標
##   （機率 0.25 + (能力 - 65) / 50，上限 0.7）。
## - 對手開出需求薪資的 1.0～1.25 倍並保證先發。若選手覺得對手的條件比你好，收件匣出現「搶人大戰」：
##   - 加價：用剛好贏過對手的最低年薪簽下（一定成功）。
##   - 堅持原條件：賭選手看重你的其他條件（成功率 10%～45%，條件差越多越低）。
##   - 放手：對手簽下選手。
## - 搶輸時對手會直接簽走選手，讓 AI 球隊不再只是被動等你挑人。
class_name BiddingWar
extends RefCounted

const MIN_ABILITY := 62.0


static func entry_chance(ability: float) -> float:
	return clampf(0.25 + (ability - 65.0) / 50.0, 0.0, 0.7)


## 你的報價送出前檢查：若觸發搶人大戰，建立收件匣訊息並回傳 {accepted:false, bidding:true, reason}；否則回傳 {}。
static func maybe_start(w: WorldState, buyer: Club, p: Player, fee: int, salary: int, years: int, role_promise: String, force: bool = false) -> Dictionary:
	if not buyer.is_human or p.club_id == buyer.id:
		return {}
	var ca := p.current_ability()
	if ca < MIN_ABILITY:
		return {}
	if w.inbox.any(func(m): return m.get("kind") == "bidding" and m.get("player_id") == p.id and not m.get("resolved", false)):
		return {"accepted": false, "bidding": true, "reason": "搶人大戰進行中，請到收件匣決定"}
	# 只有「本來會成交」的報價才會引來競爭
	if not _would_accept(w, buyer, p, fee, salary, role_promise):
		return {}
	if not force and not w.rng.chance(entry_chance(ca)):
		return {}
	var rival := _find_rival(w, buyer, p, fee)
	if rival == null:
		return {}
	var rival_salary := int(TransferMarket.wage_demand(w, p) * w.rng.range_f(1.0, 1.25) / 1000.0) * 1000
	var ours: float = TransferMarket.contract_utility(w, p, buyer, salary, role_promise)["utility"]
	var theirs: float = TransferMarket.contract_utility(w, p, rival, rival_salary, "starter")["utility"]
	if theirs <= ours:
		return {}
	var raise := raise_salary(w, p, buyer, role_promise, theirs, salary)
	var hold := hold_chance(ours, theirs)
	var labels := {"bid:withdraw": "放手"}
	var opts: Array = []
	if raise > 0:
		opts.append("bid:raise")
		labels["bid:raise"] = "加價到 $%dK 簽下" % (raise / 1000)
	opts.append("bid:hold")
	labels["bid:hold"] = "堅持原條件（%d%% 機會）" % roundi(hold * 100.0)
	opts.append("bid:withdraw")
	var msg := {"id": w.new_id("msg"), "day": w.day, "kind": "bidding", "player_id": p.id, "from_club": p.club_id,
		"rival_id": rival.id, "rival_salary": rival_salary, "fee": fee, "salary": salary, "years": years, "role_promise": role_promise,
		"raise_salary": raise, "hold_chance": hold,
		"text": "搶人大戰！%s 也看上了 %s，開出年薪 $%dK 並保證先發。選手的經紀人說：「條件最好的那邊，我們就簽。」" % [rival.name, p.handle, rival_salary / 1000],
		"resolved": false, "options": opts, "option_labels": labels}
	w.inbox.append(msg)
	Media.post(w, "rumor", "%s 與 %s 正在爭奪 %s" % [buyer.short_name, rival.short_name, p.handle], [p.id, buyer.id, rival.id], 0.0)
	w.log.add("bidding_war", w.day, [p.id, buyer.id, rival.id], {"rival_salary": rival_salary, "salary": salary}, [])
	return {"accepted": false, "bidding": true, "reason": "%s 也出價了！到收件匣決定要不要加價" % rival.short_name, "message_id": msg["id"]}


static func hold_chance(ours: float, theirs: float) -> float:
	return clampf(0.5 + (ours - theirs) * 1.5, 0.1, 0.45)


## 剛好贏過對手的最低年薪（找不到回傳 0）。
static func raise_salary(w: WorldState, p: Player, buyer: Club, role_promise: String, target_u: float, from_salary: int) -> int:
	for i in range(1, 41):
		var sal := int(from_salary * (1.0 + 0.04 * i) / 1000.0) * 1000
		if TransferMarket.contract_utility(w, p, buyer, sal, role_promise)["utility"] > target_u + 0.01:
			return sal
	return 0


static func _would_accept(w: WorldState, buyer: Club, p: Player, fee: int, salary: int, role_promise: String) -> bool:
	if TransferMarket.import_blocked(w, buyer, p) or Loans.is_loaned(p):
		return false
	var threshold := -0.15
	if p.club_id != "":
		var seller: Club = w.clubs[p.club_id]
		if seller.is_human or buyer.cash < fee or fee < TransferMarket.asking_price(w, seller, p):
			return false
		if int(p.career.get("last_move_year", -1)) == w.year:
			return false
		threshold = 0.1
	return TransferMarket.contract_utility(w, p, buyer, salary, role_promise)["utility"] > threshold


static func _find_rival(w: WorldState, buyer: Club, p: Player, fee: int) -> Club:
	var role := p.primary_role
	var ca := p.current_ability()
	var best: Club = null
	var best_s := -INF
	for c: Club in w.clubs.values():
		if c.is_human or c.id == p.club_id or c.id == buyer.id:
			continue
		var lg: League = w.leagues.get(c.league_id)
		if lg == null or lg.tier > 1 or c.cash < fee or TransferMarket.import_blocked(w, c, p):
			continue
		if c.wage_budget - TransferMarket.wage_bill(w, c) < TransferMarket.wage_demand(w, p):
			continue
		var cur: String = c.lineup.get(role, "")
		var cur_ca: float = w.players[cur].current_ability(role) if cur != "" and w.players.has(cur) else 0.0
		if cur_ca >= ca - 2.0:
			continue  # 這個位置不缺人
		var s := c.reputation + (ca - cur_ca) * 0.5 + w.rng.range_f(0.0, 5.0)
		if s > best_s:
			best_s = s
			best = c
	return best


## 玩家回覆搶人大戰。
static func resolve(w: WorldState, msg: Dictionary, option: String) -> Dictionary:
	msg["resolved"] = true
	var p: Player = w.players.get(msg["player_id"])
	var me: Club = w.human_club()
	var rival: Club = w.clubs.get(msg["rival_id"])
	if p == null or me == null or p.club_id != str(msg.get("from_club", "")):
		return {"note": "選手已經有了新去處"}
	var choice := option.trim_prefix("bid:")
	var won := false
	var salary := int(msg["salary"])
	match choice:
		"raise":
			salary = int(msg.get("raise_salary", 0))
			won = salary > 0
		"hold":
			won = w.rng.chance(float(msg.get("hold_chance", 0.25)))
	if won:
		var r := _sign(w, me, p, int(msg["fee"]), salary, int(msg["years"]), str(msg["role_promise"]))
		if r.get("accepted", false):
			Media.post(w, "transfer", "%s 在搶人大戰中勝出，簽下 %s" % [me.short_name, p.handle], [p.id, me.id], 0.4)
			return {"note": "成功簽下 %s（年薪 $%dK）" % [p.handle, salary / 1000], "signed": true}
		return {"note": "沒能完成簽約：%s" % r.get("reason", "")}
	if rival:
		var rr := _sign(w, rival, p, int(msg["fee"]), int(msg["rival_salary"]), 2, "starter")
		if rr.get("accepted", false):
			Media.post(w, "transfer", "%s 搶走了 %s，%s 撲空" % [rival.short_name, p.handle, me.short_name], [p.id, rival.id, me.id], -0.2)
			return {"note": "%s 選擇了 %s" % [p.handle, rival.short_name], "signed": false}
	return {"note": "%s 暫時沒有簽約" % p.handle, "signed": false}


static func _sign(w: WorldState, club: Club, p: Player, fee: int, salary: int, years: int, role_promise: String) -> Dictionary:
	if p.club_id == "":
		var r := TransferMarket.offer_contract(w, club, p, salary, years, role_promise)
		if r["accepted"]:
			TransferMarket._move(w, p, null, club, 0)
		return r
	var seller: Club = w.clubs[p.club_id]
	if club.cash < fee:
		return {"accepted": false, "reason": "資金不足"}
	var r2 := TransferMarket.offer_contract(w, club, p, salary, years, role_promise)
	if r2["accepted"]:
		TransferMarket._move(w, p, seller, club, fee)
	return r2
