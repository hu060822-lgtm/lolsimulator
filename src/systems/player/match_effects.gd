## 比賽結果對選手與俱樂部的影響：數據、士氣、自信、壓力、疲勞、比賽經驗、默契。
class_name MatchEffects
extends RefCounted


static func apply_series(w: WorldState, series: Dictionary, stakes: float) -> void:
	var played := {}
	for g in series["games"]:
		for pid in g["players"]:
			var s: Dictionary = g["players"][pid]
			var p: Player = w.players[pid]
			var won: bool = g["players"][pid]["side"] == g["winner"]
			p.season_stats["games"] += 1
			p.season_stats["wins"] += 1 if won else 0
			p.season_stats["kills"] += s["kills"]
			p.season_stats["deaths"] += s["deaths"]
			p.season_stats["assists"] += s["assists"]
			p.season_stats["rating_sum"] += s["rating"]
			p.career["games"] += 1
			p.career["wins"] += 1 if won else 0
			p.career["kills"] += s["kills"]
			p.career["deaths"] += s["deaths"]
			p.career["assists"] += s["assists"]
			p.career["rating_sum"] += s["rating"]
			# 自信：個人表現；士氣：團隊結果
			p.confidence = clampf(p.confidence + (s["rating"] - 6.0) * 1.5, 0.0, 100.0)
			p.morale = clampf(p.morale + (2.5 if won else -2.5) * stakes, 0.0, 100.0)
			p.stress = clampf(p.stress + (1.0 if won else 3.0) * stakes * (1.3 - p.trait_value("composure") / 100.0), 0.0, 100.0)
			p.fatigue = clampf(p.fatigue + 2.0, 0.0, 100.0)
			p.reputation = clampf(p.reputation + (s["rating"] - 6.5) * 0.3 * stakes, 0.0, 100.0)
			# 比賽經驗：理解型能力透過實戰成長（年輕選手最明顯）
			var youth = clampf((24.0 - p.age(w.year)) / 6.0, 0.1, 1.0)
			for sk in ["decision_making", "map_awareness", "shotcalling"]:
				p.skills[sk] = minf(p.skill(sk) + 0.06 * youth * p.development_rate, float(p.ceilings.get(sk, 99.0)))
			var champ: String = s["champion"]
			p.champion_pool[champ] = minf(p.mastery(champ) + 0.5, 100.0)
			played[pid] = true
		if g["mvp"] != "":
			w.players[g["mvp"]].reputation += 0.3
	# 出場機會：所有隊內選手都記錄「隊伍出賽」，只有上場者記錄「先發」——供選手自主行為判斷
	for cid in [series["winner"], series["loser"]]:
		var club: Club = w.clubs[cid]
		club.chemistry = clampf(club.chemistry + 0.4, 0.0, 100.0)
		for pid in club.roster:
			var p: Player = w.players[pid]
			p.season_stats["team_games"] += 1
			if played.has(pid):
				p.season_stats["starts"] += 1
