## 選手自主行為：選手依自己的職業目標評估現況，並主動採取行動。
## 這不是好感度條——不同目標的選手對同一個現況會有完全不同的感受。
## 規則見 docs/rules/02-player-agency.md。
class_name CareerAgent
extends RefCounted

const EXPECTED_SHARE := {"starter": 0.85, "rotation": 0.45, "backup": 0.15, "prospect": 0.1}

## 各目標對各滿意面向的權重
const GOAL_WEIGHTS := {
	"WIN_TITLES": {"competitive": 2.0, "playing": 1.0},
	"PLAYING_TIME": {"playing": 2.2},
	"DEVELOP": {"development": 1.6, "playing": 0.8},
	"MONEY": {"salary": 2.2},
	"RETIRE_AT_CLUB": {"trust": 1.5, "loyalty": 2.0},
	"GO_ABROAD": {"competitive": 1.0},
	"STABILITY": {"trust": 1.0, "salary": 0.8, "playing": 0.8},
}


## 依目前身份與球隊內排名推算選手「認為自己應得」的出場比例。
static func expected_status(w: WorldState, p: Player) -> String:
	if p.club_id == "":
		return "starter"
	var same_role = w.club_players(p.club_id).filter(func(o): return o.primary_role == p.primary_role and not o.retired)
	same_role.sort_custom(func(a, b): return a.current_ability() > b.current_ability())
	var rank = same_role.find(p)
	if rank == 0:
		return "starter"
	if p.age(w.year) <= 19:
		return "prospect"
	return "rotation" if p.trait_value("ambition") < 60 else "starter"


static func evaluate(w: WorldState, p: Player) -> Dictionary:
	var sat := {}
	var club: Club = w.clubs.get(p.club_id)
	var team_games: int = p.season_stats.get("team_games", 0)
	var share := float(p.season_stats.get("starts", 0)) / team_games if team_games > 0 else (1.0 if p.squad_status == "starter" else 0.3)
	var expected: float = EXPECTED_SHARE.get(expected_status(w, p), 0.5)
	sat["playing"] = clampf((share - expected) * 2.0, -1.0, 1.0)
	var demand = TransferMarket.wage_demand(w, p)
	var salary = p.contract.salary if p.contract else 0
	sat["salary"] = clampf((float(salary) / maxf(demand, 1.0) - 1.0) * 2.0, -1.0, 1.0)
	var club_strength = club.reputation / 100.0 if club else 0.0
	sat["competitive"] = clampf((club_strength - p.trait_value("ambition") / 100.0) * 2.0 + 0.2, -1.0, 1.0)
	sat["trust"] = clampf((p.trust_in_management - 50.0) / 50.0, -1.0, 1.0)
	var coach: Staff = w.staff.get(club.coach_id) if club else null
	sat["development"] = clampf(((coach.development if coach else 40.0) - 50.0) / 50.0 + sat["playing"] * 0.5, -1.0, 1.0)
	sat["loyalty"] = clampf(p.trait_value("loyalty") / 100.0, 0.0, 1.0)
	return sat


static func weekly(w: WorldState, p: Player) -> void:
	if p.retired or p.club_id == "":
		return
	var sat = evaluate(w, p)
	p.satisfaction = sat
	var weights = {"playing": 0.6, "salary": 0.5, "competitive": 0.4, "trust": 0.5, "development": 0.2, "loyalty": 0.2}
	for g in p.goals:
		var gw: Dictionary = GOAL_WEIGHTS.get(g, {})
		for k in gw:
			weights[k] = weights.get(k, 0.0) + gw[k]
	var total := 0.0
	var wsum := 0.0
	for k in weights:
		total += sat.get(k, 0.0) * weights[k]
		wsum += weights[k]
	# 人會被「最在意的那件事」主導：重要面向（權重 ≥ 1）中最差的一項佔 40%
	var worst_important = 1.0
	for k in weights:
		if weights[k] >= 1.0 and sat.has(k):
			worst_important = minf(worst_important, sat[k])
	var now = 0.6 * total / wsum + 0.4 * minf(worst_important, 0.5)
	p.happiness = lerpf(p.happiness, now, Tuning.f("happiness_ema"))
	p.morale = clampf(p.morale + p.happiness * 1.5, 0.0, 100.0)
	_check_promises(w, p)
	# 行動
	var worst = _worst_aspect(sat, weights)
	if p.happiness < Tuning.f("transfer_request_threshold"):
		p.weeks_unhappy += 1
	else:
		p.weeks_unhappy = maxi(p.weeks_unhappy - 1, 0)
	if not p.transfer_requested and p.weeks_unhappy >= Tuning.i("transfer_request_weeks"):
		p.transfer_requested = true
		var causes = ["連續 %d 週不滿" % p.weeks_unhappy, "最不滿：%s" % _aspect_name(worst)]
		w.log.add("transfer_request", w.day, [p.id, p.club_id], {"aspect": worst}, causes)
		_notify(w, p, "transfer_request", "%s 正式要求離隊" % p.handle, worst, causes)
	elif p.happiness < Tuning.f("talk_threshold") and not _has_open_message(w, p.id):
		w.log.add("player_concern", w.day, [p.id, p.club_id], {"aspect": worst}, ["滿意度 %.2f" % p.happiness])
		_notify(w, p, "concern", "%s 想和你談談：%s" % [p.handle, _concern_text(worst)], worst, ["最不滿：%s" % _aspect_name(worst)])
	# 合約即將到期且不滿 → 拒絕續約
	if p.contract and p.contract.end_year <= w.year:
		var wants_out = p.happiness < -0.1 or ("GO_ABROAD" in p.goals and sat["competitive"] < 0.0)
		if wants_out and not p.refuses_renewal:
			p.refuses_renewal = true
			w.log.add("refuses_renewal", w.day, [p.id, p.club_id], {}, ["滿意度 %.2f" % p.happiness])


