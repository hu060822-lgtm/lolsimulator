## 故事線與傳承：讓玩了很多季的世界有記憶。
##
## - 生涯里程碑：出賽 100／200／300／500 場、擊殺 500／1000／2000、勝場 100／200。
##   媒體報導；自家選手達成時全隊士氣 +3、本人士氣 +6。
## - 退役告別：在你隊上打過兩季以上（或退役時仍在隊上）的選手退役時，收件匣出現告別訊息：
##   - 舉辦退役儀式（花費 CEREMONY_COST）：粉絲 +2%、品牌 +2、全隊士氣 +4，並把他的 ID 列為俱樂部傳奇。
##   - 邀請他加入教練團：以選手的比賽理解產生一位助理教練（或分析師），直接上任。
##   - 簡單道別。
## - 名人堂：退役選手依冠軍、MVP、出賽與知名度計分，達 HOF_SCORE 即入選，記在 w.history["hall_of_fame"]。
class_name Legacy
extends RefCounted

const GAMES := [100, 200, 300, 500]
const KILLS := [500, 1000, 2000]
const WINS := [100, 200]
const CEREMONY_COST := 50000
const HOF_SCORE := 10.0


static func hall_of_fame(w: WorldState) -> Array:
	if not w.history.has("hall_of_fame"):
		w.history["hall_of_fame"] = []
	return w.history["hall_of_fame"]


static func hof_score(p: Player) -> float:
	return int(p.career.get("titles", 0)) * 3.0 + int(p.career.get("mvps", 0)) * 2.0 + int(p.career.get("games", 0)) / 100.0 + maxf(p.reputation - 60.0, 0.0) / 5.0


## 系列賽結束後檢查參賽選手的里程碑。
static func check_milestones(w: WorldState, series: Dictionary) -> void:
	var seen := {}
	for g in series["games"]:
		for pid in g["players"]:
			seen[pid] = true
	for pid in seen:
		var p: Player = w.players.get(pid)
		if p == null:
			continue
		var done: Array = p.career.get("milestones", [])
		for spec in [["games", GAMES, "出賽 %d 場"], ["kills", KILLS, "生涯 %d 殺"], ["wins", WINS, "生涯 %d 勝"]]:
			var v := int(p.career.get(spec[0], 0))
			for t: int in spec[1]:
				var key := "%s_%d" % [spec[0], t]
				if v >= t and not key in done:
					done.append(key)
					_celebrate(w, p, spec[2] % t)
		p.career["milestones"] = done


static func _celebrate(w: WorldState, p: Player, what: String) -> void:
	var club: Club = w.clubs.get(p.club_id)
	if club and club.is_human:
		p.morale = clampf(p.morale + 6.0, 0.0, 100.0)
		for pid in club.roster:
			if pid != p.id:
				w.players[pid].morale = clampf(w.players[pid].morale + 3.0, 0.0, 100.0)
		Media.post(w, "feature", "里程碑！%s 達成%s" % [p.handle, what], [p.id, club.id], 0.5)
	elif p.reputation >= 55.0:
		Media.post(w, "feature", "%s 達成%s" % [p.handle, what], [p.id], 0.2)
	w.log.add("milestone", w.day, [p.id], {"what": what}, [])


