## 聯賽與賽事：賽程生成、比賽日執行、排名（含同分判定）、季後賽。
## 賽制由 League.format（資料）決定。
class_name LeagueEngine
extends RefCounted

const PRESEASON_DAYS := 14


static func start_season(w: WorldState) -> void:
	w.phase = WorldState.PHASE_PRESEASON
	w.phase_day = w.day
	var start = w.day + PRESEASON_DAYS
	# 季中國際賽（First Stand、MSI…）：所有國內聯賽在同一時間點一起休兵
	var breaks := midseason_breaks(w, start)
	for lg in w.leagues.values():
		_reset(lg)
		_generate_regular(w, lg, start, breaks)
	for it in w.internationals.values():
		it.club_ids = []
		_reset(it)


## 季中賽事依 format.after_frac（例行賽進度，預設 0.5）排序。
static func midseason_events(w: WorldState) -> Array:
	var out: Array = w.internationals.values().filter(func(it): return str(it.format.get("timing", "end")) == "midseason")
	out.sort_custom(func(a, b): return float(a.format.get("after_frac", 0.5)) < float(b.format.get("after_frac", 0.5)))
	return out


static func total_rounds(lg: League) -> int:
	var legs = 2 if lg.format.get("regular", {}).get("type", "double_round_robin") == "double_round_robin" else 1
	return rounds_per_leg(lg) * legs


## 每個季中賽事在第幾輪後休兵（依該聯賽的輪數換算）。
static func break_round(lg: League, it: League) -> int:
	return int(ceil(float(it.format.get("after_frac", 0.5)) * total_rounds(lg)))


## 回傳 [[賽事, 復賽日], …]：休兵點取所有聯賽中最晚打到該進度的日期，再加上 break_days。
static func midseason_breaks(w: WorldState, start: int) -> Array:
	var out: Array = []
	var resume := {}   # league id -> 目前段落的開始日
	var prev_round := {}
	for lg in w.leagues.values():
		resume[lg.id] = start
		prev_round[lg.id] = 0
	for it in midseason_events(w):
		var latest := start
		for lg in w.leagues.values():
			var gap = int(lg.format.get("regular", {}).get("days_between_rounds", 3))
			var k = break_round(lg, it)
			latest = maxi(latest, int(resume[lg.id]) + (k - int(prev_round[lg.id])) * gap)
			prev_round[lg.id] = k
		var day = latest + int(it.format.get("break_days", 16))
		for lg in w.leagues.values():
			resume[lg.id] = day
		out.append([it, day])
	return out


static func rounds_per_leg(lg: League) -> int:
	var n = lg.club_ids.size()
	return n if n % 2 == 1 else n - 1


## 第一循環是否打完（季中國際賽的開打條件）。
static func first_leg_done(lg: League) -> bool:
	var per = rounds_per_leg(lg)
	return not lg.fixtures.any(func(f): return f["stage"] == "regular" and int(f["round"]) <= per and not f["played"])


static func _reset(lg: League) -> void:
	lg.fixtures = []
	lg.standings = {}
	lg.playoff_bracket = []
	lg.champion_id = ""
	lg.season_complete = false
	for cid in lg.club_ids:
		lg.standings[cid] = {"w": 0, "l": 0, "gw": 0, "gl": 0, "h2h": {}}


## 所有進行中的賽事：國內聯賽 + 本季已開打的國際賽事。
static func all_competitions(w: WorldState) -> Array:
	var out: Array = w.leagues.values()
	for it in w.internationals.values():
		if not it.club_ids.is_empty():
			out.append(it)
	return out


## 國際賽事資格：每個一級聯賽依名額（format.slots[賽事 id]）派隊。
## 季後賽冠軍優先，其餘依例行賽排名（季中賽事時聯賽冠軍尚未產生，純看排名）。
static func qualifiers(w: WorldState, it: League = null) -> Array:
	if it == null:
		it = w.international
	if it == null:
		return []
	var out: Array = []
	for lg in w.leagues.values():
		if lg.tier != 1:
			continue
		var per := int(lg.format.get("slots", {}).get(it.id, it.format.get("qualify_per_league", 4)))
		var seeds: Array = []
		if lg.champion_id != "":
			seeds.append(lg.champion_id)
		for cid in sorted_standings(lg):
			if not seeds.has(cid):
				seeds.append(cid)
		out.append_array(seeds.slice(0, per))
	return out


