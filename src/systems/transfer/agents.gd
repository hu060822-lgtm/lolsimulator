## 經紀人：每位選手隸屬一家經紀公司（依選手 id 決定，不消耗亂數）。
## 經紀人會抬高薪資要求、在簽約時抽成，並在選手被低薪綁住時替他要求加薪。
class_name Agents
extends RefCounted

## [名稱, 貪婪 0..1, 人脈 0..1]
const AGENCIES := [
	["Apex Talent", 0.85, 0.80], ["Northstar Agency", 0.55, 0.60], ["Blue Lotus Management", 0.35, 0.45],
	["Sigma Esports Group", 0.70, 0.75], ["Harbor Sports", 0.25, 0.30], ["Crown & Key", 0.90, 0.55],
	["Silverline Partners", 0.45, 0.70], ["Pixel Path", 0.30, 0.35], ["Titan Representation", 0.75, 0.90],
	["Lumen Agency", 0.50, 0.40], ["Riverstone Talent", 0.40, 0.55], ["Vanguard Pro", 0.65, 0.65],
	["Quiet Harbor", 0.20, 0.25], ["Golden Gate Esports", 0.60, 0.50], ["Orbit Management", 0.50, 0.85],
	["Family-managed", 0.15, 0.10],
]


static func of(p: Player) -> Dictionary:
	var a: Array = AGENCIES[absi(hash(p.id + "agent")) % AGENCIES.size()]
	return {"name": a[0], "greed": float(a[1]), "influence": float(a[2])}


## 經紀人對薪資要求的倍率（0.9..1.1）。
static func wage_factor(p: Player) -> float:
	return 1.0 + (float(of(p)["greed"]) - 0.5) * 0.2


## 簽約時俱樂部要付給經紀人的佣金（年薪的 4～12%）。
static func fee(p: Player, salary: int) -> int:
	return int(salary * (0.04 + float(of(p)["greed"]) * 0.08))


static func greed_word(g: float) -> String:
	return "非常強硬" if g >= 0.8 else ("強硬" if g >= 0.6 else ("普通" if g >= 0.35 else "好說話"))


## 不用亂數的機率判定：同一位選手、同一天結果固定。
static func _roll(p: Player, day: int, chance: float) -> bool:
	return float(absi(hash("%s:%d:agent" % [p.id, day])) % 10000) / 10000.0 < chance


## 每週：玩家俱樂部被低薪綁住的選手，經紀人可能來要求加薪。
static func weekly(w: WorldState, club: Club) -> void:
	if not club.is_human or w.phase == WorldState.PHASE_OFFSEASON:
		return
	for pid in club.roster:
		var p: Player = w.players[pid]
		if p.contract == null or p.contract.club_id != club.id or p.contract.years_left(w.year) < 1:
			continue
		if w.day - int(p.career.get("agent_ask_day", -999)) < 120:
			continue
		if w.inbox.any(func(m): return m.get("kind") == "agent_raise" and m.get("player_id") == p.id and not m.get("resolved", false)):
			continue
		var ag = of(p)
		var demand = TransferMarket.wage_demand(w, p)
		if demand < p.contract.salary * (1.3 - float(ag["greed"]) * 0.15):
			continue
		if not _roll(p, w.day, 0.06 + float(ag["greed"]) * 0.12):
			continue
		p.career["agent_ask_day"] = w.day
		var new_salary = int(demand * 0.95)
		w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "agent_raise", "player_id": p.id, "new_salary": new_salary,
			"text": "%s 的經紀人（%s）認為他的年薪 %s 低於身價，要求調整為 %s，並暗示有其他俱樂部感興趣。" % [p.handle, ag["name"], UIKit.money(p.contract.salary), UIKit.money(new_salary)],
			"resolved": false, "options": ["accept_raise", "refuse_raise"]})
		w.log.add("agent_raise", w.day, [p.id, club.id], {"salary": p.contract.salary, "ask": new_salary}, ["經紀人：%s（%s）" % [ag["name"], greed_word(ag["greed"])]])


static func resolve_raise(w: WorldState, msg: Dictionary, accept: bool) -> Dictionary:
	msg["resolved"] = true
	var p: Player = w.players.get(msg.get("player_id", ""))
	if p == null or p.contract == null or p.club_id != w.human_club_id:
		return {"note": "要求已失效"}
	var ag = of(p)
	if accept:
		var club: Club = w.clubs[p.club_id]
		p.contract.salary = int(msg["new_salary"])
		Finance.spend(club, "agent_fees", fee(p, int(msg["new_salary"])) / 2)
		p.happiness = clampf(p.happiness + 0.2, -1.0, 1.0)
		p.trust_in_management = clampf(p.trust_in_management + 6.0, 0.0, 100.0)
		p.morale = clampf(p.morale + 5.0, 0.0, 100.0)
		return {"note": "已加薪至 %s，%s 很滿意。" % [UIKit.money(p.contract.salary), p.handle]}
	p.happiness = clampf(p.happiness - 0.12 - float(ag["greed"]) * 0.15, -1.0, 1.0)
	p.trust_in_management = clampf(p.trust_in_management - 6.0, 0.0, 100.0)
	var leave = float(ag["greed"]) + float(ag["influence"]) > 1.35 or p.happiness < -0.3
	if leave:
		p.transfer_requested = true
		return {"note": "經紀人放話要替 %s 找新東家，選手已要求離隊。" % p.handle}
	return {"note": "%s 對此不太高興，但暫時接受。" % p.handle}
