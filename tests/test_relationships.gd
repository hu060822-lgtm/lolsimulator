extends TestCase
## 第二階段：關係網絡與選手心理。


func _pair(w: WorldState, club: Club) -> Array:
	return [w.players[club.roster[0]], w.players[club.roster[1]]]


func test_compatibility_reflects_personality() -> void:
	var w = make_world(2027)
	var c: Club = w.clubs["harbor_lights"]
	var pr = _pair(w, c)
	var a: Player = pr[0]
	var b: Player = pr[1]
	for t in ["teamwork", "temperament"]:
		a.personality[t] = 90.0
		b.personality[t] = 90.0
	var good = Relationships.compatibility(a, b, w.year)
	for t in ["teamwork", "temperament"]:
		a.personality[t] = 15.0
		b.personality[t] = 15.0
	var bad = Relationships.compatibility(a, b, w.year)
	print("  compatibility calm team players %.1f vs hot-headed loners %.1f" % [good, bad])
	check(good > bad + 30.0, "personality drives compatibility")


func test_relations_affect_execution_and_happiness() -> void:
	var w = make_world(2027)
	var c: Club = w.clubs["harbor_lights"]
	var ids: Array = c.lineup.values()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			w.relations[Relationships.key(ids[i], ids[j])] = 80.0
	var friendly = TeamContext.from_club(w, c).execution()
	var p: Player = w.players[ids[0]]
	var happy_sat = CareerAgent.evaluate(w, p)["relationships"]
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			w.relations[Relationships.key(ids[i], ids[j])] = -80.0
	var hostile = TeamContext.from_club(w, c).execution()
	var sad_sat = CareerAgent.evaluate(w, p)["relationships"]
	print("  execution friendly %.3f vs hostile %.3f" % [friendly, hostile])
	check(friendly > hostile + 0.05, "good relations improve execution")
	check(happy_sat > sad_sat + 0.8, "relations feed player satisfaction")


func test_losing_streak_breeds_conflict_for_human_club() -> void:
	var w = make_world(2027, "harbor_lights")
	var c: Club = w.human_club()
	c.streak = -5
	for pid in c.roster:
		w.players[pid].personality["temperament"] = 10.0
	var ids: Array = c.roster
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			w.relations[Relationships.key(ids[i], ids[j])] = -50.0
	var found := false
	for week in 20:
		Relationships.weekly(w, c)
		if w.inbox.any(func(m): return m["kind"] == "conflict"):
			found = true
			break
	check(found, "conflict reaches the inbox")
	var msg = w.inbox.filter(func(m): return m["kind"] == "conflict")[0]
	var before = Relationships.get_rel(w, msg["player_id"], msg["other_id"])
	var r = Relationships.resolve_conflict(w, msg, "back_first")
	check(msg["resolved"], "message resolved")
	check(Relationships.get_rel(w, msg["player_id"], msg["other_id"]) < before, "taking sides hurts the pair")
	check(r["note"] != "", "result explained")


func test_tilt_after_losing_a_game() -> void:
	var w = make_world(2027)
	var a = TeamContext.from_club(w, w.clubs["jade_dragons"])
	var b = TeamContext.from_club(w, w.clubs["iron_lotus"])
	var s := SeriesState.new(a, b, 5, w.champions, w.patch, SimRng.new(3), false, 1.0)
	s.play_game(s.new_draft())
	var loser = a if s.games[0]["loser_club"] == a.club_id else b
	var winner = b if loser == a else a
	check(loser.tilt.size() == 5, "every loser player carries tilt")
	check(winner.tilt.values().all(func(v): return float(v) < 0.0), "winner carries momentum, not tilt")
	var low := 0.0
	for p in loser.players.values():
		low = maxf(low, loser.tilt[p.id])
	check(low > 0.0 and low <= 0.06, "tilt bounded by composure")


func test_big_game_experience_accumulates() -> void:
	var w = make_world(2027)
	var a = TeamContext.from_club(w, w.clubs["jade_dragons"])
	var b = TeamContext.from_club(w, w.clubs["iron_lotus"])
	var series = SeriesSim.play(a, b, 5, w.champions, w.patch, SimRng.new(8), false, 2.0)
	MatchEffects.apply_series(w, series, 2.0)
	var pid: String = w.clubs["jade_dragons"].lineup["MID"]
	check(int(w.players[pid].career.get("big_games", 0)) >= 1, "playoff series counts as big game")
	var c: Club = w.clubs[series["winner"]]
	check_eq(c.streak, 1, "winner streak starts")