static func _worst_aspect(sat: Dictionary, weights: Dictionary) -> String:
	var worst := "playing"
	var worst_v := INF
	for k in sat:
		if k == "loyalty":
			continue
		var v: float = sat[k] * weights.get(k, 0.1)
		if v < worst_v:
			worst_v = v
			worst = k
	return worst


static func _check_promises(w: WorldState, p: Player) -> void:
	for pr in p.promises:
		if pr.get("resolved", false) or w.day < int(pr["due_day"]):
			continue
		pr["resolved"] = true
		var share := float(p.season_stats.get("starts", 0)) / maxf(float(p.season_stats.get("team_games", 0)), 1.0)
		var kept = share >= 0.6 if pr["type"] == "playing_time" else true
		pr["kept"] = kept
		if kept:
			p.trust_in_management = clampf(p.trust_in_management + 10.0, 0.0, 100.0)
			w.log.add("promise_kept", w.day, [p.id], pr, ["兌現承諾"])
		else:
			p.trust_in_management = clampf(p.trust_in_management - 22.0, 0.0, 100.0)
			p.happiness -= 0.3
			w.log.add("promise_broken", w.day, [p.id], pr, ["承諾的出場機會未兌現（先發率 %.0f%%）" % (share * 100.0)])


## 回應選手（第一階段的領導力系統雛形；第四階段擴充為完整對話系統）。
## 效果依選手個性與對管理層的信任而不同，並非固定加減。
static func respond(w: WorldState, p: Player, response: String) -> Dictionary:
	var trust = p.trust_in_management / 100.0
	var temper = p.trait_value("temperament") / 100.0
	var effect := 0.0
	var note := ""
	match response:
		"promise_playing_time":
			p.promises.append({"type": "playing_time", "made_day": w.day, "due_day": w.day + 42})
			effect = 0.25 * (0.5 + trust)
			note = "選手暫時接受，但會記住這個承諾"
		"explain_situation":
			effect = 0.18 * (trust * 1.6 - 0.3)
			note = "信任你的選手會理解；不信任的選手覺得是藉口" if trust < 0.45 else "選手理解球隊的考量"
		"demand_patience":
			effect = -0.1 + 0.25 * temper
			p.trust_in_management -= 4.0 * (1.0 - temper)
			note = "情緒穩定的選手能接受；性格衝動的選手會更不滿"
		"transfer_list":
			p.transfer_requested = true
			effect = 0.35 if p.happiness < 0.0 else -0.2
			note = "選手被放上轉會名單"
		"dismiss":
			effect = -0.25
			p.trust_in_management -= 12.0
			note = "選手感到不被尊重"
	p.happiness = clampf(p.happiness + effect, -1.0, 1.0)
	p.trust_in_management = clampf(p.trust_in_management, 0.0, 100.0)
	w.log.add("player_talk", w.day, [p.id], {"response": response, "effect": effect}, [note])
	for m in w.inbox:
		if m.get("player_id") == p.id and not m.get("resolved", false):
			m["resolved"] = true
	return {"effect": effect, "note": note}


## 退役判斷（賽季結束）。
static func retirement_check(w: WorldState, p: Player, rng: SimRng) -> bool:
	var a = p.age(w.year)
	if a < 26:
		return false
	var prob = (a - 26) * 0.06
	prob += maxf(55.0 - p.current_ability(), 0.0) * 0.015
	prob += maxf(50.0 - p.motivation, 0.0) * 0.004
	if p.club_id == "":
		prob += 0.2
	if "RETIRE_AT_CLUB" in p.goals and p.contract and p.contract.end_year <= w.year and p.club_id != "":
		prob += 0.15  # 想在母隊退役：合約結束時傾向就此退休
	if "WIN_TITLES" in p.goals and p.career.get("titles", 0) == 0:
		prob -= 0.1   # 還沒拿過冠軍的選手不想退役
	return rng.chance(clampf(prob, 0.0, 0.95))


static func _notify(w: WorldState, p: Player, kind: String, text: String, aspect: String, causes: Array) -> void:
	if p.club_id != w.human_club_id:
		return
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": kind, "player_id": p.id, "text": text,
		"aspect": aspect, "causes": causes, "resolved": false,
		"options": ["promise_playing_time", "explain_situation", "demand_patience", "transfer_list", "dismiss"]})


static func _has_open_message(w: WorldState, pid: String) -> bool:
	return w.inbox.any(func(m): return m.get("player_id") == pid and not m.get("resolved", false))


static func _aspect_name(a: String) -> String:
	return {"playing": "出場機會", "salary": "薪資", "competitive": "球隊競爭力", "trust": "對管理層的信任", "development": "個人發展"}.get(a, a)


static func _concern_text(a: String) -> String:
	return {"playing": "我需要更多上場時間。", "salary": "我覺得我的薪水配不上我的表現。", "competitive": "我不確定這支隊伍有爭冠的野心。",
		"trust": "我對俱樂部的決定越來越沒有信心。", "development": "我覺得我在這裡沒有成長。"}.get(a, "我們需要談談。")
