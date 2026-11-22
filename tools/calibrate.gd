## 比賽引擎校準工具：大量模擬並輸出統計，用於調整 Tuning 參數。
## godot --headless --path . -s tools/calibrate.gd [-- --games=400]
extends SceneTree


func _init() -> void:
	var n := 300
	var neutral := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--games="):
			n = int(a.substr(8))
		if a == "--neutral-staff":
			neutral = true  # 診斷用：教練團能力全部設為 55，只看選手與 BP
	var m = DataModule.load_from_dir("res://data/modules/fictional_base")
	var w = WorldBuilder.build(m, 7)
	var clubs: Array = w.leagues["ecl"].club_ids.map(func(id): return w.clubs[id])
	var rng := SimRng.new(99)
	var dur := 0.0
	var kills := 0.0
	var fav_wins := 0
	var fav_games := 0
	var comebacks := 0
	var behind15 := 0
	var ca_gap_sum := 0.0
	var upset_by_gap = {"0-3": [0, 0], "3-6": [0, 0], "6+": [0, 0]}
	var dragons := 0.0
	var barons := 0.0
	for i in n:
		var a: Club = clubs[rng.range_i(0, clubs.size() - 1)]
		var b: Club = clubs[rng.range_i(0, clubs.size() - 1)]
		if a == b:
			continue
		var ta = TeamContext.from_club(w, a)
		var tb = TeamContext.from_club(w, b)
		if neutral:
			for t in [ta, tb]:
				for k in t.staff_ratings:
					t.staff_ratings[k] = 55.0
		var s = SeriesSim.play(ta, tb, 1, w.champions, w.patch, rng.fork(i), true)
		var g: Dictionary = s["games"][0]
		dur += g["duration"]
		kills += g["kills"]["blue"] + g["kills"]["red"]
		dragons += g["dragons"]["blue"] + g["dragons"]["red"]
		barons += g["barons"]["blue"] + g["barons"]["red"]
		var ca_a = _team_ca(w, a)
		var ca_b = _team_ca(w, b)
		var fav: String = a.id if ca_a >= ca_b else b.id
		var gap = absf(ca_a - ca_b)
		var bucket = "0-3" if gap < 3 else ("3-6" if gap < 6 else "6+")
		upset_by_gap[bucket][1] += 1
		if s["winner"] != fav:
			upset_by_gap[bucket][0] += 1
		fav_games += 1
		if s["winner"] == fav:
			fav_wins += 1
		# 逆轉：15 分鐘經濟落後仍獲勝
		var gd15 := 0
		for e in g["events"]:
			if e["minute"] <= 15:
				gd15 = e["gold_diff"]
		var winner_side: String = g["winner"]
		var behind = (gd15 < -1500 and winner_side == "blue") or (gd15 > 1500 and winner_side == "red")
		if absi(gd15) > 1500:
			behind15 += 1
			if behind:
				comebacks += 1
	var games := float(fav_games)
	print("games=%d avg_duration=%.1f avg_kills=%.1f dragons=%.2f barons=%.2f" % [fav_games, dur / games, kills / games, dragons / games, barons / games])
	print("favourite(by CA) win rate=%.1f%%" % (fav_wins / games * 100.0))
	for k in upset_by_gap:
		var v: Array = upset_by_gap[k]
		print("  CA gap %s: upsets %d/%d (%.1f%%)" % [k, v[0], v[1], v[0] * 100.0 / maxf(v[1], 1)])
	print("comeback rate (behind >1.5k at 15') = %.1f%% of %d" % [comebacks * 100.0 / maxf(behind15, 1), behind15])
	quit()


func _team_ca(w, c: Club) -> float:
	var vals: Array = []
	for role in c.lineup:
		vals.append(w.players[c.lineup[role]].current_ability(role))
	return MathX.mean(vals)
