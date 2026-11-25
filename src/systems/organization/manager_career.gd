## 經理生涯：你不是俱樂部本身，而是一位會被評價、會被開除、也會被挖角的總教練。
##
## - 經理聲望（0..100）：每季依「實際名次 vs 外界預期」、冠軍與國際賽成績變動。
## - 被開除：賽季結束時董事會信心低於 FIRE_CONFIDENCE，董事會解除職務；收件匣會列出願意聘請你的
##   俱樂部（通常聲望較低），必須選一隊接手。
## - 被挖角：成績亮眼時，聲望更高、本季表現不如預期的俱樂部會在休賽季邀請你執教。可以接受（換隊）
##   或婉拒（董事會感受到你的忠誠，信心上升）。
## - 換隊：原俱樂部交還 AI 經營；你的球探情報與委派設定會跟著你走。
class_name ManagerCareer
extends RefCounted

const FIRE_CONFIDENCE := 22.0
const MAX_OFFERS := 2


static func data(w: WorldState) -> Dictionary:
	if w.manager.is_empty():
		var c: Club = w.human_club()
		w.manager = {"reputation": 25.0 + (c.reputation * 0.3 if c else 15.0), "seasons": [], "fired": 0, "titles": 0, "jobs": [c.id if c else ""]}
	return w.manager


## 賽季結束：更新經理聲望與生涯紀錄，判斷是否被開除、是否有球隊來挖角。
static func season_review(w: WorldState) -> void:
	var me: Club = w.human_club()
	if me == null or me.history.is_empty():
		return
	var m := data(w)
	var h: Dictionary = me.history[-1]
	var lg: League = w.leagues.get(me.league_id)
	var n: int = lg.club_ids.size() if lg else 8
	var expected := Media.expected_position(w, me)
	var pos := int(h.get("position", n))
	var delta := (expected - pos) / float(n) * 18.0
	if h.get("champion", false):
		delta += 8.0
		m["titles"] = int(m.get("titles", 0)) + 1
	if str(h.get("worlds", "")) != "":
		delta += 3.0
	if int(h.get("tier", 1)) >= 2:
		delta -= 2.0
	m["reputation"] = clampf(float(m["reputation"]) + delta, 0.0, 100.0)
	m["seasons"].append({"year": w.year, "club_id": me.id, "position": pos, "expected": roundi(expected), "champion": h.get("champion", false),
		"board": roundi(me.board_confidence), "rep_change": snappedf(delta, 0.1)})
	if me.board_confidence < FIRE_CONFIDENCE:
		_fire(w, me, pos, expected)
	elif delta > 0.0 or float(m["reputation"]) > me.reputation + 5.0:
		_offers(w, me)


static func _fire(w: WorldState, me: Club, pos: int, expected: float) -> void:
	var m := data(w)
	m["fired"] = int(m.get("fired", 0)) + 1
	m["reputation"] = clampf(float(m["reputation"]) - 8.0, 0.0, 100.0)
	var cands := _candidates(w, me, -40.0, 3.0, 3)
	if cands.is_empty():
		cands = _lowest(w, me, 2)
	var opts: Array = []
	var labels := {}
	for c in cands:
		opts.append("job:" + c.id)
		labels["job:" + c.id] = "接手 %s（聲望 %d）" % [c.name, int(c.reputation)]
	Media.post(w, "crisis", "%s 宣布與總教練分道揚鑣" % me.name, [me.id], -0.5)
	w.log.add("manager_fired", w.day, [me.id], {"position": pos}, ["董事會信心 %d" % int(me.board_confidence)])
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "fired", "text": "董事會決定解除你的職務（本季第 %d 名，外界預期第 %d 名，董事會信心 %d）。以下俱樂部願意聘請你，請選擇下一份工作。" % [pos, roundi(expected), int(me.board_confidence)],
		"causes": ["經理聲望 %d" % int(m["reputation"])], "resolved": false, "options": opts, "option_labels": labels})


static func _offers(w: WorldState, me: Club) -> void:
	var m := data(w)
	var cands := _candidates(w, me, 5.0, 25.0, MAX_OFFERS)
	for c in cands:
		w.log.add("job_offer", w.day, [c.id, me.id], {}, [])
		w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "job_offer", "club_id": c.id,
			"text": "%s 邀請你擔任總教練（聲望 %d，本隊 %d）" % [c.name, int(c.reputation), int(me.reputation)],
			"causes": ["經理聲望 %d" % int(m["reputation"]), "%s 現金 %s・薪資預算 %s" % [c.short_name, _money(c.cash), _money(c.wage_budget)]],
			"resolved": false, "options": ["job:" + c.id, "job:decline"],
			"option_labels": {"job:" + c.id: "接受，轉任 %s" % c.short_name, "job:decline": "婉拒，留在 %s" % me.short_name}})


