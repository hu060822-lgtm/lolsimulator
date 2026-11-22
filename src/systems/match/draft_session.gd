## BP 流程（職業賽制：6 禁 → 6 選 → 4 禁 → 4 選）。
## 可逐步推進：玩家操作的一方由 UI 呼叫 apply()，AI 一方呼叫 ai_step()。
## 每一個 AI 決策都記錄原因（reason），供賽後分析與「影響來源追蹤」使用。
class_name DraftSession
extends RefCounted

const SEQUENCE := [
	["blue", "ban"], ["red", "ban"], ["blue", "ban"], ["red", "ban"], ["blue", "ban"], ["red", "ban"],
	["blue", "pick"], ["red", "pick"], ["red", "pick"], ["blue", "pick"], ["blue", "pick"], ["red", "pick"],
	["red", "ban"], ["blue", "ban"], ["red", "ban"], ["blue", "ban"],
	["red", "pick"], ["blue", "pick"], ["blue", "pick"], ["red", "pick"],
]

var teams: Dictionary = {}       ## side -> TeamContext
var champions: Dictionary = {}   ## id -> Champion
var patch: PatchState
var rng: SimRng
var step: int = 0
var bans: Dictionary = {"blue": [], "red": []}
var picks: Dictionary = {"blue": {}, "red": {}}  ## side -> role -> champ_id
var unavailable: Dictionary = {} ## champ_id -> true（禁用/已選/系列賽 fearless 規則）
var log: Array = []
## 系列賽中對手的「威脅英雄」加權（敗方調整用）：side -> {champ_id: bonus}
var ban_bias: Dictionary = {"blue": {}, "red": {}}


func _init(blue: TeamContext, red: TeamContext, champs: Dictionary, patch_state: PatchState, r: SimRng, excluded: Array = []) -> void:
	teams = {"blue": blue, "red": red}
	champions = champs
	patch = patch_state
	rng = r
	for c in excluded:
		unavailable[c] = true


func is_done() -> bool:
	return step >= SEQUENCE.size()


func current() -> Array:
	return SEQUENCE[step]


func other(side: String) -> String:
	return "red" if side == "blue" else "blue"


func open_roles(side: String) -> Array:
	return Attr.ROLES.filter(func(r): return not picks[side].has(r))


func apply(champ_id: String, role: String = "", reason: String = "manual") -> void:
	var side: String = SEQUENCE[step][0]
	var action: String = SEQUENCE[step][1]
	unavailable[champ_id] = true
	if action == "ban":
		bans[side].append(champ_id)
	else:
		picks[side][role] = champ_id
	log.append({"step": step, "side": side, "action": action, "champion": champ_id, "role": role, "reason": reason})
	step += 1


func run_all() -> void:
	while not is_done():
		ai_step()


func ai_step() -> void:
	var side: String = SEQUENCE[step][0]
	var action: String = SEQUENCE[step][1]
	var team: TeamContext = teams[side]
	if action == "ban":
		for fb in team.forced_bans:
			if not unavailable.has(fb):
				apply(fb, "", "forced")
				return
		var b = _best_ban(side)
		apply(b["champion"], "", b["reason"])
	else:
		var open = open_roles(side)
		for role in open:
			var fc: String = team.forced_picks.get(role, "")
			if fc != "" and not unavailable.has(fc):
				apply(fc, role, "forced")
				return
		var p = _best_pick(side)
		apply(p["champion"], p["role"], p["reason"])


func _comp_of(side: String, extra: Champion = null) -> Dictionary:
	var list: Array = picks[side].values().map(func(cid): return champions[cid])
	if extra:
		list.append(extra)
	return CompAnalyzer.analyze(list)


func _mastery(team: TeamContext, role: String, champ_id: String) -> float:
	var p: Player = team.players.get(role)
	if p == null:
		return 0.3
	var m = p.mastery(champ_id)
	return m / 100.0 if m > 0.0 else 0.25


