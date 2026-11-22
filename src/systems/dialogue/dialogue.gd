## 對話系統：經理主動找選手談話、賽前／局間的團隊談話。
##
## 每個選項的效果取決於選手的個性（情緒穩定、職業態度、野心、抗壓性）、對管理層的信任與近期表現。
## 同一名選手每 7 天只能單獨談一次；團隊談話每局一次。
## 回傳 {"ok", "reply"（選手的回應）, "tone"（-1..1）, "effects"}，所有談話都記錄在 SimLog 供追溯。
class_name Dialogue
extends RefCounted

const TALK_COOLDOWN := 7

const TOPICS := {
	"praise": "稱讚近期表現",
	"criticize": "批評近期表現",
	"motivate": "設定目標、激勵鬥志",
	"discuss_role": "討論在隊上的定位",
	"future": "聊聊未來與合約",
}

const TEAM_TALKS := {
	"calm": "放輕鬆，照平常打",
	"focus": "要求專注，嚴守紀律",
	"fire_up": "激勵士氣，這場一定要拿下",
	"no_pressure": "沒人看好我們，放手去打",
}


static func can_talk(w: WorldState, p: Player) -> bool:
	return w.day - int(p.career.get("last_talk_day", -999)) >= TALK_COOLDOWN


static func _form(p: Player) -> float:
	var g: int = p.season_stats.get("games", 0)
	return p.avg_season_rating() if g >= 2 else 6.3


static func talk(w: WorldState, p: Player, topic: String) -> Dictionary:
	if not can_talk(w, p):
		return {"ok": false, "reply": "%s：「我們前幾天才談過。」" % p.handle, "tone": 0.0, "effects": {}}
	p.career["last_talk_day"] = w.day
	var trust = p.trust_in_management / 100.0
	var temper = p.trait_value("temperament") / 100.0
	var pro = p.trait_value("professionalism") / 100.0
	var ambition = p.trait_value("ambition") / 100.0
	var form = _form(p)
	var fx := {}
	var reply := ""
	var tone := 0.0
	match topic:
		"praise":
			if form >= 6.5:
				fx = {"morale": 6.0, "confidence": 5.0, "trust": 3.0}
				reply = "謝謝！我會繼續保持。"
				tone = 0.8
			elif form >= 5.8:
				fx = {"morale": 3.0, "confidence": 2.0}
				reply = "嗯……我覺得自己還可以更好。"
				tone = 0.3
			else:
				fx = {"trust": -4.0}
				reply = "最近打得怎樣我自己清楚，不用安慰我。"
				tone = -0.4
		"criticize":
			if form < 6.0:
				if pro >= 0.6 or temper >= 0.6:
					fx = {"motivation": 6.0 * (0.5 + pro), "morale": -2.0, "trust": 2.0}
					reply = "你說得對，我會調整。"
					tone = 0.4
				else:
					fx = {"morale": -8.0, "trust": -6.0, "stress": 5.0}
					reply = "大家都打不好，為什麼只找我？"
					tone = -0.7
			else:
				fx = {"morale": -6.0, "trust": -10.0}
				reply = "我這季是隊上表現最好的之一，你在開玩笑嗎？"
				tone = -0.9
		"motivate":
			var room = maxf(85.0 - p.motivation, 0.0) / 85.0
			var gain = (4.0 + 10.0 * ambition) * room * (0.6 + trust * 0.6)
			fx = {"motivation": gain, "morale": 2.0}
			if gain >= 5.0:
				reply = "好，這季我要拿冠軍。"
				tone = 0.7
			elif gain >= 2.0:
				reply = "我會盡力。"
				tone = 0.3
			else:
				reply = "我一直都很拼，你不用特別提醒。"
				tone = 0.0
		"discuss_role":
			var expected = CareerAgent.expected_status(w, p)
			if p.squad_status == "starter":
				fx = {"morale": 3.0, "trust": 3.0}
				reply = "我知道自己是先發，會扛起責任。"
				tone = 0.5
			elif expected == "starter":
				fx = {"trust": 4.0 * (trust * 2.0 - 0.6), "morale": -2.0}
				reply = "我覺得我應該先發。希望你說到做到，給我機會。" if trust >= 0.45 else "又是這套說法。我想先發。"
				tone = 0.1 if trust >= 0.45 else -0.5
			else:
				fx = {"morale": 2.0, "trust": 2.0}
				reply = "我明白，我會在訓練裡證明自己。"
				tone = 0.4
		"future":
			var club: Club = w.clubs.get(p.club_id)
			var demand = TransferMarket.wage_demand(w, p)
			var u = TransferMarket.contract_utility(w, p, club, demand, p.squad_status)["utility"] if club else 0.0
			if p.refuses_renewal or u < -0.1:
				reply = "老實說，我想看看其他機會。"
				tone = -0.4
			elif u < 0.4:
				reply = "如果條件合適，我願意留下。我期待年薪大約 %s。" % _money(demand)
				tone = 0.2
			else:
				reply = "我很喜歡這裡，希望能長期留下來（期待年薪約 %s）。" % _money(demand)
				tone = 0.6
			fx = {"trust": 2.0}
		_:
			return {"ok": false, "reply": "", "tone": 0.0, "effects": {}}
	_apply(p, fx)
	var club2: Club = w.clubs.get(p.club_id)
	if club2 and tone < -0.5:
		Relationships.change_coach(w, p, -3.0)
	w.log.add("talk", w.day, [p.id], {"topic": topic, "tone": tone}, [reply])
	return {"ok": true, "reply": "%s：「%s」" % [p.handle, reply], "tone": tone, "effects": fx}


