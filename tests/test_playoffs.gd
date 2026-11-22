extends TestCase
## 季後賽對戰表：單淘汰 4/6/8 隊、雙敗 4/6/8 隊；聯盟制不升降級。


func _run_bracket(kind: String, n: int, upset_every: int) -> Dictionary:
	var w = make_world()
	var lg: League = null
	for l in w.leagues.values():
		if l.tier == 1:
			lg = l
			break
	# 確保有 n 支隊伍
	var ids: Array = w.clubs.keys().slice(0, n)
	lg.club_ids = ids
	LeagueEngine._reset(lg)
	for i in ids.size():
		lg.standings[ids[i]]["w"] = 100 - i
	lg.format = lg.format.duplicate(true)
	lg.format["playoffs"] = {"type": kind, "teams": n, "best_of": 5}
	lg.fixtures = []
	LeagueEngine.start_playoffs(w, lg)
	var played := 0
	var guard := 0
	while not lg.season_complete and guard < 200:
		guard += 1
		w.day += 1
		var busy := {}
		for fx in lg.fixtures:
			if fx["played"] or int(fx["day"]) != w.day:
				continue
			for cid in [fx["home"], fx["away"]]:
				check(not busy.has(cid), "%s plays once per day" % cid)
				busy[cid] = true
			played += 1
			var win: String = fx["away"] if upset_every > 0 and played % upset_every == 0 else fx["home"]
			fx["played"] = true
			fx["result"] = {"winner": win, "score": {fx["home"]: 3 if win == fx["home"] else 1, fx["away"]: 3 if win == fx["away"] else 1}}
		LeagueEngine._advance_playoffs(w, lg)
	return {"lg": lg, "played": played, "seeds": ids}


func test_brackets_complete_with_expected_matches() -> void:
	var cases = [["single_elimination", 4, 3], ["single_elimination", 6, 5], ["single_elimination", 8, 7],
		["double_elimination", 4, 6], ["double_elimination", 6, 8], ["double_elimination", 8, 14]]
	for c in cases:
		var r = _run_bracket(c[0], c[1], 0)
		var lg: League = r["lg"]
		check(lg.season_complete, "%s %d finishes" % [c[0], c[1]])
		check_eq(r["played"], c[2], "%s %d match count" % [c[0], c[1]])
		check_eq(lg.champion_id, r["seeds"][0], "%s %d: favourites always winning means seed 1 wins" % [c[0], c[1]])
		check_eq(lg.playoff_bracket[-1].size(), 4, "%s %d top four recorded" % [c[0], c[1]])
		check(lg.fixtures.filter(func(f): return f["stage"] == "final").size() == 1, "one final")
		# 有爆冷時也要能打完
		var r2 = _run_bracket(c[0], c[1], 3)
		check(r2["lg"].season_complete, "%s %d finishes with upsets" % [c[0], c[1]])


func test_double_elimination_gives_second_chance() -> void:
	# 每場都由客隊（較低種子／敗部隊伍）獲勝時，仍會打滿 14 場
	var r = _run_bracket("double_elimination", 8, 1)
	check_eq(r["played"], 14, "full double-elimination bracket")
	check(r["lg"].season_complete, "finishes")


func test_franchise_leagues_do_not_relegate() -> void:
	var m = DataModule.load_from_dir("res://data/modules/lol_world")
	var w = WorldBuilder.build(m, 21, "")
	for lg in w.leagues.values():
		if lg.tier == 1:
			check(lg.format.get("franchise", false), "%s is a franchise league" % lg.short_name)
	var season := {}
	for lg in w.leagues.values():
		if lg.tier == 2:
			lg.champion_id = lg.club_ids[0]
	WorldSimulator._promotion_relegation(w, season)
	check_eq(season["movements"].size(), 0, "no promotion or relegation")
