extends TestCase
## 第五輪：版本 Meta 競賽、選手手感、青訓試訓、故事線與傳承、自動存檔。


func _session(seed_v: int = 21, club_id: String = "crimson_tide_gaming") -> GameSession:
	var s := GameSession.new()
	var errs = s.new_game(MODULE_DIR, seed_v, club_id)
	check(errs.is_empty(), "new game ok")
	s.manual_draft = false
	return s


func test_meta_bonus_rewards_research_and_meta_plan() -> void:
	check_eq(MetaRace.bonus(0.0, "teamfight", "teamfight"), 0.0, "no research, no bonus")
	var on := MetaRace.bonus(100.0, "teamfight", "teamfight")
	var off := MetaRace.bonus(100.0, "pick", "teamfight")
	check(on > off and off > 0.0, "playing the meta plan pays more than general understanding")
	check(absf(on - (MetaRace.GENERAL + MetaRace.PLAN_EDGE)) < 0.0001, "full bonus")


func test_world_starts_with_meta_plan_and_patches_midseason() -> void:
	var w := make_world(5, "harbor_lights")
	check(w.patch.meta_plan in StyleMatchup.CYCLE, "initial patch has a meta plan")
	var v0 := w.patch.version
	var guard := 0
	while w.patch.version == v0 and guard < 200:
		WorldSimulator.advance_day(w)
		guard += 1
	check(w.patch.version != v0, "a mid-season patch arrived")
	check_eq(w.patch.version, MetaRace.next_version(v0), "minor version bump")
	check(w.inbox.any(func(m): return m.get("kind") == "patch"), "human told about the patch")


func test_meta_study_speeds_up_research() -> void:
	var s := _session()
	var w := s.world
	var me := s.club()
	var ai: Club = null
	for c in w.clubs.values():
		if not c.is_human:
			ai = c
			break
	me.meta_research = 0.0
	ai.meta_research = 0.0
	var plan := TrainingEngine.default_plan()
	plan["rest"] = 0
	plan["meta_study"] = 2
	me.training_plan = plan
	w.patch.started_day = w.day
	MetaRace.weekly(w)
	check(me.meta_research > 0.0, "research grows")
	var mine := me.meta_research / maxf(StaffSystem.rating(w, me, "drafting"), 1.0)
	var theirs := ai.meta_research / maxf(StaffSystem.rating(w, ai, "drafting"), 1.0)
	check(mine > theirs, "two study slots beat the AI default (per analyst point)")


func test_team_context_carries_meta() -> void:
	var s := _session()
	var w := s.world
	s.club().meta_research = 80.0
	var t := TeamContext.from_club(w, s.club())
	check_eq(t.meta_research, 80.0, "research copied")
	check_eq(t.meta_plan, w.patch.meta_plan, "meta plan copied")


func test_hot_streak_rises_and_decays() -> void:
	var w := make_world(9)
	var p: Player = w.players.values()[0]
	p.hot = 0.0
	var series := {"games": [{"players": {p.id: {"rating": 9.5}}}, {"players": {p.id: {"rating": 9.0}}}]}
	FormStreak.after_series(w, series)
	check(p.hot > 0.5, "great games heat up a player")
	check(FormStreak.label(p) != "", "labelled")
	var h := p.hot
	FormStreak.weekly(p)
	check(p.hot < h, "hot streak cools over time")
	FormStreak.after_series(w, {"games": [{"players": {p.id: {"rating": 3.0}}}]})
	FormStreak.after_series(w, {"games": [{"players": {p.id: {"rating": 3.0}}}]})
	check(p.hot < 0.0, "bad games turn him cold")


func test_hot_players_raise_briefing_form() -> void:
	var s := _session()
	var w := s.world
	var t := TeamContext.from_club(w, s.club())
	var base := MatchBriefing.avg_form(w, t)
	for p in t.players.values():
		p.hot = 1.0
	check(MatchBriefing.avg_form(w, t) > base + 0.05, "hot streak shows in expected form")


