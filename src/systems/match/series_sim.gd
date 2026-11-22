## 系列賽（Bo1/Bo3/Bo5）。負責選邊、每局 BP、以及局間的戰術調整：
## 輸掉的一方會針對上一局對手的關鍵英雄調整禁用，教練適應力高時也會改變戰術方向。
class_name SeriesSim
extends RefCounted


static func play(a: TeamContext, b: TeamContext, best_of: int, champions: Dictionary, patch: PatchState, rng: SimRng, detail: bool = true, stakes: float = 1.0) -> Dictionary:
	var need = best_of / 2 + 1
	var wins = {a.club_id: 0, b.club_id: 0}
	var games: Array = []
	var blue = a
	var red = b
	var bias = {a.club_id: {}, b.club_id: {}}
	var base_plan = {a.club_id: a.plan, b.club_id: b.plan}
	while wins[a.club_id] < need and wins[b.club_id] < need:
		var ds := DraftSession.new(blue, red, champions, patch, rng)
		ds.ban_bias = {"blue": bias[blue.club_id], "red": bias[red.club_id]}
		ds.run_all()
		var dr = ds.result()
		var eng := MatchEngine.new(blue, red, dr, champions, rng.fork(games.size()), detail, stakes)
		var res = eng.simulate()
		res["blue_club"] = blue.club_id
		res["red_club"] = red.club_id
		games.append(res)
		var w: String = res["winner_club"]
		var l: String = res["loser_club"]
		wins[w] += 1
		# 局間調整：敗方針對勝方 MVP 的英雄
		var mvp_id: String = res["mvp"]
		if mvp_id != "" and res["players"].has(mvp_id):
			var champ: String = res["players"][mvp_id]["champion"]
			bias[l][champ] = float(bias[l].get(champ, 0.0)) + 0.35
		var loser_ctx = a if l == a.club_id else b
		if rng.chance(loser_ctx.coach_stat("adaptability") / 100.0 * 0.6):
			loser_ctx.plan = "flexible"  # 放下既定方向，改為依陣容與對手調整
		# 敗方選邊（選藍方）
		if l == a.club_id:
			blue = a
			red = b
		else:
			blue = b
			red = a
	a.plan = base_plan[a.club_id]
	b.plan = base_plan[b.club_id]
	var winner = a.club_id if wins[a.club_id] > wins[b.club_id] else b.club_id
	return {"winner": winner, "loser": b.club_id if winner == a.club_id else a.club_id,
		"score": wins, "best_of": best_of, "games": games}