## 團隊談話：對先發陣容每個人分別產生效果。回傳每名選手的反應。
static func team_talk(w: WorldState, club: Club, kind: String, stakes: float = 1.0, underdog: bool = false) -> Dictionary:
	var reactions: Array = []
	var total := 0.0
	for role in Attr.ROLES:
		var p: Player = w.players.get(club.lineup.get(role, ""))
		if p == null:
			continue
		var composure = p.trait_value("composure") / 100.0
		var pro = p.trait_value("professionalism") / 100.0
		var fx := {}
		var r := 0.0
		match kind:
			"calm":
				fx = {"stress": -6.0 * (1.2 - composure), "motivation": -1.5}
				r = 0.4 if p.stress > 45.0 else 0.0
			"focus":
				fx = {"confidence": 3.0 * pro, "stress": 2.0 * (1.0 - pro)}
				r = pro - 0.45
			"fire_up":
				fx = {"morale": 4.0 * stakes, "motivation": 3.0, "stress": 5.0 * stakes * (1.0 - composure)}
				r = 0.5 if composure >= 0.55 else -0.2
			"no_pressure":
				if underdog:
					fx = {"stress": -8.0, "confidence": 3.0}
					r = 0.6
				else:
					fx = {"motivation": -3.0}
					r = -0.4
		_apply(p, fx)
		total += r
		reactions.append({"player": p.handle, "tone": r, "text": _reaction_text(r)})
	w.log.add("team_talk", w.day, [club.id], {"kind": kind, "avg": total / maxf(reactions.size(), 1)}, [])
	return {"ok": true, "reactions": reactions, "avg": total / maxf(reactions.size(), 1)}


static func _reaction_text(r: float) -> String:
	if r >= 0.4:
		return "聽進去了，看起來很有精神"
	if r >= 0.1:
		return "點頭表示同意"
	if r > -0.2:
		return "沒什麼反應"
	return "看起來不太認同"


static func _apply(p: Player, fx: Dictionary) -> void:
	for k in fx:
		var v = float(fx[k])
		match k:
			"morale": p.morale = clampf(p.morale + v, 0.0, 100.0)
			"confidence": p.confidence = clampf(p.confidence + v, 0.0, 100.0)
			"stress": p.stress = clampf(p.stress + v, 0.0, 100.0)
			"trust": p.trust_in_management = clampf(p.trust_in_management + v, 0.0, 100.0)
			"motivation": p.motivation = clampf(p.motivation + v, 0.0, 100.0)


static func _money(v: int) -> String:
	return "$%dk" % int(v / 1000)
