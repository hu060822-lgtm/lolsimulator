## 年度宿敵：每季開始時，從同聯賽挑出一支最像對手的俱樂部當你的宿敵。
##
## - 挑選：去年積分榜跟你相鄰、或聲望最接近的同聯賽隊伍。
## - 宿敵戰的勝負影響更大：全隊士氣 ±6、粉絲 ±1.5%、品牌 ±1.5、董事會信心 ±3，媒體會大篇幅報導。
## - 賽季目標可能包含「宿敵戰至少贏一次」。
## 資料存在 w.manager["rival"]：{club_id, year, w, l, reason}。
class_name Rivalry
extends RefCounted

const MORALE := 6.0
const FANS_PCT := 1.5
const BRAND := 1.5
const BOARD := 3.0


static func current(w: WorldState) -> Dictionary:
	var me: Club = w.human_club()
	if me == null:
		return {}
	var m := ManagerCareer.data(w)
	var r: Dictionary = m.get("rival", {})
	if r.is_empty() or int(r.get("year", 0)) != w.year or not w.clubs.has(r.get("club_id", "")) or w.clubs[r["club_id"]].league_id != me.league_id or r["club_id"] == me.id:
		r = pick(w)
	return r


static func is_rival(w: WorldState, club_id: String) -> bool:
	var r := current(w)
	return not r.is_empty() and r["club_id"] == club_id


## 選出本季宿敵並寫入經理資料。
static func pick(w: WorldState) -> Dictionary:
	var me: Club = w.human_club()
	var lg: League = w.leagues.get(me.league_id) if me else null
	if lg == null:
		return {}
	var last_pos := {}
	if not me.history.is_empty():
		var my_last: Dictionary = me.history[-1]
		for cid in lg.club_ids:
			var c: Club = w.clubs[cid]
			if not c.history.is_empty() and c.history[-1].get("year", 0) == my_last.get("year", -1) and c.history[-1].get("league_id", "") == my_last.get("league_id", ""):
				last_pos[cid] = int(c.history[-1]["position"])
	var best := ""
	var best_s := -1e9
	var reason := ""
	for cid in lg.club_ids:
		if cid == me.id:
			continue
		var c: Club = w.clubs[cid]
		var s := -absf(c.reputation - me.reputation) * 0.5 + w.rng.range_f(0.0, 3.0)
		var why := "同賽區聲望最接近的對手"
		if last_pos.has(cid) and last_pos.has(me.id) and absi(int(last_pos[cid]) - int(last_pos[me.id])) == 1:
			s += 8.0
			why = "去年積分榜上和你只差一名"
		if s > best_s:
			best_s = s
			best = cid
			reason = why
	var r := {"club_id": best, "year": w.year, "w": 0, "l": 0, "reason": reason}
	ManagerCareer.data(w)["rival"] = r
	if best != "":
		Media.post(w, "feature", "新賽季看點：%s 與 %s 的宿敵之爭" % [me.short_name, w.clubs[best].short_name], [me.id, best], 0.1)
	return r


## 系列賽結束：若是宿敵戰，套用加倍的士氣、粉絲、品牌與董事會效果。
static func on_series(w: WorldState, home: Club, away: Club, series: Dictionary) -> void:
	var me: Club = w.human_club()
	if me == null or not (home.id == me.id or away.id == me.id):
		return
	var opp: Club = away if home.id == me.id else home
	var r := current(w)
	if r.is_empty() or r["club_id"] != opp.id:
		return
	var won: bool = series["winner"] == me.id
	var sgn := 1.0 if won else -1.0
	r["w" if won else "l"] = int(r["w" if won else "l"]) + 1
	for pid in me.roster:
		var p: Player = w.players[pid]
		p.morale = clampf(p.morale + MORALE * sgn, 0.0, 100.0)
	me.fanbase = maxi(0, int(me.fanbase * (1.0 + FANS_PCT / 100.0 * sgn)))
	me.brand = clampf(me.brand + BRAND * sgn, 0.0, 100.0)
	me.board_confidence = clampf(me.board_confidence + BOARD * sgn, 0.0, 100.0)
	var score := "%d-%d" % [int(series["score"][me.id]), int(series["score"][opp.id])]
	if won:
		Media.post(w, "feature", "宿敵戰 %s 以 %s 擊敗 %s，粉絲沸騰" % [me.short_name, score, opp.short_name], [me.id, opp.id], 0.6)
	else:
		Media.post(w, "crisis", "宿敵戰 %s 以 %s 不敵 %s，球迷不滿" % [me.short_name, score, opp.short_name], [me.id, opp.id], -0.5)
	w.log.add("rivalry", w.day, [me.id, opp.id], {"won": won, "score": score}, [])
