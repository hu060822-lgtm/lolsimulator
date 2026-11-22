## 隨機事件：直播爭議、贊助活動、設備故障、選手請假……
##
## 事件定義來自資料模組（events.json，存在 w.event_defs）。每個事件有觸發條件、對象（選手或俱樂部）
## 與數個選項；選項的效果是資料（effects），由這裡解讀。玩家俱樂部會在收件匣選擇處理方式，
## AI 俱樂部依定義中的 "ai" 選項處理。
##
## effects 格式：
##   "target": 對象選手 {morale, stress, fatigue, trust, confidence, reputation, motivation}
##   "roster": 全隊選手（同上）
##   "club":   {cash, fans_pct, opinion, chemistry, draft_familiarity, reputation}
##   "team_relations": 對象選手與隊友（無對象時為全隊）關係變化
class_name RandomEvents
extends RefCounted

const WEEKLY_CHANCE := 0.07
const HUMAN_WEEKLY_CHANCE := 0.11


static func weekly(w: WorldState, club: Club) -> void:
	if w.event_defs.is_empty() or club.roster.is_empty():
		return
	if not w.rng.chance(HUMAN_WEEKLY_CHANCE if club.is_human else WEEKLY_CHANCE):
		return
	trigger_random(w, club)


## 依權重抽一個符合條件的事件並觸發。回傳觸發的事件 id（無則空字串）。
static func trigger_random(w: WorldState, club: Club) -> String:
	var candidates: Array = []
	var weights: Array = []
	for ev in w.event_defs:
		var targets = _targets(w, club, ev)
		if ev.get("target", "club") == "player" and targets.is_empty():
			continue
		candidates.append([ev, targets])
		weights.append(float(ev.get("weight", 1)))
	if candidates.is_empty():
		return ""
	var total := 0.0
	for x in weights:
		total += x
	var r = w.rng.range_f(0.0, total)
	var pick: Array = candidates[-1]
	for i in candidates.size():
		r -= weights[i]
		if r <= 0.0:
			pick = candidates[i]
			break
	var ev: Dictionary = pick[0]
	var target: Player = null
	if not pick[1].is_empty():
		target = w.rng.pick(pick[1])
	fire(w, club, ev, target)
	return ev["id"]


static func _targets(w: WorldState, club: Club, ev: Dictionary) -> Array:
	if ev.get("target", "club") != "player":
		return []
	var cond: Dictionary = ev.get("condition", {})
	var out: Array = []
	for pid in club.roster:
		var p: Player = w.players[pid]
		var ok := true
		for t in cond.get("trait_below", {}):
			if p.trait_value(t) >= float(cond["trait_below"][t]):
				ok = false
		for t in cond.get("trait_above", {}):
			if p.trait_value(t) <= float(cond["trait_above"][t]):
				ok = false
		if cond.has("min_reputation") and p.reputation < float(cond["min_reputation"]):
			ok = false
		if cond.has("min_ability") and p.current_ability() < float(cond["min_ability"]):
			ok = false
		if ok:
			out.append(p)
	return out


static func find_def(w: WorldState, id: String) -> Dictionary:
	for ev in w.event_defs:
		if ev.get("id") == id:
			return ev
	return {}


static func _fmt(w: WorldState, s: String, club: Club, target: Player) -> String:
	return s.format({"player": target.handle if target else "", "club": club.name, "club_short": club.short_name})


