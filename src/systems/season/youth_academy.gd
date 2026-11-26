## 青訓試訓週：每個休賽季，青訓營推薦三名 16～17 歲的新人來試訓。
##
## - 只看得到「潛力估計區間」：球探能力越好區間越窄，但估計中心本身就有誤差，
##   有人會是被低估的天才，也有人只是試訓時手感好。
## - 選項：簽下其中一人（青訓合約，薪資低、三年、新秀定位）、多看一週（花錢讓區間縮小、估計更準），或全部放走。
## - 沒被簽走的人會進入自由球員市場，AI 球隊也可能簽走。
class_name YouthAcademy
extends RefCounted

const PROSPECTS := 3
const EXTRA_LOOK_COST := 25000
const SALARY := 30000
const ROLE_SHORT := {"TOP": "TOP", "JUNGLE": "JG", "MID": "MID", "ADC": "ADC", "SUPPORT": "SUP"}


## 估計區間的半寬：球探能力 40 → 約 ±16；80 → 約 ±8。
static func half_width(w: WorldState, club: Club, looks: int) -> float:
	var scout := StaffSystem.rating(w, club, "scouting")
	return clampf(24.0 - scout * 0.2, 6.0, 20.0) / (1.0 + 0.8 * looks)


static func tryouts(w: WorldState) -> void:
	var me: Club = w.human_club()
	if me == null:
		return
	var lg: League = w.leagues.get(me.league_id)
	var q := 0.45 if lg and lg.tier <= 1 else 0.35
	var ids: Array = []
	var est := {}
	for i in PROSPECTS:
		var role: String = Attr.ROLES[w.rng.range_i(0, 4)]
		var p := PlayerGenerator.generate(w, w.rng, me.region, role, clampf(w.rng.normal(q, 0.15), 0.1, 0.9), true)
		p.birth_year = w.year + 1 - w.rng.range_i(16, 17)
		if w.rng.chance(0.15):
			p.potential = clampf(p.potential + 12.0, 40.0, 97.0)  # 隱藏的天才
		w.players[p.id] = p
		w.free_agents.append(p.id)
		p.career["tryout_club"] = me.id
		ids.append(p.id)
		est[p.id] = _estimate(w, me, p, 0)
	var msg := {"id": w.new_id("msg"), "day": w.day, "kind": "tryout", "player_id": "", "prospects": ids, "estimates": est, "looks": 0,
		"resolved": false}
	_refresh_message(w, msg)
	w.inbox.append(msg)
	w.log.add("tryout", w.day, [me.id] + ids, {}, [])


static func _estimate(w: WorldState, club: Club, p: Player, looks: int) -> Dictionary:
	var hw := half_width(w, club, looks)
	var center := p.potential + w.rng.normal(0.0, hw * 0.6)
	return {"lo": roundi(clampf(center - hw, 30.0, 99.0)), "hi": roundi(clampf(center + hw, 30.0, 99.0))}


static func _refresh_message(w: WorldState, msg: Dictionary) -> void:
	var opts: Array = []
	var labels := {}
	var lines: Array = []
	for pid in msg["prospects"]:
		var p: Player = w.players[pid]
		var e: Dictionary = msg["estimates"][pid]
		var arch := PlayerArchetype.of(p)
		opts.append("try:" + pid)
		labels["try:" + pid] = "簽下 %s" % p.handle
		lines.append("・%s（%s，%d 歲，%s）目前能力 %d，潛力估計 %d～%d" % [p.handle, ROLE_SHORT.get(p.primary_role, p.primary_role), p.age(w.year + 1), arch["name"], roundi(p.current_ability()), int(e["lo"]), int(e["hi"])])
	if int(msg["looks"]) < 2:
		opts.append("try:look")
		labels["try:look"] = "再看一週（$%dK）" % (EXTRA_LOOK_COST / 1000)
	opts.append("try:none")
	labels["try:none"] = "都不簽"
	msg["options"] = opts
	msg["option_labels"] = labels
	msg["text"] = "青訓試訓週：青訓營推薦了三名新人。簽下的人拿三年青訓合約（年薪 $%dK），潛力估計只是球探的判斷，不一定準。\n%s" % [SALARY / 1000, "\n".join(lines)]


static func resolve(w: WorldState, msg: Dictionary, option: String) -> Dictionary:
	var me: Club = w.human_club()
	var choice := option.trim_prefix("try:")
	if choice == "look":
		if me.cash < EXTRA_LOOK_COST:
			return {"note": "資金不足"}
		Finance.spend(me, "scouting", EXTRA_LOOK_COST)
		msg["looks"] = int(msg["looks"]) + 1
		for pid in msg["prospects"]:
			msg["estimates"][pid] = _estimate(w, me, w.players[pid], int(msg["looks"]))
			Scouting.observe(w, pid, 0.3)
		_refresh_message(w, msg)
		return {"note": "球探多看了一週，估計區間縮小了"}
	msg["resolved"] = true
	if choice == "none":
		return {"note": "這次沒有簽下任何新人"}
	var p: Player = w.players.get(choice)
	if p == null or p.club_id != "":
		return {"note": "這名新人已經有了去處"}
	if me.roster.size() >= Tuning.i("max_roster") + 2:
		msg["resolved"] = false
		return {"note": "名單已滿，請先釋出或租借選手"}
	var c := Contract.new()
	c.club_id = me.id
	c.salary = SALARY
	c.start_year = w.year + 1 if w.phase == WorldState.PHASE_OFFSEASON else w.year
	c.end_year = c.start_year + 2
	c.role_promise = "prospect"
	p.contract = c
	TransferMarket._move(w, p, null, me, 0)
	p.career["academy"] = me.id
	Scouting.observe(w, p.id, 1.0)
	return {"note": "%s 加入青訓，簽下三年合約" % p.handle, "signed": true}
