## 記者會：玩家俱樂部打完系列賽後（季後賽、國際賽、爆冷或連敗時一定會有），
## 記者提問、玩家選擇回答方式。回答會影響選手士氣／自信、外界評價、董事會與對手。
class_name PressConference
extends RefCounted

## 回答方式 -> [名稱, 說明]
const ANSWERS := {
	"praise": ["稱讚選手", "士氣上升，外界評價略升"],
	"responsibility": ["教練扛下責任", "選手信任上升，董事會略降"],
	"demand": ["公開要求更好表現", "求勝慾上升但士氣下降，壓力增加"],
	"provoke": ["挑釁下一個對手", "自信大增但壓力上升，外界評價兩極"],
	"calm": ["低調回應", "沒有特別影響"],
}


static func labels() -> Dictionary:
	var out := {}
	for k in ANSWERS:
		out["press:" + k] = ANSWERS[k][0]
	return out


static func _roll(key: String, chance: float) -> bool:
	return float(absi(hash(key)) % 10000) / 10000.0 < chance


static func after_series(w: WorldState, lg: League, fx: Dictionary, series: Dictionary) -> void:
	var human = w.human_club()
	if human == null or not (fx["home"] == human.id or fx["away"] == human.id):
		return
	var won: bool = series["winner"] == human.id
	var opp: Club = w.clubs[fx["away"] if fx["home"] == human.id else fx["home"]]
	var big = fx["stage"] != "regular" or lg.tier == 0
	var upset = won and opp.reputation > human.reputation + 12
	var upset_loss = not won and human.reputation > opp.reputation + 12
	var slump = human.streak <= -3
	if not (big or upset or upset_loss or slump or _roll("%s:%d:press" % [human.id, w.day], 0.35)):
		return
	var q := ""
	if upset:
		q = "今天擊敗了被看好的 %s，這是球隊的轉捩點嗎？" % opp.short_name
	elif upset_loss:
		q = "輸給外界不看好的 %s，選手是不是太輕敵了？" % opp.short_name
	elif slump:
		q = "球隊已經 %d 連敗，你還相信現在這套陣容嗎？" % -human.streak
	elif won and big:
		q = "在%s拿下關鍵勝利，接下來的目標是什麼？" % (lg.short_name if lg.short_name != "" else lg.name)
	elif won:
		q = "今天贏得乾淨俐落，對選手的表現滿意嗎？"
	elif big:
		q = "在大舞台上落敗，你想對粉絲說什麼？"
	else:
		q = "今天的失利問題出在哪裡？"
	# 只保留一則未回覆的記者會，舊的視為低調回應
	for m in w.inbox:
		if m.get("kind") == "press" and not m.get("resolved", false):
			m["resolved"] = true
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "press", "player_id": "", "won": won, "opponent": opp.id,
		"text": "賽後記者會：「%s」" % q, "resolved": false,
		"options": ANSWERS.keys().map(func(k): return "press:" + k), "option_labels": labels()})


static func answer(w: WorldState, msg: Dictionary, key: String) -> Dictionary:
	msg["resolved"] = true
	var club = w.human_club()
	if club == null or not ANSWERS.has(key):
		return {"note": "記者會已結束"}
	var won: bool = msg.get("won", false)
	var players: Array = club.lineup.values().map(func(pid): return w.players[pid])
	var opp: Club = w.clubs.get(msg.get("opponent", ""))
	var note := ""
	match key:
		"praise":
			for p in players:
				p.morale = clampf(p.morale + 5.0, 0.0, 100.0)
				p.confidence = clampf(p.confidence + (3.0 if won else 1.0), 0.0, 100.0)
			club.opinion = clampf(club.opinion + 2.0, -100.0, 100.0)
			note = "選手看到報導後很受鼓舞。"
		"responsibility":
			for p in players:
				p.trust_in_management = clampf(p.trust_in_management + 5.0, 0.0, 100.0)
				p.stress = clampf(p.stress - 4.0, 0.0, 100.0)
			club.board_confidence = clampf(club.board_confidence - (2.0 if not won else 0.0), 0.0, 100.0)
			note = "選手感受到教練的保護，壓力減輕。"
		"demand":
			for p in players:
				p.motivation = clampf(p.motivation + 6.0, 0.0, 100.0)
				p.morale = clampf(p.morale - 4.0, 0.0, 100.0)
				p.stress = clampf(p.stress + 5.0, 0.0, 100.0)
				if p.trait_value("professionalism") < 40:
					p.trust_in_management = clampf(p.trust_in_management - 4.0, 0.0, 100.0)
			club.board_confidence = clampf(club.board_confidence + 1.5, 0.0, 100.0)
			note = "更衣室氣氛緊繃，但選手憋著一口氣。"
		"provoke":
			for p in players:
				p.confidence = clampf(p.confidence + 7.0, 0.0, 100.0)
				p.stress = clampf(p.stress + 4.0, 0.0, 100.0)
			club.opinion = clampf(club.opinion + (4.0 if won else -5.0), -100.0, 100.0)
			club.brand = clampf(club.brand + 1.0, 0.0, 100.0)
			if opp:
				Media.post(w, "press", "%s 在記者會上挑釁 %s，引發粉絲熱議" % [club.short_name, opp.short_name], [club.id, opp.id], 0.0)
			note = "話題性十足，選手信心大增，但輸了會被放大檢視。"
		"calm":
			note = "記者沒有拿到新聞點。"
	w.log.add("press", w.day, [club.id], {"answer": key}, [ANSWERS[key][0]])
	return {"note": note}