static func fire(w: WorldState, club: Club, ev: Dictionary, target: Player) -> void:
	var text = _fmt(w, ev.get("text", ev["id"]), club, target)
	var ids: Array = [club.id] + ([target.id] if target else [])
	if ev.has("headline"):
		Media.post(w, "event", _fmt(w, ev["headline"], club, target), ids, -0.2)
	w.log.add("event", w.day, ids, {"event": ev["id"]}, [])
	var options: Array = ev.get("options", [])
	if club.is_human and options.size() > 1:
		var labels := {}
		var opts: Array = []
		for o in options:
			labels["ev:" + o["id"]] = o.get("label", o["id"])
			opts.append("ev:" + o["id"])
		w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "event", "event_id": ev["id"], "club_id": club.id,
			"player_id": target.id if target else "", "text": text, "resolved": false, "options": opts, "option_labels": labels})
		return
	# 單一選項的事件直接生效；AI 依預設選項處理
	var choice: String = ev.get("ai", options[0]["id"] if not options.is_empty() else "")
	var res = apply_option(w, club, ev, choice, target)
	if club.is_human:
		w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "event", "event_id": ev["id"], "player_id": target.id if target else "",
			"text": text + ("。" + res["note"] if res["note"] != "" else ""), "resolved": false, "options": ["acknowledge"]})


## 玩家在收件匣中選擇處理方式（option 形如 "ev:fine"）。
static func resolve(w: WorldState, msg: Dictionary, option: String) -> Dictionary:
	msg["resolved"] = true
	var ev = find_def(w, msg.get("event_id", ""))
	var club: Club = w.clubs.get(msg.get("club_id", w.human_club_id))
	if ev.is_empty() or club == null:
		return {"note": "事件已失效"}
	var target: Player = w.players.get(msg.get("player_id", ""))
	if target and target.club_id != club.id:
		target = null
		if ev.get("target", "club") == "player":
			return {"note": "選手已不在隊上"}
	return apply_option(w, club, ev, option.trim_prefix("ev:"), target)


static func apply_option(w: WorldState, club: Club, ev: Dictionary, option_id: String, target: Player) -> Dictionary:
	var opt: Dictionary = {}
	for o in ev.get("options", []):
		if o["id"] == option_id:
			opt = o
	if opt.is_empty():
		return {"note": ""}
	var fx: Dictionary = opt.get("effects", {})
	if target and fx.has("target"):
		_apply_player(target, fx["target"])
	if fx.has("roster"):
		for pid in club.roster:
			_apply_player(w.players[pid], fx["roster"])
	if fx.has("club"):
		_apply_club(club, fx["club"])
	if fx.has("team_relations"):
		var d = float(fx["team_relations"])
		var ids: Array = club.roster
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				if target == null or ids[i] == target.id or ids[j] == target.id:
					Relationships.change(w, ids[i], ids[j], d)
	w.log.add("event_choice", w.day, [club.id], {"event": ev["id"], "option": option_id}, [])
	return {"note": "已處理：%s" % opt.get("label", option_id) if club.is_human else ""}


static func _apply_player(p: Player, e: Dictionary) -> void:
	for k in e:
		var v = float(e[k])
		match k:
			"morale":
				p.morale = clampf(p.morale + v, 0.0, 100.0)
			"stress":
				p.stress = clampf(p.stress + v, 0.0, 100.0)
			"fatigue":
				p.fatigue = clampf(p.fatigue + v, 0.0, 100.0)
			"trust":
				p.trust_in_management = clampf(p.trust_in_management + v, 0.0, 100.0)
			"confidence":
				p.confidence = clampf(p.confidence + v, 0.0, 100.0)
			"reputation":
				p.reputation = clampf(p.reputation + v, 0.0, 100.0)
			"motivation":
				p.motivation = clampf(p.motivation + v, 0.0, 100.0)


static func _apply_club(c: Club, e: Dictionary) -> void:
	for k in e:
		var v = float(e[k])
		match k:
			"cash":
				if v >= 0:
					Finance.earn(c, "events", int(v))
				else:
					Finance.spend(c, "events", int(-v))
			"fans_pct":
				c.fanbase = int(c.fanbase * (1.0 + v / 100.0))
			"opinion":
				c.opinion = clampf(c.opinion + v, -100.0, 100.0)
			"chemistry":
				c.chemistry = clampf(c.chemistry + v, 0.0, 100.0)
			"draft_familiarity":
				c.draft_familiarity = clampf(c.draft_familiarity + v, 0.0, 100.0)
			"reputation":
				c.reputation = clampf(c.reputation + v, 5.0, 99.0)
