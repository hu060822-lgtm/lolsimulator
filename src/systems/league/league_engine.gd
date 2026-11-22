## 聯賽與賽事：賽程生成、比賽日執行、排名（含同分判定）、季後賽。
## 賽制由 League.format（資料）決定。
class_name LeagueEngine
extends RefCounted

const PRESEASON_DAYS := 14


static func start_season(w: WorldState) -> void:
	w.phase = WorldState.PHASE_PRESEASON
	w.phase_day = w.day
	for lg in w.leagues.values():
		lg.fixtures = []
		lg.standings = {}
		lg.playoff_bracket = []
		lg.champion_id = ""
		lg.season_complete = false
		for cid in lg.club_ids:
			lg.standings[cid] = {"w": 0, "l": 0, "gw": 0, "gl": 0, "h2h": {}}
		_generate_regular(w, lg, w.day + PRESEASON_DAYS)


## 雙循環（circle method）
static func _generate_regular(w: WorldState, lg: League, start_day: int) -> void:
	var fmt: Dictionary = lg.format.get("regular", {})
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
			rn += 1
			for pr in pairs:
				var home: String = pr[0] if leg == 0 else pr[1]
				var away: String = pr[1] if leg == 0 else pr[0]
				lg.fixtures.append({"id": "%s_%d_r%d_%s_%s" % [lg.id, w.year, rn, home, away], "day": day, "stage": "regular",
					"round": rn, "home": home, "away": away, "best_of": bo, "played": false, "result": {}})
			day += gap


static func regular_done(lg: League) -> bool:
	return lg.fixtures.filter(func(f): return f["stage"] == "regular" and not f["played"]).is_empty()


static func play_day(w: WorldState) -> Array:
	var results: Array = []
	for lg in w.leagues.values():
		for fx in lg.fixtures:
			if fx["played"] or int(fx["day"]) != w.day:
				continue
			results.append(play_fixture(w, lg, fx))
		if w.phase == WorldState.PHASE_PLAYOFFS and not lg.season_complete:
			_advance_playoffs(w, lg)
	return results


static func play_fixture(w: WorldState, lg: League, fx: Dictionary) -> Dictionary:
	var home: Club = w.clubs[fx["home"]]
	var away: Club = w.clubs[fx["away"]]
	for c in [home, away]:
		if not LineupSelector.is_valid(w, c):
			LineupSelector.pick(w, c)
	var a = TeamContext.from_club(w, home)
	var b = TeamContext.from_club(w, away)
	var detail = home.is_human or away.is_human
	var stakes = 1.0 if fx["stage"] == "regular" else (1.6 if fx["stage"] == "final" else 1.3)
	var series = SeriesSim.play(a, b, int(fx["best_of"]), w.champions, w.patch, w.rng.fork(hash(fx["id"])), detail, stakes)
	fx["played"] = true
	fx["result"] = {"winner": series["winner"], "score": series["score"]}
	if detail:
		fx["result"]["games"] = series["games"]
	MatchEffects.apply_series(w, series, stakes)
	if fx["stage"] == "regular":
		_record(lg, series)
	var winner: Club = w.clubs[series["winner"]]
	w.log.add("match", w.day, [home.id, away.id], {"fixture": fx["id"], "winner": winner.id,
		"score": "%d-%d" % [series["score"][home.id], series["score"][away.id]], "stage": fx["stage"]}, [])
	return {"league": lg.id, "fixture": fx, "series": series}


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
		lg.fixtures.append({"id": "%s_%d_po%d_%s_%s" % [lg.id, w.year, rnd, hi, lo], "day": day, "stage": stage,
			"round": rnd, "home": hi, "away": lo, "best_of": bo, "played": false, "result": {}})


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
	for lg in w.leagues.values():
		for fx in lg.fixtures:
			if not fx["played"] and (fx["home"] == club_id or fx["away"] == club_id):
				if best == -1 or int(fx["day"]) < best:
					best = int(fx["day"])
	return best