## 開打國際賽事：小組單循環 Bo1 → 前 4 名淘汰賽。回傳是否開打。
## 世界賽在國內賽季全部結束後；季中邀請賽在一級聯賽第一循環結束後。
static func start_international(w: WorldState, it: League = null) -> bool:
	if it == null:
		it = w.international
	if it == null:
		return false
	var q = qualifiers(w, it)
	if q.size() < 4:
		return false
	it.club_ids = q
	_reset(it)
	_generate_regular(w, it, w.day + (5 if str(it.format.get("timing", "end")) == "end" else 2))
	for cid in q:
		w.log.add("intl_qualified", w.day, [cid], {"year": w.year, "event": it.id}, [])
	Media.on_intl_start(w, it)
	return true


## 國際賽事小組賽結束 → 排淘汰賽。
static func advance_internationals(w: WorldState) -> void:
	for it in w.internationals.values():
		if it.club_ids.is_empty() or it.season_complete or not it.playoff_bracket.is_empty():
			continue
		_advance_swiss(w, it)
		if regular_done(it):
			start_playoffs(w, it)


## 季中賽事：所有一級聯賽都打到休兵點時開打（每季每項一次）。
static func maybe_start_midseason(w: WorldState) -> void:
	for it in midseason_events(w):
		if not it.club_ids.is_empty():
			continue
		for lg in w.leagues.values():
			if lg.tier != 1:
				continue
			var k = break_round(lg, it)
			if lg.fixtures.any(func(f): return f["stage"] == "regular" and int(f["round"]) <= k and not f["played"]):
				return
		start_international(w, it)
		return


## 單／雙循環（circle method）。breaks = midseason_breaks() 的結果：打到休兵點後，下一輪最早從復賽日開始。
## 瑞士輪（type = "swiss"）只排第一輪，之後每輪依戰績配對（見 _advance_swiss）。
static func _generate_regular(w: WorldState, lg: League, start_day: int, breaks: Array = []) -> void:
	var fmt: Dictionary = lg.format.get("regular", {})
	if fmt.get("type", "") == "swiss":
		_swiss_round(w, lg, start_day)
		return
	var bo := int(fmt.get("best_of", 1))
	var gap := int(fmt.get("days_between_rounds", 3))
	var teams: Array = lg.club_ids.duplicate()
	if teams.size() % 2 == 1:
		teams.append("")
	var n = teams.size()
	var rounds: Array = []
	for r in n - 1:
		var pairs: Array = []
		for i in n / 2:
			var a: String = teams[i]
			var b: String = teams[n - 1 - i]
			if a != "" and b != "":
				pairs.append([a, b] if r % 2 == 0 else [b, a])
		rounds.append(pairs)
		var last: String = teams.pop_back()
		teams.insert(1, last)
	var legs = 2 if fmt.get("type", "double_round_robin") == "double_round_robin" else 1
	var day = start_day
	var rn := 0
	for leg in legs:
		for pairs in rounds:
			for b in breaks:
				if rn == break_round(lg, b[0]) and rn > 0:
					day = maxi(day, int(b[1]))
			rn += 1
			for pr in pairs:
				var home: String = pr[0] if leg == 0 else pr[1]
				var away: String = pr[1] if leg == 0 else pr[0]
				lg.fixtures.append(_with_stakes(lg, {"id": "%s_%d_r%d_%s_%s" % [lg.id, w.year, rn, home, away], "day": day, "stage": "regular",
					"round": rn, "home": home, "away": away, "best_of": bo, "played": false, "result": {}}))
			day += gap


## 賽事可在 format.stakes 依階段指定比賽重要性（影響壓力、大賽經驗、成長）。
static func _with_stakes(lg: League, fx: Dictionary) -> Dictionary:
	var st: Dictionary = lg.format.get("stakes", {})
	if st.has(fx["stage"]):
		fx["stakes"] = float(st[fx["stage"]])
	return fx


static func regular_done(lg: League) -> bool:
	if lg.fixtures.any(func(f): return f["stage"] == "regular" and not f["played"]):
		return false
	if lg.format.get("regular", {}).get("type", "") == "swiss":
		return swiss_active(lg).is_empty() and not lg.fixtures.is_empty()
	return true


# ---------------------------------------------------------------- 瑞士輪（世界賽）
## 戰績相同的隊伍互打；3 勝晉級、3 敗淘汰。晉級／淘汰戰為 Bo3，其餘 Bo1。

static func swiss_active(lg: League) -> Array:
	var wins := int(lg.format.get("regular", {}).get("wins", 3))
	return lg.club_ids.filter(func(c): return int(lg.standings[c]["w"]) < wins and int(lg.standings[c]["l"]) < wins)


