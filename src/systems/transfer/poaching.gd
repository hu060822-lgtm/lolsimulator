## 挖角：轉會窗口期間，聲望更高的 AI 豪門會對玩家表現亮眼的選手提出報價。
##
## 這讓「把隊伍養強」本身帶來新挑戰：拒絕報價不再沒有代價——有野心、想拿冠軍
## 或想要高薪的選手被擋下轉會會失望，信任下降，持續不滿就會正式要求離隊。
## 接受則換到轉會費，但要補上陣容缺口。
class_name Poaching
extends RefCounted

const WEEKLY_CHANCE := 0.22
const REP_MARGIN := 4.0     ## 買方聲望至少高出玩家俱樂部這麼多才會來挖角


static func weekly(w: WorldState) -> void:
	var me: Club = w.human_club()
	if me == null or not w.phase in [WorldState.PHASE_OFFSEASON, WorldState.PHASE_PRESEASON]:
		return
	if not w.rng.chance(WEEKLY_CHANCE):
		return
	var open = w.inbox.filter(func(m): return m.get("kind") == "transfer_offer" and m.get("poach", false) and not m.get("resolved", false))
	if open.size() >= 2:
		return
	var targets: Array = []
	for role in me.lineup:
		var p: Player = w.players.get(me.lineup[role])
		if p == null or Loans.is_loaned(p) or int(p.career.get("last_move_year", -1)) == w.year:
			continue
		if open.any(func(m): return m.get("player_id") == p.id):
			continue
		targets.append([p.current_ability(role) + p.reputation * 0.05, p, role])
	if targets.is_empty():
		return
	targets.sort_custom(func(a, b): return a[0] > b[0])
	var pick: Array = targets[0] if w.rng.chance(0.6) or targets.size() == 1 else targets[1]
	var p: Player = pick[1]
	var role: String = pick[2]
	var buyer = _best_buyer(w, me, p, role)
	if buyer == null:
		return
	var fee = int(TransferMarket.market_value(w, p) * w.rng.range_f(1.05, 1.45) / 10000.0) * 10000
	if fee > buyer.cash * 0.6:
		return
	var salary = int(TransferMarket.wage_demand(w, p) * w.rng.range_f(1.15, 1.4))
	var keen = player_keen(w, p, buyer, salary)
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "transfer_offer", "player_id": p.id, "from_club": buyer.id,
		"fee": fee, "salary": salary, "years": 3, "role_promise": "starter", "poach": true, "keen": keen,
		"text": "%s 想挖角 %s：轉會費 %s" % [buyer.name, p.handle, _money(fee)],
		"causes": [("%s 聲望 %d，高於本隊 %d" % [buyer.short_name, int(buyer.reputation), int(me.reputation)]) if buyer.reputation > me.reputation else ("%s 財力雄厚，開出年薪 %s" % [buyer.short_name, _money(salary)]),
			("%s 很想加盟（%s）" % [p.handle, keen_reason(w, p, buyer, salary)]) if keen else ("%s 對這次轉會興趣不大" % p.handle)],
		"resolved": false, "options": ["accept_offer", "reject_offer"]})
	w.log.add("poach_bid", w.day, [p.id, buyer.id, me.id], {"fee": fee, "keen": keen}, [])


## 有需求、付得起、聲望比玩家高的俱樂部中，挑聲望最高的一隊。
static func _best_buyer(w: WorldState, me: Club, p: Player, role: String) -> Club:
	var best: Club = null
	for c in w.clubs.values():
		if c.is_human:
			continue
		# 聲望更高的豪門，或聲望相近但財力雄厚（用高薪挖人）的俱樂部
		var rich = c.cash > maxi(me.cash, 0) * 1.3 and c.reputation >= me.reputation - 8.0
		if c.reputation < me.reputation + REP_MARGIN and not rich:
			continue
		if TransferMarket.import_blocked(w, c, p):
			continue
		var cur: Player = w.players.get(c.lineup.get(role, ""))
		if cur and cur.current_ability(role) >= p.current_ability(role) - 1.0:
			continue
		if best == null or c.reputation > best.reputation:
			best = c
	return best


## 選手是否想去：想拿冠軍（買方更強）、想要高薪、野心大，或在本隊不開心。
static func player_keen(w: WorldState, p: Player, buyer: Club, salary: int) -> bool:
	return keen_reason(w, p, buyer, salary) != ""


static func keen_reason(w: WorldState, p: Player, buyer: Club, salary: int) -> String:
	var me: Club = w.clubs.get(p.club_id)
	var cur_salary = p.contract.salary if p.contract else 0
	if "RETIRE_AT_CLUB" in p.goals and p.trait_value("loyalty") > 60:
		return ""
	if "WIN_TITLES" in p.goals and me and buyer.reputation > me.reputation + 6:
		return "想去爭冠"
	if "MONEY" in p.goals and salary > cur_salary * 1.2:
		return "薪水更高"
	if p.trait_value("ambition") > 70 and me and buyer.reputation > me.reputation + 10:
		return "野心勃勃，想去更大的舞台"
	if p.happiness < -0.15:
		return "在本隊不開心"
	return ""


## 玩家拒絕挖角報價：想走的選手失望。回傳說明文字（不想走則為空）。
static func on_rejected(w: WorldState, msg: Dictionary, p: Player) -> String:
	if not msg.get("poach", false) or not msg.get("keen", false):
		return ""
	var hit = 0.25 + maxf(p.trait_value("ambition") - 50.0, 0.0) / 200.0
	p.happiness = clampf(p.happiness - hit, -1.0, 1.0)
	p.trust_in_management = clampf(p.trust_in_management - 8.0, 0.0, 100.0)
	p.morale = clampf(p.morale - 8.0, 0.0, 100.0)
	w.log.add("blocked_move", w.day, [p.id, msg.get("from_club", "")], {}, ["玩家拒絕了他想要的轉會"])
	return "%s 對錯過轉會很失望（滿意度與信任下降）。可以找他談話或承諾給予更多資源來安撫。" % p.handle


static func _money(v: int) -> String:
	if v >= 1000000:
		return "$%.1fM" % (v / 1000000.0)
	return "$%dk" % int(v / 1000)
