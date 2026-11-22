extends TestCase


func test_league_schedule_double_round_robin() -> void:
	var w = make_world()
	var lg: League = w.leagues["ecl"]
	var n = lg.club_ids.size()
	check_eq(lg.fixtures.size(), n * (n - 1), "each pair meets twice")
	var pairs := {}
	for f in lg.fixtures:
		var key = "%s|%s" % [f["home"], f["away"]]
		check(not pairs.has(key), "no duplicate home/away pairing")
		pairs[key] = true


## 第一階段驗收標準：完整打完一個賽季，並進入轉會期。
func test_full_season_reaches_transfer_window() -> void:
	var w = make_world(11, "harbor_lights")
	var guard := 0
	while w.phase != WorldState.PHASE_OFFSEASON and guard < 400:
		WorldSimulator.advance_day(w)
		guard += 1
	check_eq(w.phase, WorldState.PHASE_OFFSEASON, "season ends in offseason")
	for lg in w.leagues.values():
		check(lg.champion_id != "", "%s has a champion" % lg.id)
	check_eq(w.history["seasons"].size(), 1, "season recorded in history")
	var human: Club = w.clubs["harbor_lights"]
	var played := 0
	for pid in human.lineup.values():
		played += w.players[pid].season_stats.get("games", 0)
	check(played > 0, "human club played matches")
	print("  season finished on day %d; ECL champion: %s" % [w.day, w.clubs[w.leagues["ecl"].champion_id].name])


func test_save_load_is_deterministic() -> void:
	var w = make_world(21)
	WorldSimulator.advance_days(w, 40)
	var json = SaveSystem.to_json(w)
	var copy = SaveSystem.from_json(json)
	check(copy != null, "save loads")
	WorldSimulator.advance_days(w, 40)
	WorldSimulator.advance_days(copy, 40)
	check_eq(_fingerprint(copy), _fingerprint(w), "loaded world evolves identically")


func _fingerprint(w: WorldState) -> String:
	var parts: Array = [w.day, w.phase, w.rng.get_state()["state"]]
	for lg in w.leagues.values():
		for cid in LeagueEngine.sorted_standings(lg):
			parts.append("%s:%d-%d" % [cid, int(lg.standings[cid]["w"]), int(lg.standings[cid]["l"])])
	var total := 0.0
	for p in w.players.values():
		for s in p.skills:
			total += float(p.skills[s])
	parts.append(snappedf(total, 0.01))
	return str(parts)


## 多年世界模擬：世代交替、俱樂部興衰、名單永遠可用。
func test_decades_of_world_simulation() -> void:
	var w = make_world(2027)
	var original := {}
	for p in w.active_players():
		original[p.id] = true
	var start_year = w.year
	var years := 12
	var t0 = Time.get_ticks_msec()
	var champions := {}
	while w.year < start_year + years:
		WorldSimulator.advance_day(w)
		if w.phase == WorldState.PHASE_REGULAR and w.day == w.phase_day:
			for c in w.clubs.values():
				check(LineupSelector.is_valid(w, c), "year %d: %s fields a full lineup" % [w.year, c.id])
	for s in w.history["seasons"]:
		for lid in s["leagues"]:
			champions[s["leagues"][lid]["champion"]] = true
	var still_active := 0
	for pid in original:
		if not w.players[pid].retired:
			still_active += 1
	var secs = (Time.get_ticks_msec() - t0) / 1000.0
	var starters_regen := 0
	var starters := 0
	for c in w.clubs.values():
		for pid in c.lineup.values():
			starters += 1
			if not original.has(pid):
				starters_regen += 1
	print("  %d seasons in %.1fs; original players still active: %d/%d; starters who entered after year 0: %d/%d; distinct champions: %d; retirements: %d; transfers: %d" % [
		years, secs, still_active, original.size(), starters_regen, starters, champions.size(), w.history["retirements"].size(), w.history["transfers"].size()])
	check_eq(w.history["seasons"].size(), years, "every season recorded")
	check(still_active < original.size() * 0.35, "first generation mostly retired after %d years" % years)
	check(starters_regen > starters * 0.6, "new generation now forms most lineups")
	check(champions.size() >= 4, "power shifts between clubs over the decade")
	var pop = w.active_players().size()
	var cap = w.clubs.size() * 20
	check(pop > w.clubs.size() * 6 and pop < cap, "player population stays stable (%d, limit %d)" % [pop, cap])