## 願意聘請你的 AI 一級聯賽俱樂部：聲望在 [本隊 + lo, 經理聲望 + hi] 之間，本季表現不如預期者優先。
static func _candidates(w: WorldState, me: Club, lo: float, hi: float, n: int) -> Array:
	var m := data(w)
	var out: Array = []
	for c in w.clubs.values():
		if c.is_human:
			continue
		var lg: League = w.leagues.get(c.league_id)
		if lg == null or lg.tier > 1:
			continue
		if c.reputation < me.reputation + lo or c.reputation > float(m["reputation"]) + hi:
			continue
		var under := 0.0
		if not c.history.is_empty():
			under = float(c.history[-1].get("position", 0)) - Media.expected_position(w, c)
		out.append([under + c.reputation * 0.05 + w.rng.range_f(0.0, 1.5), c])
	out.sort_custom(func(a, b): return a[0] > b[0])
	return out.slice(0, n).map(func(x): return x[1])


static func _lowest(w: WorldState, me: Club, n: int) -> Array:
	var all: Array = w.clubs.values().filter(func(c): return not c.is_human)
	all.sort_custom(func(a, b): return a.reputation < b.reputation)
	return all.slice(0, n)


## 玩家回覆工作邀請。option = "job:<club_id>" 或 "job:decline"。
static func respond(w: WorldState, msg: Dictionary, option: String) -> Dictionary:
	msg["resolved"] = true
	var me: Club = w.human_club()
	var target := option.trim_prefix("job:")
	if target == "decline":
		if me:
			me.board_confidence = clampf(me.board_confidence + 6.0, 0.0, 100.0)
		return {"note": "你婉拒了邀請。消息傳開後，董事會對你的忠誠印象深刻（信心上升）"}
	if not w.clubs.has(target):
		return {"note": "這個職位已經不存在"}
	var from := me.name if me else ""
	switch_club(w, target)
	return {"note": "你離開 %s，正式接手 %s！" % [from, w.clubs[target].name], "switched": true}


## 換隊：原俱樂部交還 AI，新俱樂部改由玩家經營。
static func switch_club(w: WorldState, new_id: String) -> void:
	var old: Club = w.human_club()
	var nc: Club = w.clubs[new_id]
	var m := data(w)
	if old:
		old.is_human = false
		nc.settings = old.settings.duplicate()
		for pid in old.scout_knowledge:
			nc.scout_knowledge[pid] = maxf(float(nc.scout_knowledge.get(pid, 0.0)), float(old.scout_knowledge[pid]))
		old.sponsor_offers = []
		ClubAI.choose_style(w, old)
	nc.is_human = true
	nc.tactics.erase("style_year")
	nc.board_confidence = 60.0
	nc.crisis_flags = {}
	w.human_club_id = new_id
	m["jobs"].append(new_id)
	# 舊隊的待辦事項（選手要求、報價、其他工作邀請）全部失效
	for msg in w.inbox:
		if msg.get("resolved", false):
			continue
		var pid: String = msg.get("player_id", "")
		if msg.get("kind", "") in ["job_offer", "fired"] or (pid != "" and not nc.roster.has(pid)) or msg.get("kind", "") in ["crisis", "sponsor_offers"]:
			msg["resolved"] = true
	Media.post(w, "transfer", "%s 宣布新任總教練上任" % nc.name, [nc.id], 0.3)
	w.log.add("manager_hired", w.day, [nc.id] + ([old.id] if old else []), {}, [])


## 新賽季開始前：被開除卻沒選新工作 → 自動接手第一個邀請；其他邀請過期。
static func preseason_cleanup(w: WorldState) -> void:
	for msg in w.inbox:
		if msg.get("resolved", false):
			continue
		if msg.get("kind", "") == "fired":
			respond(w, msg, msg["options"][0])
		elif msg.get("kind", "") == "job_offer":
			msg["resolved"] = true


static func _money(v: int) -> String:
	if absi(v) >= 1000000:
		return "$%.1fM" % (v / 1000000.0)
	return "$%dk" % int(v / 1000)
