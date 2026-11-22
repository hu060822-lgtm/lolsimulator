## 可逐局推進的系列賽狀態。AI 對 AI 由 SeriesSim.play 一次跑完；
## 玩家的比賽則由 UI 逐局取得 DraftSession、手動 BP，再呼叫 play_game。
class_name SeriesState
extends RefCounted

var a: TeamContext
var b: TeamContext
var best_of: int
var champions: Dictionary
var patch: PatchState
var rng: SimRng
var detail: bool
var stakes: float
var wins: Dictionary = {}
var games: Array = []
var blue: TeamContext
var red: TeamContext
var bias: Dictionary = {}
var base_plan: Dictionary = {}


func _init(team_a: TeamContext, team_b: TeamContext, bo: int, champs: Dictionary, patch_state: PatchState, r: SimRng, keep_detail: bool = true, stakes_level: float = 1.0) -> void:
	a = team_a
	b = team_b
	best_of = bo
	champions = champs
	patch = patch_state
	rng = r
	detail = keep_detail
	stakes = stakes_level
	wins = {a.club_id: 0, b.club_id: 0}
	blue = a
	red = b
	bias = {a.club_id: {}, b.club_id: {}}
	base_plan = {a.club_id: a.plan, b.club_id: b.plan}


func need() -> int:
	return best_of / 2 + 1


func is_done() -> bool:
	return wins[a.club_id] >= need() or wins[b.club_id] >= need()


func side_of(club_id: String) -> String:
	return "blue" if blue.club_id == club_id else "red"


func new_draft() -> DraftSession:
	var ds := DraftSession.new(blue, red, champions, patch, rng)
	ds.ban_bias = {"blue": bias[blue.club_id], "red": bias[red.club_id]}
	return ds


## 進行一局：若 BP 尚未完成，剩下的步驟由 AI 完成。
func play_game(ds: DraftSession) -> Dictionary:
	while not ds.is_done():
		ds.ai_step()
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
	if is_done():
		a.plan = base_plan[a.club_id]
		b.plan = base_plan[b.club_id]
	return res


func result() -> Dictionary:
	var winner = a.club_id if wins[a.club_id] > wins[b.club_id] else b.club_id
	return {"winner": winner, "loser": b.club_id if winner == a.club_id else a.club_id,
		"score": wins, "best_of": best_of, "games": games}
