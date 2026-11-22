## 選手之間的對話事件：雙人組想加練、隊長提議團隊聚餐、老將與新人的對話。
## 只對玩家俱樂部產生（AI 俱樂部由關係系統在背景自行運作）。
class_name TeammateTalks
extends RefCounted

const DUOS := [["ADC", "SUPPORT", "下路雙人組"], ["MID", "JUNGLE", "中野"], ["TOP", "JUNGLE", "上野"]]


static func _roll(key: String, chance: float) -> bool:
	return float(absi(hash(key)) % 10000) / 10000.0 < chance


static func _open(w: WorldState, kind: String) -> bool:
	return w.inbox.any(func(m): return m.get("kind") == kind and not m.get("resolved", false))


static func weekly(w: WorldState, club: Club) -> void:
	if not club.is_human or w.phase == WorldState.PHASE_OFFSEASON:
		return
	var seed_key = "%s:%d" % [club.id, w.day]
	# 1) 雙人組加練：關係普通、還有進步空間的組合
	if not _open(w, "duo_practice") and _roll(seed_key + ":duo", 0.12):
		var d: Array = DUOS[absi(hash(seed_key)) % DUOS.size()]
		var a: Player = w.players.get(club.lineup.get(d[0], ""))
		var b: Player = w.players.get(club.lineup.get(d[1], ""))
		if a and b:
			var rel = Relationships.get_rel(w, a.id, b.id)
			if rel < 45:
				w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "duo_practice", "player_id": a.id, "other_id": b.id,
					"text": "%s 找上 %s：「我們%s的配合還不夠，要不要每天多排一小時雙排？」兩人來問你能不能調整訓練。" % [a.handle, b.handle, d[2]],
					"resolved": false, "options": ["duo:approve", "duo:decline"], "option_labels": {"duo:approve": "同意加練", "duo:decline": "維持原本訓練"}})
	# 2) 連敗時的團隊聚餐提議（由最會溝通的選手提出）
	if club.streak <= -2 and not _open(w, "team_bonding") and _roll(seed_key + ":bond", 0.35):
		var leader: Player = null
		for pid in club.lineup.values():
			var p: Player = w.players[pid]
			if leader == null or p.trait_value("communication") > leader.trait_value("communication"):
				leader = p
		if leader:
			w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "team_bonding", "player_id": leader.id,
				"text": "%s 在練習後說：「大家最近都繃太緊了，週末一起吃頓飯、把話說開吧。」需要俱樂部出錢安排（約 $20,000）。" % leader.handle,
				"resolved": false, "options": ["bond:fund", "bond:decline"], "option_labels": {"bond:fund": "出錢安排聚餐", "bond:decline": "婉拒"}})
	# 3) 老將與新人：年輕選手請教老將
	if not _open(w, "mentor_talk") and _roll(seed_key + ":mentor", 0.08):
		var young: Player = null
		var vet: Player = null
		for pid in club.roster:
			var p: Player = w.players[pid]
			if p.age(w.year) <= 19 and (young == null or p.potential > young.potential):
				young = p
			if p.age(w.year) >= 24 and (vet == null or p.current_ability() > vet.current_ability()):
				vet = p
		if young and vet and young != vet:
			w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "mentor_talk", "player_id": young.id, "other_id": vet.id,
				"text": "新人 %s 私下問 %s：「你剛出道的時候，怎麼面對大賽壓力？」%s 想知道能不能固定帶他看 VOD。" % [young.handle, vet.handle, vet.handle],
				"resolved": false, "options": ["mentor:approve", "mentor:decline"], "option_labels": {"mentor:approve": "同意固定帶看 VOD", "mentor:decline": "專心自己的訓練"}})


static func resolve(w: WorldState, msg: Dictionary, option: String) -> Dictionary:
	msg["resolved"] = true
	var club = w.human_club()
	var a: Player = w.players.get(msg.get("player_id", ""))
	var b: Player = w.players.get(msg.get("other_id", ""))
	match option:
		"duo:approve":
			if a and b:
				Relationships.change(w, a.id, b.id, 10.0)
				a.fatigue = clampf(a.fatigue + 4.0, 0.0, 100.0)
				b.fatigue = clampf(b.fatigue + 4.0, 0.0, 100.0)
				club.chemistry = clampf(club.chemistry + 2.0, 0.0, 100.0)
				return {"note": "%s 和 %s 的默契明顯提升，只是有點累。" % [a.handle, b.handle]}
		"duo:decline":
			if a:
				a.happiness = clampf(a.happiness - 0.05, -1.0, 1.0)
			return {"note": "兩人有點失望，但尊重訓練安排。"}
		"bond:fund":
			Finance.spend(club, "operations", 20000)
			var ids: Array = club.lineup.values()
			for i in ids.size():
				var p: Player = w.players[ids[i]]
				p.morale = clampf(p.morale + 5.0, 0.0, 100.0)
				p.stress = clampf(p.stress - 6.0, 0.0, 100.0)
				for j in range(i + 1, ids.size()):
					Relationships.change(w, ids[i], ids[j], 4.0)
			return {"note": "聚餐氣氛很好，隊伍重新找回笑容。"}
		"bond:decline":
			if a:
				a.trust_in_management = clampf(a.trust_in_management - 4.0, 0.0, 100.0)
			return {"note": "%s 覺得管理層不在乎選手感受。" % (a.handle if a else "選手")}
		"mentor:approve":
			if a and b:
				Relationships.change(w, a.id, b.id, 8.0)
				a.confidence = clampf(a.confidence + 4.0, 0.0, 100.0)
				a.stress = clampf(a.stress - 5.0, 0.0, 100.0)
				a.career["mentored"] = int(a.career.get("mentored", 0)) + 1
				return {"note": "%s 很珍惜這個機會，看比賽的角度更成熟了。" % a.handle}
		"mentor:decline":
			return {"note": "新人只好自己摸索。"}
	return {"note": "已處理"}
