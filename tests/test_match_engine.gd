extends TestCase
## 比賽引擎的核心承諾：比賽不是總評比較。BP、戰術、穩定性都必須能改變結果。


func _ctx(w: WorldState, club_id: String, tag: String) -> TeamContext:
	var t = TeamContext.from_club(w, w.clubs[club_id])
	t.club_id = tag
	t.name = tag
	return t


## 爛 BP：每個位置選一隻「不在英雄池、全物理、沒有前排與開戰」的英雄。
func _bad_picks(w: WorldState, t: TeamContext) -> Dictionary:
	var out := {}
	var used := {}
	for role in Attr.ROLES:
		var p: Player = t.players[role]
		var best: Champion = null
		var best_v := INF
		for c in w.champions.values():
			if not (role in c.roles) or used.has(c.id):
				continue
			var v: float = p.mastery(c.id) + (c.tag("frontline") + c.tag("engage") + c.tag("disengage")) * 15.0 + (30.0 if c.damage != "AD" else 0.0) - w.patch.meta(c.id) * 5.0
			if v < best_v:
				best_v = v
				best = c
		out[role] = best.id
		used[best.id] = true
	return out


func _win_rate(w: WorldState, a: TeamContext, b: TeamContext, n: int, seed_base: int) -> float:
	var wins := 0
	for i in n:
		var s = SeriesSim.play(a, b, 1, w.champions, w.patch, SimRng.new(seed_base + i), false)
		if s["winner"] == a.club_id:
			wins += 1
	return float(wins) / n


func test_deterministic_with_same_seed() -> void:
	var w = make_world()
	var r1 = SeriesSim.play(_ctx(w, "jade_dragons", "A"), _ctx(w, "harbor_lights", "B"), 3, w.champions, w.patch, SimRng.new(5))
	var r2 = SeriesSim.play(_ctx(w, "jade_dragons", "A"), _ctx(w, "harbor_lights", "B"), 3, w.champions, w.patch, SimRng.new(5))
	check_eq(r1["score"], r2["score"], "same seed -> same series score")
	check_eq(r1["games"][0]["events"].size(), r2["games"][0]["events"].size(), "same seed -> same events")


func test_identical_rosters_bad_draft_loses() -> void:
	var w = make_world()
	var good = _ctx(w, "jade_dragons", "GOOD")
	var bad = _ctx(w, "jade_dragons", "BAD")
	bad.forced_picks = _bad_picks(w, bad)
	var wr = _win_rate(w, good, bad, 150, 1000)
	print("  identical rosters, good draft vs bad draft: %.1f%%" % (wr * 100.0))
	check(wr >= 0.62, "BP alone should swing identical rosters (got %.2f)" % wr)


func test_underdog_wins_through_draft() -> void:
	var w = make_world()
	# 先確認兩隊實力差距：強隊 CA 較高
	var strong = _ctx(w, "crimson_tide_gaming", "STRONG")
	var weak = _ctx(w, "harbor_lights", "WEAK")
	var baseline = _win_rate(w, weak, strong, 150, 2000)
	strong.forced_picks = _bad_picks(w, strong)
	var with_draft_edge = _win_rate(w, weak, strong, 150, 2000)
	print("  underdog win rate: baseline %.1f%% → when favourite drafts badly %.1f%%" % [baseline * 100.0, with_draft_edge * 100.0])
	check(baseline < 0.45, "favourite should normally be favoured (underdog %.2f)" % baseline)
	check(with_draft_edge > baseline + 0.12, "draft advantage must materially help the underdog")


func test_consistency_drives_mistakes() -> void:
	var w = make_world()
	var mistakes = {"low": 0, "high": 0}
	for label in ["low", "high"]:
		var a = _ctx(w, "silver_monsoon", "A")
		var b = _ctx(w, "iron_lotus", "B")
		var originals := {}
		for role in a.players:
			var p: Player = a.players[role]
			originals[p.id] = p.skill("consistency")
		for p in a.players.values():
			p.skills["consistency"] = 20.0 if label == "low" else 95.0
		for i in 60:
			var s = SeriesSim.play(a, b, 1, w.champions, w.patch, SimRng.new(300 + i), false)
			for pid in s["games"][0]["players"]:
				var st: Dictionary = s["games"][0]["players"][pid]
				if st["side"] == ("blue" if s["games"][0]["blue_club"] == "A" else "red"):
					mistakes[label] += st["mistakes"]
		for p in a.players.values():
			p.skills["consistency"] = originals[p.id]
	print("  mistakes over 60 games: consistency 20 → %d, consistency 95 → %d" % [mistakes["low"], mistakes["high"]])
	check(mistakes["low"] > mistakes["high"] * 1.5, "low consistency must produce more mistakes")


func test_events_are_traceable() -> void:
	var w = make_world()
	var s = SeriesSim.play(_ctx(w, "northstar_esports", "A"), _ctx(w, "iron_lotus", "B"), 1, w.champions, w.patch, SimRng.new(77))
	var g: Dictionary = s["games"][0]
	check(g["events"].size() > 10, "detailed game has events")
	var untraced = g["events"].filter(func(e): return e["type"] in ["teamfight", "gank", "solo_kill", "dragon", "baron", "adapt"] and e["causes"].is_empty())
	check(untraced.is_empty(), "key events must carry causes (%d without)" % untraced.size())
	check(g["draft"]["log"].size() == 20, "draft has 20 recorded actions with reasons")


func test_live_tactical_order_is_applied() -> void:
	var w = make_world()
	var a = _ctx(w, "northstar_esports", "A")
	a.orders = {"14": "stall", "20": "stall", "26": "stall", "32": "stall"}
	var s = SeriesSim.play(a, _ctx(w, "iron_lotus", "B"), 1, w.champions, w.patch, SimRng.new(3))
	var g: Dictionary = s["games"][0]
	var orders = g["events"].filter(func(e): return e["type"] == "order")
	check(orders.size() >= 1, "player orders appear in the match log")