func test_tryouts_offer_three_prospects_and_sign() -> void:
	var s := _session()
	var w := s.world
	YouthAcademy.tryouts(w)
	var msgs := w.inbox.filter(func(m): return m.get("kind") == "tryout")
	check_eq(msgs.size(), 1, "tryout message")
	var msg: Dictionary = msgs[0]
	check_eq(msg["prospects"].size(), 3, "three prospects")
	for pid in msg["prospects"]:
		var e: Dictionary = msg["estimates"][pid]
		check(int(e["lo"]) < int(e["hi"]), "potential shown as a range")
		check(w.players[pid].age(w.year + 1) <= 17, "young prospect")
	var pid0: String = msg["prospects"][0]
	var e0: Dictionary = msg["estimates"][pid0]
	var w0 := int(e0["hi"]) - int(e0["lo"])
	var cash := s.club().cash
	s.respond_to_message(msg["id"], "try:look")
	check(s.club().cash < cash, "extra look costs money")
	var e1: Dictionary = msg["estimates"][pid0]
	check(int(e1["hi"]) - int(e1["lo"]) < w0, "range narrows after another look")
	check(not msg["resolved"], "still open after a look")
	var r := s.respond_to_message(msg["id"], "try:" + pid0)
	check(r.get("signed", false), "signed")
	check_eq(w.players[pid0].club_id, s.club().id, "prospect joined")
	check_eq(w.players[pid0].contract.role_promise, "prospect", "academy contract")


func test_milestone_celebrated_once() -> void:
	var s := _session()
	var w := s.world
	var p: Player = w.players[s.club().lineup.values()[0]]
	p.career["games"] = 100
	p.career["milestones"] = []
	var m0 := p.morale
	Legacy.check_milestones(w, {"games": [{"players": {p.id: {}}}]})
	check("games_100" in p.career["milestones"], "milestone recorded")
	check(p.morale > m0, "morale boost")
	var n := w.log.of_type("milestone").size()
	Legacy.check_milestones(w, {"games": [{"players": {p.id: {}}}]})
	check_eq(w.log.of_type("milestone").size(), n, "not celebrated twice")


func test_retiring_legend_enters_hall_and_farewell() -> void:
	var s := _session()
	var w := s.world
	var me := s.club()
	var p: Player = w.players[me.roster[0]]
	p.career["titles"] = 4
	p.career["mvps"] = 1
	p.history.append({"year": w.year - 1, "club_id": me.id, "games": 30})
	p.history.append({"year": w.year, "club_id": me.id, "games": 30})
	Legacy.on_retire(w, p, me.id)
	check(Legacy.hall_of_fame(w).any(func(e): return e["player_id"] == p.id), "inducted into hall of fame")
	var fw := w.inbox.filter(func(m): return m.get("kind") == "farewell" and m.get("player_id") == p.id)
	check_eq(fw.size(), 1, "farewell message")
	var brand := me.brand
	s.respond_to_message(fw[0]["id"], "fw:ceremony")
	check(me.brand > brand, "ceremony lifts brand")
	check(me.legends.any(func(e): return e["player_id"] == p.id), "listed as club legend")


func test_retired_player_can_join_staff() -> void:
	var s := _session()
	var w := s.world
	var me := s.club()
	var p: Player = w.players[me.roster[1]]
	Legacy.on_retire(w, p, me.id)
	var fw := w.inbox.filter(func(m): return m.get("kind") == "farewell" and m.get("player_id") == p.id)
	me.cash += 1000000
	var r := s.respond_to_message(fw[0]["id"], "fw:coach")
	var hired := me.staff.values().any(func(sid): return w.staff.has(sid) and w.staff[sid].name == p.handle)
	check(hired, "former player now on staff (%s)" % r.get("note", ""))


func test_autosave_weekly() -> void:
	var s := _session()
	s.club().settings["autosave_day"] = -999
	check(s.maybe_autosave(), "first autosave written")
	check(not s.maybe_autosave(), "not again on the same day")
	check(not GameSession.slot_info(GameSession.AUTOSAVE_SLOT).is_empty(), "autosave slot has meta")
	s.club().settings["autosave"] = false
	check(not s.maybe_autosave(true), "disabled autosave does nothing")


func test_save_roundtrip_keeps_new_fields() -> void:
	var s := _session()
	var w := s.world
	s.club().meta_research = 42.0
	s.club().legends.append({"player_id": "x", "handle": "Old", "year": 2020})
	var p: Player = w.players[s.club().roster[0]]
	p.hot = 0.75
	var path := "user://round5_test.json"
	check_eq(s.save(path), OK, "saved")
	var s2 := GameSession.new()
	check(s2.load_game(path), "loaded")
	check_eq(s2.club().meta_research, 42.0, "research persisted")
	check_eq(s2.club().legends.size(), 1, "legends persisted")
	check_eq(s2.world.players[p.id].hot, 0.75, "hot streak persisted")
	check_eq(s2.world.patch.meta_plan, w.patch.meta_plan, "meta plan persisted")
