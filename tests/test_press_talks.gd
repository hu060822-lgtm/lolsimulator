extends TestCase
## 記者會與選手之間的對話事件。


func test_press_conference_after_big_match() -> void:
	var w = make_world(31, "crimson_tide_gaming")
	var me: Club = w.human_club()
	var lg: League = w.leagues[me.league_id]
	var opp_id: String = lg.club_ids.filter(func(c): return c != me.id)[0]
	var fx = {"home": me.id, "away": opp_id, "stage": "final"}
	PressConference.after_series(w, lg, fx, {"winner": me.id, "score": {me.id: 3, opp_id: 1}})
	var msgs = w.inbox.filter(func(m): return m.get("kind") == "press")
	check_eq(msgs.size(), 1, "a final always has a press conference")
	var p: Player = w.players[me.lineup["MID"]]
	var before = p.morale
	var r = PressConference.answer(w, msgs[0], "praise")
	check(p.morale > before, "praise lifts morale: %s" % r["note"])
	check(msgs[0]["resolved"], "resolved")
	# 新的記者會會讓舊的自動結束
	PressConference.after_series(w, lg, fx, {"winner": opp_id, "score": {me.id: 1, opp_id: 3}})
	PressConference.after_series(w, lg, fx, {"winner": opp_id, "score": {me.id: 1, opp_id: 3}})
	check_eq(w.inbox.filter(func(m): return m.get("kind") == "press" and not m.get("resolved", false)).size(), 1, "only one open press conference")


func test_provoke_backfires_after_loss() -> void:
	var w = make_world(32, "crimson_tide_gaming")
	var me: Club = w.human_club()
	var before = me.opinion
	PressConference.answer(w, {"won": false, "opponent": ""}, "provoke")
	check(me.opinion < before, "provoking after a loss hurts public opinion")


func test_teammate_talks_appear_and_resolve() -> void:
	var w = make_world(33, "crimson_tide_gaming")
	w.phase = WorldState.PHASE_REGULAR
	var me: Club = w.human_club()
	me.streak = -3
	var kinds := {}
	for i in 120:
		w.day += 7
		TeammateTalks.weekly(w, me)
		for m in w.inbox:
			if m.get("kind") in ["duo_practice", "team_bonding", "mentor_talk"] and not m.get("resolved", false):
				kinds[m["kind"]] = m
	check(kinds.has("duo_practice"), "duo practice request appears")
	check(kinds.has("team_bonding"), "team bonding proposal appears during a losing streak")
	if kinds.has("duo_practice"):
		var m: Dictionary = kinds["duo_practice"]
		var before = Relationships.get_rel(w, m["player_id"], m["other_id"])
		TeammateTalks.resolve(w, m, "duo:approve")
		check(Relationships.get_rel(w, m["player_id"], m["other_id"]) > before, "extra duo practice improves the relationship")
	if kinds.has("team_bonding"):
		var cash = me.cash
		TeammateTalks.resolve(w, kinds["team_bonding"], "bond:fund")
		check(me.cash < cash, "bonding costs money")