func _best_pick(side: String) -> Dictionary:
	var team: TeamContext = teams[side]
	var enemy: TeamContext = teams[other(side)]
	var q = team.draft_quality()
	var noise_sd = 0.12 * (1.0 - q)
	var enemy_comp = _comp_of(other(side))
	var picks_made: int = picks[side].size()
	var best = {"score": -INF, "champion": "", "role": "", "reason": ""}
	for role in open_roles(side):
		var lane_opp_id: String = picks[other(side)].get(role, "")
		for c in champions.values():
			if unavailable.has(c.id) or not (role in c.roles):
				continue
			var m = _mastery(team, role, c.id)
			var meta = patch.meta(c.id) / 2.0
			var comp = _comp_of(side, c)
			var fit: float = CompAnalyzer.plan_fit(team.plan, comp) if team.plan != "flexible" else 0.5 + (comp["fit"] - 1.0) * 2.0
			var counter := 0.0
			if picks[other(side)].size() > 0:
				counter = CompAnalyzer.counter_score(comp, enemy_comp) * 2.0
			var lane := 0.0
			if lane_opp_id != "":
				lane = (c.lane - champions[lane_opp_id].lane) / 10.0
			# 越早的選擇越需要「安全」（不易被針對），越晚越重視針對與陣容契合
			var lateness = picks_made / 4.0
			var score = 0.44 * m + 0.18 * meta + (0.14 + 0.10 * lateness) * fit + (0.06 + 0.08 * lateness) * counter + 0.08 * lane
			score += rng.normal(0.0, noise_sd)
			if score > best["score"]:
				var why: Array = []
				if m >= 0.85: why.append("拿手英雄(熟練度 %d)" % int(m * 100))
				if meta >= 0.5: why.append("版本強勢")
				if counter > 0.1: why.append("剋制對手陣容")
				if lane > 0.15: why.append("對線優勢")
				if fit > 0.7: why.append("符合戰術方向")
				best = {"score": score, "champion": c.id, "role": role, "reason": "、".join(why) if why.size() > 0 else "綜合評估"}
	return best


func _best_ban(side: String) -> Dictionary:
	var team: TeamContext = teams[side]
	var enemy: TeamContext = teams[other(side)]
	var q = team.draft_quality()
	var noise_sd = 0.15 * (1.0 - q)  # 分析師對對手英雄池的認知誤差
	var my_comp = _comp_of(side)
	var enemy_open = open_roles(other(side))
	var bias: Dictionary = ban_bias[side]
	var best = {"score": -INF, "champion": "", "reason": ""}
	for c in champions.values():
		if unavailable.has(c.id):
			continue
		var threat := 0.0
		var target_role := ""
		for role in enemy_open:
			if not (role in c.roles):
				continue
			var t = _mastery(enemy, role, c.id) * 0.6 + patch.meta(c.id) / 2.0 * 0.3
			if t > threat:
				threat = t
				target_role = role
		if target_role == "":
			continue
		# 第二輪禁用：同時考慮「剋制我方陣容」的英雄
		var anti := 0.0
		if picks[side].size() > 0:
			anti = -CompAnalyzer.counter_score(my_comp, CompAnalyzer.analyze([c])) * 0.5
		var score = threat + anti + float(bias.get(c.id, 0.0)) + rng.normal(0.0, noise_sd)
		if score > best["score"]:
			var p: Player = enemy.players.get(target_role)
			var reason = "針對 %s 的拿手英雄" % (p.handle if p else target_role)
			if bias.get(c.id, 0.0) > 0.0:
				reason = "上一局對手的關鍵英雄"
			elif anti > 0.05:
				reason = "剋制我方陣容"
			best = {"score": score, "champion": c.id, "reason": reason}
	return best


func result() -> Dictionary:
	var out = {"bans": bans, "picks": picks, "log": log, "comp": {}, "plan": {}}
	for side in ["blue", "red"]:
		var comp = _comp_of(side)
		out["comp"][side] = comp
		var t: TeamContext = teams[side]
		out["plan"][side] = t.plan if t.plan != "flexible" else CompAnalyzer.best_plan(comp)
	return out