static func _swiss_round(w: WorldState, lg: League, day: int) -> void:
	var fmt: Dictionary = lg.format.get("regular", {})
	var wins := int(fmt.get("wins", 3))
	var rn = 1 + lg.fixtures.filter(func(f): return f["stage"] == "regular").map(func(f): return int(f["round"])).reduce(func(a, b): return maxi(a, b), 0)
	var active = swiss_active(lg)
	var groups := {}
	for cid in active:
		var key = "%d-%d" % [int(lg.standings[cid]["w"]), int(lg.standings[cid]["l"])]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(cid)
	var leftover: Array = []
	var keys: Array = groups.keys()
	keys.sort()
	keys.reverse()
	for key in keys:
		var g: Array = leftover + groups[key]
		leftover = []
		# 第一輪：同賽區不互打（依資格順序交錯）；之後盡量避免重複對戰
		if rn == 1:
			g = _interleave_regions(w, g)
		else:
			w.rng.shuffle(g)
		while g.size() >= 2:
			var a: String = g.pop_front()
			var bi := 0
			for i in g.size():
				if not lg.standings[a]["h2h"].has(g[i]) and not lg.standings[g[i]]["h2h"].has(a):
					bi = i
					break
			var b: String = g[bi]
			g.remove_at(bi)
			var decisive = int(lg.standings[a]["w"]) == wins - 1 or int(lg.standings[a]["l"]) == wins - 1
			lg.fixtures.append(_with_stakes(lg, {"id": "%s_%d_sw%d_%s_%s" % [lg.id, w.year, rn, a, b], "day": day, "stage": "regular",
				"round": rn, "home": a, "away": b, "best_of": int(fmt.get("decisive_best_of", 3)) if decisive else int(fmt.get("best_of", 1)),
				"played": false, "result": {}}))
		leftover = g
	# 奇數時最後一隊與下一組合併（極少發生；16 隊不會出現）


static func _interleave_regions(w: WorldState, ids: Array) -> Array:
	var half = ids.size() / 2
	var top: Array = ids.slice(0, half)
	var bottom: Array = ids.slice(half)
	bottom.reverse()
	var out: Array = []
	for i in half:
		out.append(top[i])
		out.append(bottom[i])
	if ids.size() % 2 == 1:
		out.append(ids[-1])
	return out


## 瑞士輪：本輪全部打完 → 排下一輪。
static func _advance_swiss(w: WorldState, lg: League) -> void:
	if lg.format.get("regular", {}).get("type", "") != "swiss" or lg.club_ids.is_empty():
		return
	if lg.fixtures.any(func(f): return f["stage"] == "regular" and not f["played"]):
		return
	if not swiss_active(lg).is_empty():
		_swiss_round(w, lg, w.day + 1)


static func play_day(w: WorldState) -> Array:
	var results: Array = []
	for lg in all_competitions(w):
		for fx in lg.fixtures:
			if fx["played"] or int(fx["day"]) != w.day:
				continue
			results.append(play_fixture(w, lg, fx))
		if not lg.playoff_bracket.is_empty() and not lg.season_complete:
			_advance_playoffs(w, lg)
	return results


static func play_fixture(w: WorldState, lg: League, fx: Dictionary) -> Dictionary:
	var s = prepare_series(w, fx)
	while not s.is_done():
		var ds = s.new_draft()
		ds.run_all()
		s.play_game(ds)
	return complete_fixture(w, lg, fx, s.result())


static func stakes_of(fx: Dictionary) -> float:
	if fx.has("stakes"):
		return float(fx["stakes"])
	return 1.0 if fx["stage"] == "regular" else (1.6 if fx["stage"] == "final" else 1.3)


## 建立系列賽（玩家手動 BP 時由 GameSession 逐局推進）。
static func prepare_series(w: WorldState, fx: Dictionary) -> SeriesState:
	var home: Club = w.clubs[fx["home"]]
	var away: Club = w.clubs[fx["away"]]
	for c in [home, away]:
		if not LineupSelector.is_valid(w, c):
			LineupSelector.pick(w, c)
	var a = TeamContext.from_club(w, home)
	var b = TeamContext.from_club(w, away)
	var detail = home.is_human or away.is_human
	return SeriesState.new(a, b, int(fx["best_of"]), w.champions, w.patch, w.rng.fork(hash(fx["id"])), detail, stakes_of(fx))


