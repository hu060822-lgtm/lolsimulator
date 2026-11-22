## 關係網絡（Relationship Engine）：選手之間、選手與主教練之間的關係。
##
## 關係值 -100..100，存在 w.relations["a|b"]（id 排序後串接）。第一次查詢時依個性相容度建立。
## 關係會影響：團隊執行力（比賽）、默契的長期走向、選手滿意度（可能因此要求離隊）、
## 年輕選手的成長（老將指導）。
class_name Relationships
extends RefCounted

const FRIEND := 40.0
const RIVAL := -40.0


static func key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


## 兩名選手的天生相容度：國籍、年齡、性格。
static func compatibility(pa: Player, pb: Player, year: int) -> float:
	var v := 0.0
	if pa.nationality == pb.nationality:
		v += 12.0
	v -= absf(pa.age(year) - pb.age(year)) * 1.2
	v += (pa.trait_value("teamwork") + pb.trait_value("teamwork") - 100.0) * 0.25
	v += (pa.trait_value("temperament") + pb.trait_value("temperament") - 100.0) * 0.2
	# 兩個野心都很大的人容易互相較勁
	if pa.trait_value("ambition") > 75 and pb.trait_value("ambition") > 75:
		v -= 10.0
	# 同位置競爭先發
	if pa.primary_role == pb.primary_role:
		v -= 8.0
	return clampf(v, -60.0, 60.0)


static func get_rel(w: WorldState, a: String, b: String) -> float:
	var k = key(a, b)
	if not w.relations.has(k):
		var pa: Player = w.players.get(a)
		var pb: Player = w.players.get(b)
		if pa == null or pb == null:
			return 0.0
		w.relations[k] = compatibility(pa, pb, w.year) * 0.6
	return float(w.relations[k])


static func change(w: WorldState, a: String, b: String, delta: float) -> float:
	var v = clampf(get_rel(w, a, b) + delta, -100.0, 100.0)
	w.relations[key(a, b)] = v
	return v


## 選手與主教練的關係（以 staff id 為另一端）。
static func coach_rel(w: WorldState, p: Player) -> float:
	var club: Club = w.clubs.get(p.club_id)
	if club == null or club.coach_id == "":
		return 0.0
	var k = key(p.id, club.coach_id)
	if not w.relations.has(k):
		var coach: Staff = w.staff.get(club.coach_id)
		w.relations[k] = ((coach.man_management if coach else 40.0) - 50.0) * 0.4
	return float(w.relations[k])


static func change_coach(w: WorldState, p: Player, delta: float) -> void:
	var club: Club = w.clubs.get(p.club_id)
	if club == null or club.coach_id == "":
		return
	w.relations[key(p.id, club.coach_id)] = clampf(coach_rel(w, p) + delta, -100.0, 100.0)


## 隊友平均關係（-100..100）
static func team_average(w: WorldState, club: Club, ids: Array = []) -> float:
	var list: Array = ids if not ids.is_empty() else club.roster
	var total := 0.0
	var n := 0
	for i in list.size():
		for j in range(i + 1, list.size()):
			total += get_rel(w, list[i], list[j])
			n += 1
	return total / n if n > 0 else 0.0


## 某選手與隊友的關係摘要：平均、最好與最差的隊友。
static func summary(w: WorldState, p: Player) -> Dictionary:
	var club: Club = w.clubs.get(p.club_id)
	if club == null:
		return {"avg": 0.0, "best": "", "best_v": 0.0, "worst": "", "worst_v": 0.0, "coach": 0.0}
	var total := 0.0
	var n := 0
	var best := ""
	var best_v := -INF
	var worst := ""
	var worst_v := INF
	for pid in club.roster:
		if pid == p.id:
			continue
		var v = get_rel(w, p.id, pid)
		total += v
		n += 1
		if v > best_v:
			best_v = v
			best = pid
		if v < worst_v:
			worst_v = v
			worst = pid
	return {"avg": total / maxf(n, 1), "best": best, "best_v": best_v if best != "" else 0.0,
		"worst": worst, "worst_v": worst_v if worst != "" else 0.0, "coach": coach_rel(w, p)}


static func label(v: float) -> String:
	if v >= 60:
		return "摯友"
	if v >= FRIEND:
		return "好友"
	if v >= 10:
		return "融洽"
	if v > -10:
		return "普通"
	if v > RIVAL:
		return "不合"
	return "交惡"


## 每週：關係朝相容度慢慢靠攏；團隊活動、成績、衝突與老將指導。
static func weekly(w: WorldState, club: Club) -> void:
	var ids: Array = club.roster.duplicate()
	var plan: Dictionary = club.training_plan
	var bonding = int(plan.get("team_building", 0)) * 0.6 + int(plan.get("scrims", 0)) * 0.1
	var streak = club.streak
	var coach: Staff = w.staff.get(club.coach_id)
	var mm = StaffSystem.rating(w, club, "man_management")
	for i in ids.size():
		var pa: Player = w.players[ids[i]]
		for j in range(i + 1, ids.size()):
			var pb: Player = w.players[ids[j]]
			var cur = get_rel(w, pa.id, pb.id)
			var base = compatibility(pa, pb, w.year)
			var d = (base - cur) * 0.03 + bonding
			# 連敗時，脾氣差的人容易起衝突；連勝時大家都好相處
			if streak <= -3:
				d -= (200.0 - pa.trait_value("temperament") - pb.trait_value("temperament")) / 100.0 * 0.8
			elif streak >= 3:
				d += 0.5
			change(w, pa.id, pb.id, d)
		# 主教練關係：管理能力、上場時間
		if coach:
			var benched = pa.squad_status != "starter" and CareerAgent.expected_status(w, pa) == "starter"
			change_coach(w, pa, (mm - 50.0) / 50.0 * 0.6 - (1.2 if benched else 0.0))
	_conflicts(w, club, ids, mm)
	_mentoring(w, club, ids)
	# 默契的長期走向：隊內關係好，默契自然累積
	club.chemistry = clampf(club.chemistry + team_average(w, club, club.lineup.values()) / 100.0 * 0.5, 0.0, 100.0)