## 選手退役（WorldSimulator._retirements 在選手離隊後呼叫）。
static func on_retire(w: WorldState, p: Player, club_id: String) -> void:
	var score := hof_score(p)
	if score >= HOF_SCORE:
		hall_of_fame(w).append({"year": w.year, "player_id": p.id, "handle": p.handle, "role": p.primary_role,
			"titles": int(p.career.get("titles", 0)), "mvps": int(p.career.get("mvps", 0)), "games": int(p.career.get("games", 0)),
			"score": snappedf(score, 0.1), "club_id": _main_club(p)})
		Media.post(w, "feature", "名人堂：%s 正式退役並入選名人堂（%d 冠、%d MVP、%d 場）" % [p.handle, int(p.career.get("titles", 0)), int(p.career.get("mvps", 0)), int(p.career.get("games", 0))], [p.id], 0.6)
	var me: Club = w.human_club()
	if me == null:
		return
	var seasons := p.history.filter(func(h): return h.get("club_id", "") == me.id).size()
	if club_id != me.id and seasons < 2:
		return
	var opts := ["fw:ceremony", "fw:coach", "fw:simple"]
	var labels := {"fw:ceremony": "舉辦退役儀式（$%dK）" % (CEREMONY_COST / 1000), "fw:coach": "邀請他加入教練團", "fw:simple": "簡單道別"}
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "farewell", "player_id": p.id,
		"text": "%s 宣布退役。他在 %s 打了 %d 季，生涯 %d 場、%d 冠。要怎麼送別這位老將？" % [p.handle, me.short_name, maxi(seasons, 1), int(p.career.get("games", 0)), int(p.career.get("titles", 0))],
		"resolved": false, "options": opts, "option_labels": labels})


## 最常效力的俱樂部。
static func _main_club(p: Player) -> String:
	var counts := {}
	for h in p.history:
		var c: String = h.get("club_id", "")
		if c != "":
			counts[c] = int(counts.get(c, 0)) + 1
	var best := ""
	for c in counts:
		if best == "" or counts[c] > counts[best]:
			best = c
	return best


static func resolve(w: WorldState, msg: Dictionary, option: String) -> Dictionary:
	var me: Club = w.human_club()
	var p: Player = w.players.get(msg.get("player_id", ""))
	msg["resolved"] = true
	if me == null or p == null:
		return {"note": "已處理"}
	match option.trim_prefix("fw:"):
		"ceremony":
			Finance.spend(me, "events", CEREMONY_COST)
			me.fanbase = int(me.fanbase * 1.02)
			me.brand = clampf(me.brand + 2.0, 0.0, 100.0)
			for pid in me.roster:
				w.players[pid].morale = clampf(w.players[pid].morale + 4.0, 0.0, 100.0)
			me.legends.append({"player_id": p.id, "handle": p.handle, "year": w.year})
			Media.post(w, "feature", "%s 為 %s 舉辦退役儀式，他的 ID 從此只屬於這支隊伍" % [me.short_name, p.handle], [p.id, me.id], 0.6)
			return {"note": "%s 成為俱樂部傳奇" % p.handle}
		"coach":
			var s := coach_from_player(w, p)
			w.staff[s.id] = s
			var r := StaffSystem.hire(w, me, s, StaffSystem.wage_demand(s), 2)
			if not r.get("ok", false):
				return {"note": r.get("note", "")}
			Media.post(w, "feature", "%s 退役後留隊擔任%s" % [p.handle, StaffSystem.ROLE_NAMES[s.role]], [p.id, me.id], 0.3)
			return {"note": r.get("note", "")}
	return {"note": "你向 %s 道別" % p.handle}


## 以退役選手的比賽理解產生教練（指揮與 BP 理解好的人當分析師，其他當助理教練）。
static func coach_from_player(w: WorldState, p: Player) -> Staff:
	var role := "analyst" if p.skill("draft_iq") > p.skill("shotcalling") else "assistant_coach"
	var s := PlayerGenerator.generate_staff(w, w.rng, 0.4, role)
	s.name = p.handle
	s.birth_year = p.birth_year
	s.tactical = clampf((p.skill("decision_making") + p.skill("shotcalling")) / 2.0, 30.0, 92.0)
	s.drafting = clampf((p.skill("draft_iq") + p.skill("map_awareness")) / 2.0, 30.0, 92.0)
	s.development = clampf(p.trait_value("professionalism") * 0.8 + 10.0, 30.0, 90.0)
	s.man_management = clampf(p.trait_value("communication") * 0.8 + 10.0, 30.0, 90.0)
	s.adaptability = clampf(p.skill("adaptability"), 30.0, 92.0)
	s.reputation = clampf(p.reputation, 20.0, 90.0)
	return s