static func complete_fixture(w: WorldState, lg: League, fx: Dictionary, series: Dictionary) -> Dictionary:
	var home: Club = w.clubs[fx["home"]]
	var away: Club = w.clubs[fx["away"]]
	var detail = home.is_human or away.is_human
	fx["played"] = true
	fx["result"] = {"winner": series["winner"], "score": series["score"]}
	if detail:
		fx["result"]["games"] = series["games"]
	MatchEffects.apply_series(w, series, stakes_of(fx))
	if fx["stage"] == "regular":
		_record(lg, series)
	Media.on_match(w, lg, fx, series)
	var winner: Club = w.clubs[series["winner"]]
	w.log.add("match", w.day, [home.id, away.id], {"fixture": fx["id"], "winner": winner.id,
		"score": "%d-%d" % [series["score"][home.id], series["score"][away.id]], "stage": fx["stage"]}, [])
	return {"league": lg.id, "fixture": fx, "series": series}


static func find_fixture(w: WorldState, club_id: String, day: int) -> Dictionary:
	for lg in all_competitions(w):
		for fx in lg.fixtures:
			if not fx["played"] and int(fx["day"]) == day and (fx["home"] == club_id or fx["away"] == club_id):
				return {"league": lg, "fixture": fx}
	return {}


static func _record(lg: League, series: Dictionary) -> void:
	var w_id: String = series["winner"]
	var l_id: String = series["loser"]
	var sw: Dictionary = lg.standings[w_id]
	var sl: Dictionary = lg.standings[l_id]
	sw["w"] += 1
	sl["l"] += 1
	sw["gw"] += series["score"][w_id]
	sw["gl"] += series["score"][l_id]
	sl["gw"] += series["score"][l_id]
	sl["gl"] += series["score"][w_id]
	sw["h2h"][l_id] = int(sw["h2h"].get(l_id, 0)) + 1


## 排名：勝場 → 小分差 → 對戰紀錄 → 小分勝場。
static func sorted_standings(lg: League) -> Array:
	var ids: Array = lg.standings.keys()
	ids.sort_custom(func(a, b):
		var sa: Dictionary = lg.standings[a]
		var sb: Dictionary = lg.standings[b]
		if sa["w"] != sb["w"]:
			return sa["w"] > sb["w"]
		var da: int = sa["gw"] - sa["gl"]
		var db: int = sb["gw"] - sb["gl"]
		if da != db:
			return da > db
		var ha: int = int(sa["h2h"].get(b, 0))
		var hb: int = int(sb["h2h"].get(a, 0))
		if ha != hb:
			return ha > hb
		return sa["gw"] > sb["gw"])
	return ids


static func start_playoffs(w: WorldState, lg: League) -> void:
	var fmt: Dictionary = lg.format.get("playoffs", {})
	var n := int(fmt.get("teams", 4))
	var seeds = sorted_standings(lg).slice(0, n)
	lg.playoff_bracket = [seeds]
	_schedule_round(w, lg, seeds, w.day + 3)


static func _schedule_round(w: WorldState, lg: League, teams: Array, day: int) -> void:
	var bo := int(lg.format.get("playoffs", {}).get("best_of", 5))
	var stage := "final" if teams.size() == 2 else "playoffs"
	var rnd = lg.playoff_bracket.size()
	for i in teams.size() / 2:
		var hi: String = teams[i]
		var lo: String = teams[teams.size() - 1 - i]
		lg.fixtures.append(_with_stakes(lg, {"id": "%s_%d_po%d_%s_%s" % [lg.id, w.year, rnd, hi, lo], "day": day, "stage": stage,
			"round": rnd, "home": hi, "away": lo, "best_of": bo, "played": false, "result": {}}))


static func _advance_playoffs(w: WorldState, lg: League) -> void:
	var rnd = lg.playoff_bracket.size()
	var current = lg.fixtures.filter(func(f): return f["stage"] != "regular" and int(f["round"]) == rnd)
	if current.is_empty() or current.any(func(f): return not f["played"]):
		return
	var winners: Array = current.map(func(f): return f["result"]["winner"])
	if winners.size() == 1:
		lg.champion_id = winners[0]
		lg.season_complete = true
		return
	lg.playoff_bracket.append(winners)
	_schedule_round(w, lg, winners, w.day + 4)


static func next_match_day(w: WorldState, club_id: String) -> int:
	var best := -1
	for lg in all_competitions(w):
		for fx in lg.fixtures:
			if not fx["played"] and (fx["home"] == club_id or fx["away"] == club_id):
				if best == -1 or int(fx["day"]) < best:
					best = int(fx["day"])
	return best