## 衝突事件：關係差、脾氣差、輸球時發生；玩家俱樂部會收到需要處理的訊息。
static func _conflicts(w: WorldState, club: Club, ids: Array, mm: float) -> void:
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var pa: Player = w.players[ids[i]]
			var pb: Player = w.players[ids[j]]
			var rel = get_rel(w, pa.id, pb.id)
			if rel > -20.0:
				continue
			var hot = (200.0 - pa.trait_value("temperament") - pb.trait_value("temperament")) / 200.0
			var p = 0.015 + hot * 0.04 + (0.03 if club.streak <= -2 else 0.0) - (mm - 50.0) / 2000.0
			if not w.rng.chance(clampf(p, 0.0, 0.2)):
				continue
			change(w, pa.id, pb.id, -8.0)
			pa.morale = clampf(pa.morale - 4.0, 0.0, 100.0)
			pb.morale = clampf(pb.morale - 4.0, 0.0, 100.0)
			club.chemistry = clampf(club.chemistry - 2.0, 0.0, 100.0)
			var causes = ["關係 %d（%s）" % [int(rel), label(rel)], "脾氣：%d / %d" % [int(pa.trait_value("temperament")), int(pb.trait_value("temperament"))]]
			if club.streak <= -2:
				causes.append("%d 連敗" % -club.streak)
			w.log.add("conflict", w.day, [pa.id, pb.id, club.id], {}, causes)
			if club.is_human:
				w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "conflict", "player_id": pa.id, "other_id": pb.id,
					"text": "%s 與 %s 在訓練中爆發爭執" % [pa.handle, pb.handle], "causes": causes,
					"resolved": false, "options": ["mediate", "back_first", "ignore"]})
			return  # 每週每隊最多一次


## 老將指導：職業態度好的老將提升同隊年輕選手的成長與關係。
static func _mentoring(w: WorldState, club: Club, ids: Array) -> void:
	for mid in ids:
		var m: Player = w.players[mid]
		if m.age(w.year) < 25 or m.trait_value("professionalism") < 65:
			continue
		for yid in ids:
			var y: Player = w.players[yid]
			if y.age(w.year) > 20 or get_rel(w, mid, yid) < 10.0:
				continue
			change(w, mid, yid, 0.4)
			var focus = Attr.COGNITIVE
			var sk: String = focus[w.rng.range_i(0, focus.size() - 1)]
			y.skills[sk] = minf(y.skill(sk) + 0.05 * (1.0 if y.primary_role == m.primary_role else 0.5), float(y.ceilings.get(sk, 99.0)))


## 玩家處理衝突。
static func resolve_conflict(w: WorldState, msg: Dictionary, option: String) -> Dictionary:
	var pa: Player = w.players.get(msg.get("player_id", ""))
	var pb: Player = w.players.get(msg.get("other_id", ""))
	msg["resolved"] = true
	if pa == null or pb == null:
		return {"note": "選手已不在隊上"}
	var club: Club = w.human_club()
	var mm = StaffSystem.rating(w, club, "man_management")
	match option:
		"mediate":
			var ok = w.rng.chance(clampf(0.35 + (mm - 40.0) / 100.0 + (pa.trait_value("temperament") + pb.trait_value("temperament")) / 400.0, 0.1, 0.9))
			if ok:
				change(w, pa.id, pb.id, 15.0)
				club.chemistry = clampf(club.chemistry + 2.0, 0.0, 100.0)
				return {"note": "調解成功，兩人握手言和"}
			change(w, pa.id, pb.id, -3.0)
			return {"note": "調解沒有效果，兩人仍有心結"}
		"back_first":
			pa.trust_in_management = clampf(pa.trust_in_management + 8.0, 0.0, 100.0)
			pb.trust_in_management = clampf(pb.trust_in_management - 12.0, 0.0, 100.0)
			change_coach(w, pb, -10.0)
			change(w, pa.id, pb.id, -6.0)
			return {"note": "你站在 %s 這邊；%s 對管理層失去信任" % [pa.handle, pb.handle]}
	club.chemistry = clampf(club.chemistry - 1.0, 0.0, 100.0)
	return {"note": "你決定不介入"}


## 轉會或退役：清除與該選手的關係（只保留現隊友）。
static func on_leave(w: WorldState, pid: String) -> void:
	for k in w.relations.keys():
		if k.begins_with(pid + "|") or k.ends_with("|" + pid):
			w.relations.erase(k)
