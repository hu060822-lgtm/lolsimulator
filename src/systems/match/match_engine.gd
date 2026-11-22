## 事件驅動比賽引擎（單局）。
##
## 比賽不是比較兩隊總評，而是逐分鐘推進一個可觀察的局面：
##   對線（線權、單殺、失誤）→ 打野路線（Gank、反野、反蹲）→ 物件決策（爭奪 / 放棄並交換資源）
##   → 中期營運（推塔、分推、抓單）→ 團戰（開戰、失誤、撤退判斷）→ 後期（大龍、遠古龍、終結）
## 每一個事件都由「當下局面」計算機率並記錄原因（causes）。
## 詳細規則見 docs/rules/03-match-engine.md。
class_name MatchEngine
extends RefCounted

const SIDES := ["blue", "red"]
const LANES := {"top": ["TOP"], "mid": ["MID"], "bot": ["ADC", "SUPPORT"]}
const MAX_MINUTE := 60

var blue: TeamContext
var red: TeamContext
var draft: Dictionary
var champions: Dictionary
var rng: SimRng
var detail: bool = true
var stakes: float = 1.0   ## 1 = 例行賽；季後賽/決賽更高，放大壓力影響
var tilt: Dictionary = {}  ## player_id -> 狀態下滑（系列賽中輸掉上一局的情緒影響）

var minute: int = 0
var units: Dictionary = {}        ## side -> Array[Dictionary]（依 Attr.ROLES 排序）
var comp: Dictionary = {}         ## side -> 陣容分析
var counter: Dictionary = {}      ## side -> 對對手的原型剋制值
var stance: Dictionary = {"blue": "control", "red": "control"}
var focus: Dictionary = {"blue": "", "red": ""}   ## 玩家指定的目標（物件或兵線）
var _prep: Dictionary = {"blue": 0.0, "red": 0.0}  ## 針對指定物件提前布置（視野、集結）帶來的團戰加成
var priority: Dictionary = {}     ## side -> lane -> -1..1
var vision: Dictionary = {"blue": 0.5, "red": 0.5}
var structures: Dictionary = {}   ## side -> {"top": 0..4, "mid": 0..4, "bot": 0..4, "nexus_towers": 0..2}（被摧毀數）
var siege: Dictionary = {}        ## side(進攻方) -> lane -> 累積推進值
var dragons: Dictionary = {"blue": 0, "red": 0}
var grubs: Dictionary = {"blue": 0, "red": 0}
var barons: Dictionary = {"blue": 0, "red": 0}
var baron_until: Dictionary = {"blue": -1, "red": -1}
var elder_until: Dictionary = {"blue": -1, "red": -1}
var next_dragon: int = 5
var next_baron: int = 20
var grubs_taken: bool = false
var herald_taken: bool = false
var lane_tilt: Dictionary = {}    ## side -> lane -> 暫時性對線修正（例：被 Gank 交出閃現）
var events: Array = []
var winner: String = ""
## 戰況地圖：每分鐘一格，記錄十名選手位置、擊殺／物件／推塔標記與建築狀態（只在 detail 模式）。
var frames: Array = []
var gold_curve: Array = []        ## 每分鐘的經濟差（藍 - 紅），賽後圖表用
var _where: String = ""           ## 目前事件發生的地點（lane:top、obj:dragon、jungle:blue…）
var _involved: Dictionary = {}    ## "blue0" -> 地點，本分鐘參與事件的選手
var _marks: Array = []


func _init(blue_ctx: TeamContext, red_ctx: TeamContext, draft_result: Dictionary, champs: Dictionary, r: SimRng, keep_detail: bool = true, stakes_level: float = 1.0) -> void:
	blue = blue_ctx
	red = red_ctx
	draft = draft_result
	champions = champs
	rng = r
	detail = keep_detail
	stakes = stakes_level
	tilt = blue.tilt.merged(red.tilt)


func team(side: String) -> TeamContext:
	return blue if side == "blue" else red


func other(side: String) -> String:
	return "red" if side == "blue" else "blue"


# ---------------------------------------------------------------- 主流程

func simulate() -> Dictionary:
	begin()
	return finish()


# ---------------------------------------------------------------- 逐段推進（即時戰術指揮）
## 與 simulate() 使用完全相同的隨機序列：begin → run_until(...)* → finish。

const SHOTCALL_MINUTES := [14, 20, 26, 32, 38, 44, 50, 56]


func begin() -> void:
	_setup()
	minute = 0
	gold_curve = [0]
	_record_frame()


func is_over() -> bool:
	return winner != "" or minute >= MAX_MINUTE


## 推進到指定分鐘（含）。回傳比賽是否結束。
func run_until(stop_minute: int) -> bool:
	while not is_over() and minute < mini(stop_minute, MAX_MINUTE):
		minute += 1
		_tick()
		gold_curve.append(int(_team_gold("blue") - _team_gold("red")))
		_record_frame()
	return is_over()


## 下一個戰術調整點（玩家可在這之前下達指示）；沒有則回傳 -1。
func next_shotcall() -> int:
	for m in SHOTCALL_MINUTES:
		if m > minute:
			return m
	return -1


## 給 UI 的即時局勢。
func snapshot() -> Dictionary:
	var kills := {}
	for side in SIDES:
		var k := 0
		for u in units[side]:
			k += u["kills"]
		kills[side] = k
	return {"minute": minute, "gold": {"blue": int(_team_gold("blue")), "red": int(_team_gold("red"))}, "kills": kills,
		"dragons": dragons.duplicate(), "barons": barons.duplicate(), "grubs": grubs.duplicate(),
		"towers_destroyed": {"blue": _structures_lost("red"), "red": _structures_lost("blue")},
		"stances": stance.duplicate(), "focus": focus.duplicate(), "events": events, "blue_club": blue.club_id, "red_club": red.club_id,
		"comp_late": {"blue": comp["blue"]["late"], "red": comp["red"]["late"]}, "over": is_over(),
		"frames": frames, "champs": _champ_ids(), "structures": {"blue": structures["blue"].duplicate(), "red": structures["red"].duplicate()}}


func finish() -> Dictionary:
	run_until(MAX_MINUTE)
	if winner == "":
		# 時間上限：以總經濟與塔數決勝（極少發生）
		winner = "blue" if _team_gold("blue") + _structures_lost("red") * 800 >= _team_gold("red") + _structures_lost("blue") * 800 else "red"
		_event("end", "比賽進入極限時間，%s 以運營優勢終結比賽" % team(winner).short_name, [winner], ["時間上限"])
	return _build_result()


func _setup() -> void:
	for side in SIDES:
		var t = team(side)
		var list: Array = []
		for role in Attr.ROLES:
			var p: Player = t.players.get(role)
			var cid: String = draft["picks"][side].get(role, "")
			var c: Champion = champions.get(cid)
			list.append({
				"role": role, "player": p, "champ": c,
				"mastery": (p.mastery(cid) / 100.0 if p and p.mastery(cid) > 0 else 0.25),
				"form": _day_form(p), "gold": 500.0, "kills": 0, "deaths": 0, "assists": 0,
				"dead_until": 0, "mistakes": 0, "impact": 0.0, "debuff": 0.0,
				"side": side, "idx": list.size(),
			})
		units[side] = list
		comp[side] = draft["comp"][side]
		priority[side] = {"top": 0.0, "mid": 0.0, "bot": 0.0}
		lane_tilt[side] = {"top": 0.0, "mid": 0.0, "bot": 0.0}
		structures[side] = {"top": 0, "mid": 0, "bot": 0, "nexus_towers": 0}
		siege[side] = {"top": 0.0, "mid": 0.0, "bot": 0.0}
		stance[side] = _initial_stance(side)
	for side in SIDES:
		counter[side] = CompAnalyzer.counter_score(comp[side], comp[other(side)])
	_update_vision()


## 每日狀態：穩定性越低波動越大；自信、疲勞、壓力（受抗壓性調節）皆有影響。
func _day_form(p: Player) -> float:
	if p == null:
		return -0.2
	var sd = Tuning.f("form_sd") * (1.5 - p.skill("consistency") / 100.0)
	var f = rng.normal(0.0, sd)
	f += (p.confidence - 50.0) / 100.0 * 0.06
	f += (p.morale - 50.0) / 100.0 * 0.03
	f += (p.motivation - 60.0) / 100.0 * 0.05  # 求勝慾：連霸後容易鬆懈
	f -= p.fatigue / 100.0 * 0.07
	var experience = 1.0 - minf(float(p.career.get("big_games", 0)) / 60.0, 0.5)  # 大賽經驗最多抵銷一半壓力
	f -= maxf(p.stress - 40.0, 0.0) / 100.0 * 0.08 * stakes * (1.2 - p.trait_value("composure") / 100.0) * experience
	f -= float(tilt.get(p.id, 0.0))
	return clampf(f, -0.3, 0.25)


func _tick() -> void:
	_revive()
	if minute in [14, 20, 26, 32, 38, 44, 50, 56]:
		_shotcall()
	_update_vision()
	if minute <= 14:
		_laning()
		_jungle()
	else:
		_midgame_farm()
	_objectives()
	if winner != "":
		return
	if minute >= 14:
		_macro()
	_passive_siege()


# ---------------------------------------------------------------- 個人表現

func _perf(u: Dictionary, weights: Dictionary) -> float:
	var p: Player = u["player"]
	if p == null:
		return 0.3
	var s := 0.0
	var wsum := 0.0
	for k in weights:
		s += p.skill(k) * weights[k]
		wsum += weights[k]
	var v = s / wsum / 100.0
	v *= 1.0 + u["form"]
	v *= 0.80 + 0.25 * u["mastery"]
	if minute >= 28:
		v *= 1.0 + (p.skill("clutch") - 50.0) / 100.0 * 0.06 * stakes
	return maxf(v * (1.0 - u["debuff"]), 0.05)


func _fight_perf(u: Dictionary) -> float:
	var base = _perf(u, {"teamfighting": 0.35, "positioning": 0.25, "mechanics": 0.25, "decision_making": 0.15})
	var c: Champion = u["champ"]
	var avg_gold = _avg_gold_all()
	var gold_factor = pow(maxf(u["gold"], 300.0) / maxf(avg_gold, 1.0), Tuning.f("gold_power_exponent"))
	return base * (c.power_at(minute) if c else 0.8) * gold_factor


func _side_multiplier(side: String) -> float:
	var t = team(side)
	var m: float = 1.0 + float(_prep[side])
	m *= 1.0 + Tuning.f("comp_counter_weight") * counter[side] * 3.0
	m *= 1.0 + Tuning.f("comp_fit_weight") * (comp[side]["fit"] - 1.0)
	m *= 1.0 + Tuning.f("execution_spread") * (t.execution() - 0.5)
	m *= 1.0 + 0.015 * dragons[side]
	if dragons[side] >= 4:
		m *= 1.08
	if baron_until[side] >= minute:
		m *= 1.20
	if elder_until[side] >= minute:
		m *= 1.25
	if _stance_matches_comp(side):
		m *= 1.04
	return m


func _stance_matches_comp(side: String) -> bool:
	var prim: String = comp[side]["primary"]
	var s: String = stance[side]
	return (s == "pick" and prim == "pick") or (s == "split" and prim == "split") or (s == "press" and prim in ["engage", "teamfight"]) or (s == "siege" and prim == "poke") or (s == "stall" and prim == "protect")


func _alive(side: String) -> Array:
	return units[side].filter(func(u): return u["dead_until"] <= minute)


func _revive() -> void:
	pass  # dead_until 在死亡時設定；_alive() 依分鐘判斷


# ---------------------------------------------------------------- 對線期

## 這一方在某路對線的角色（換線時前 14 分鐘上下路互換）。
func _lane_roles(side: String, lane: String) -> Array:
	if minute < 14 and team(side).lane_swap:
		if lane == "top":
			return LANES["bot"]
		if lane == "bot":
			return LANES["top"]
	return LANES[lane]


func _lane_power(side: String, lane: String) -> float:
	var total := 0.0
	for u in units[side]:
		if u["role"] in _lane_roles(side, lane):
			var c: Champion = u["champ"]
			var champ_lane = (0.8 + c.lane / 10.0 * 0.4) if c else 0.8
			total += _perf(u, {"laning": 0.5, "mechanics": 0.3, "wave_management": 0.2}) * champ_lane * (c.power_at(minute) if c else 0.8)
	if lane == "bot" and minute < 14 and team(side).lane_swap:
		total *= 1.6  # 換線後單人面對雙人：退到塔下補兵，不硬拚
	return total * (1.0 + lane_tilt[side][lane])


func _laning() -> void:
	for lane in LANES:
		_where = "lane:" + lane
		var pb = _lane_power("blue", lane)
		var pr = _lane_power("red", lane)
		var edge = clampf((pb - pr) / ((pb + pr) / 2.0) * 1.5, -1.0, 1.0)
		# 線權（EMA）
		priority["blue"][lane] = lerpf(priority["blue"][lane], edge, 0.35)
		priority["red"][lane] = -priority["blue"][lane]
		# 經濟
		for side in SIDES:
			var sgn = 1.0 if side == "blue" else -1.0
			for u in units[side]:
				if u["role"] in _lane_roles(side, lane) and u["dead_until"] <= minute:
					var g = Tuning.f("lane_gold_per_min") * (0.65 if u["role"] == "SUPPORT" else 1.0)
					u["gold"] += g + Tuning.f("lane_edge_gold") * edge * sgn
			lane_tilt[side][lane] *= 0.6
		# 對線擊殺：機率取決於優勢幅度與侵略性
		var aggr = (blue.aggression + red.aggression) / 2.0
		var p_kill = Tuning.f("lane_kill_base") + Tuning.f("lane_kill_edge") * absf(edge) + aggr * 0.01
		if rng.chance(p_kill):
			var killer_side := "blue" if rng.chance(MathX.sigmoid(edge * 3.0)) else "red"
			var victim_side = other(killer_side)
			var victim = _pick_lane_unit(victim_side, lane)
			var killer = _pick_lane_unit(killer_side, lane)
			if victim and killer and victim["dead_until"] <= minute and killer["dead_until"] <= minute:
				var causes: Array = []
				var lead_edge = edge if killer_side == "blue" else -edge
				if lead_edge > 0.2:
					causes.append("對線優勢 %+.2f" % lead_edge)
				else:
					causes.append("劣勢方逆境反殺")
				if _maybe_mistake(victim, 0.35):
					causes.append("%s 走位失誤" % _h(victim))
				_kill(killer_side, killer, victim, [], "solo_kill" if lane != "bot" else "lane_kill", "%s 的 %s 在%s路擊殺 %s" % [team(killer_side).short_name, _h(killer), _lane_name(lane), _h(victim)], causes)
	# 對線期中的偶發失誤（與局面無關的個人失誤，頻率取決於穩定性）
	for side in SIDES:
		for u in units[side]:
			if u["dead_until"] > minute or u["role"] == "JUNGLE":
				continue
			if _maybe_mistake(u, 0.12):
				var lane = _lane_of(u["role"])
				_where = "lane:" + lane
				var opp = _pick_lane_unit(other(side), lane)
				if opp and opp["dead_until"] <= minute and rng.chance(0.55):
					_kill(other(side), opp, u, [], "punished_mistake", "%s 的 %s 失誤被懲罰，%s 拿下擊殺" % [team(side).short_name, _h(u), _h(opp)], ["%s 失誤（穩定性 %d）" % [_h(u), int(u["player"].skill("consistency")) if u["player"] else 0]])
				else:
					u["gold"] -= 120
					_event("mistake", "%s 的 %s 失誤，損失兵線" % [team(side).short_name, _h(u)], [side], ["個人失誤"], [u["player"].id if u["player"] else ""])


func _pick_lane_unit(side: String, lane: String) -> Variant:
	var roles = _lane_roles(side, lane)
	var list: Array = units[side].filter(func(u): return u["role"] in roles)
	if list.is_empty():
		return null
	if list.size() == 1:
		return list[0]
	return list[0] if rng.chance(0.6) else list[1]


func _lane_of(role: String) -> String:
	for lane in LANES:
		if role in LANES[lane]:
			return lane
	return "mid"


# ---------------------------------------------------------------- 打野

func _jungle() -> void:
	if minute < 2:
		return
	var plans := {}
	for side in SIDES:
		var jg: Dictionary = units[side][1]
		jg["gold"] += 330.0 if jg["dead_until"] <= minute else 0.0
		if jg["dead_until"] > minute:
			plans[side] = "dead"
			continue
		plans[side] = _jungle_choice(side)
	for side in SIDES:
		var plan: String = plans[side]
		if plan.begins_with("gank_"):
			var lane = plan.substr(5)
			var enemy_plan: String = plans[other(side)]
			var countered: bool = enemy_plan == "gank_" + lane or (enemy_plan == "farm" and rng.chance(0.15))
			_resolve_gank(side, lane, countered)
		elif plan == "invade":
			_resolve_invade(side, plans[other(side)])


func _jungle_choice(side: String) -> String:
	var t = team(side)
	var jg: Dictionary = units[side][1]
	var c: Champion = jg["champ"]
	var gank_power = (c.early / 10.0 + c.tag("pick") * 0.1 + c.tag("burst") * 0.05) if c else 0.5
	var options: Array = []
	var weights: Array = []
	for lane in LANES:
		var target = _pick_lane_unit(other(side), lane)
		if target == null or target["dead_until"] > minute:
			continue
		var follow = 1.0 + priority[side][lane] * 0.6
		var vuln = 1.0 + (50.0 - (target["player"].skill("map_awareness") if target["player"] else 40.0)) / 100.0
		var w = gank_power * follow * vuln * (1.0 + t.aggression * 0.5)
		if t.plan == "early_aggression":
			w *= 1.5
		options.append("gank_" + lane)
		weights.append(w)
	var farm_w = 0.9 + ((c.late / 10.0) if c else 0.5)
	if t.plan == "late_scaling":
		farm_w *= 1.5
	options.append("farm")
	weights.append(farm_w)
	var invade_w = 0.15 + maxf(priority[side]["mid"], 0.0) * 0.8
	options.append("invade")
	weights.append(invade_w)
	# 決策品質：雜訊越大越可能選錯（例如去 Gank 沒有線權的路）
	var dq = _perf(jg, {"decision_making": 0.6, "map_awareness": 0.4})
	for i in weights.size():
		weights[i] = weights[i] * exp(rng.normal(0.0, 0.5 * (1.1 - dq)))
	var best := 0
	for i in weights.size():
		if weights[i] > weights[best]:
			best = i
	return options[best]


func _resolve_gank(side: String, lane: String, countered: bool) -> void:
	var jg: Dictionary = units[side][1]
	var target = _pick_lane_unit(other(side), lane)
	if target == null or target["dead_until"] > minute:
		return
	_where = "lane:" + lane
	_involve(jg)
	if countered:
		_involve(units[other(side)][1])
		# 反蹲：雙方打野同時出現，演變成 2v2 / 3v3 小規模戰鬥
		var p_side := 0.0
		var p_enemy := 0.0
		for u in units[side]:
			if u["role"] in _lane_roles(side, lane) or u["role"] == "JUNGLE":
				p_side += _fight_perf(u)
		for u in units[other(side)]:
			if u["role"] in _lane_roles(other(side), lane) or u["role"] == "JUNGLE":
				p_enemy += _fight_perf(u)
		var p_win = p_side / (p_side + p_enemy)
		var win_side = side if rng.chance(p_win) else other(side)
		var lose_side = other(win_side)
		var killer = units[win_side][1] if rng.chance(0.5) else _pick_lane_unit(win_side, lane)
		var victim = units[lose_side][1] if rng.chance(0.5) else _pick_lane_unit(lose_side, lane)
		if killer and victim and victim["dead_until"] <= minute:
			_kill(win_side, killer, victim, [], "counter_gank", "%s路爆發小規模戰鬥，%s 的 %s 擊殺 %s" % [_lane_name(lane), team(win_side).short_name, _h(killer), _h(victim)],
				["雙方打野同時出現在%s" % _lane_name(lane), "局部戰力 %.0f%%" % (p_win * 100.0 if win_side == side else (1.0 - p_win) * 100.0)])
		return
	var jg_q = _perf(jg, {"map_awareness": 0.5, "decision_making": 0.5})
	var tgt_q = _perf(target, {"map_awareness": 0.7, "positioning": 0.3})
	var p = Tuning.f("gank_base_success") + Tuning.f("gank_skill_weight") * (jg_q - tgt_q)
	p += 0.15 * priority[side][lane]
	p += Tuning.f("gank_vision_weight") * (vision[side] - vision[other(side)])
	p = clampf(p, 0.05, 0.85)
	if rng.chance(p):
		var laner = _pick_lane_unit(side, lane)
		var killer = jg if rng.chance(0.5) or laner == null else laner
		var assists: Array = [jg] if killer != jg else ([laner] if laner else [])
		var causes: Array = ["Gank 成功率 %d%%" % int(p * 100)]
		if priority[side][lane] > 0.2:
			causes.append("%s路線權讓隊友能跟上" % _lane_name(lane))
		if vision[side] > vision[other(side)] + 0.1:
			causes.append("視野優勢")
		_kill(side, killer, target, assists, "gank", "%s 打野 %s 成功 Gank %s路，擊殺 %s" % [team(side).short_name, _h(jg), _lane_name(lane), _h(target)], causes)
		lane_tilt[other(side)][lane] -= 0.12  # 交出閃現/被壓線
	else:
		lane_tilt[other(side)][lane] -= 0.04   # 交出閃現逃生
		if detail:
			_event("gank_fail", "%s 打野 %s Gank %s路失敗，%s 交閃逃生" % [team(side).short_name, _h(jg), _lane_name(lane), _h(target)], [side], ["成功率 %d%%，仍被躲過" % int(p * 100)])
		if rng.chance(0.12):
			_kill(other(side), target, jg, [], "gank_punished", "%s 反打 Gank，擊殺 %s" % [_h(target), _h(jg)], ["Gank 時機不佳"])


func _resolve_invade(side: String, enemy_plan: String) -> void:
	var jg: Dictionary = units[side][1]
	var ejg: Dictionary = units[other(side)][1]
	_where = "jungle:" + other(side)
	_involve(jg)
	var mine = _fight_perf(jg) * (1.0 + priority[side]["mid"] * 0.5)
	var theirs = _fight_perf(ejg) * (1.0 + priority[other(side)]["mid"] * 0.5)
	if enemy_plan.begins_with("gank_") or ejg["dead_until"] > minute:
		jg["gold"] += 180.0
		ejg["gold"] -= 120.0
		if detail:
			_event("invade", "%s 打野 %s 趁對手 Gank 時反野，竊取野怪資源" % [team(side).short_name, _h(jg)], [side], ["中路線權", "掌握敵方打野位置"])
		return
	if rng.chance(mine / (mine + theirs) * 0.6):
		_kill(side, jg, ejg, [], "invade_kill", "%s 打野 %s 反野成功，擊殺 %s" % [team(side).short_name, _h(jg), _h(ejg)], ["打野戰力優勢", "中路線權支援"])
	elif rng.chance(0.3):
		_kill(other(side), ejg, jg, [], "invade_punished", "%s 反野被抓，%s 擊殺 %s" % [team(side).short_name, _h(ejg), _h(jg)], ["反野時機錯誤"])


# ---------------------------------------------------------------- 中期經濟

func _midgame_farm() -> void:
	for side in SIDES:
		for u in units[side]:
			if u["dead_until"] > minute:
				continue
			var g = 420.0 if u["role"] != "SUPPORT" else 260.0
			var lane = _lane_of(u["role"])
			g *= 1.0 + priority[side].get(lane, 0.0) * 0.12
			if stance[side] == "stall":
				g *= 1.06
			u["gold"] += g


# ---------------------------------------------------------------- 物件與資源交換

func _objectives() -> void:
	if minute == 6 and not grubs_taken:
		_contest("grubs", ["top", "mid"])
	if minute == 14 and not herald_taken:
		_contest("herald", ["top", "mid"])
	if minute >= next_dragon and minute < 60:
		var elder = dragons["blue"] >= 4 or dragons["red"] >= 4
		_contest("elder" if elder else "dragon", ["bot", "mid"])
	if minute >= next_baron:
		_contest("baron", ["top", "mid"])


func _contest(obj: String, near_lanes: Array) -> void:
	_where = "obj:" + obj
	var want := {}
	var pb = _team_power("blue")
	var pr = _team_power("red")
	for side in SIDES:
		var mine = pb if side == "blue" else pr
		var theirs = pr if side == "blue" else pb
		var true_adv = log(maxf(mine, 0.01) / maxf(theirs, 0.01))
		var local := 0.0
		for lane in near_lanes:
			local += priority[side][lane]
		true_adv += 0.12 * local + 0.1 * (vision[side] - vision[other(side)])
		true_adv += 0.25 * (_alive(side).size() - _alive(other(side)).size())
		var q = team(side).shotcall_quality()
		var perceived = true_adv + rng.normal(0.0, 0.30 * (1.1 - q))
		var bias := 0.0
		match stance[side]:
			"press": bias = 0.12
			"control": bias = 0.15
			"stall": bias = -0.20
			"split": bias = -0.05
		if obj == "baron":
			bias -= 0.30
		if obj == "elder" or (obj == "dragon" and dragons[other(side)] == 3):
			bias += 0.25  # 必須阻止對手拿下龍魂/遠古龍
		if _focus_obj(side, obj):
			bias += 0.35         # 教練指定：提早布視野、集結
		want[side] = perceived + bias + team(side).aggression * 0.1 - 0.05
	var bc: bool = want["blue"] > 0.0
	var rc: bool = want["red"] > 0.0
	if bc and rc:
		for side in SIDES:
			_prep[side] = 0.2 if _focus_obj(side, obj) else 0.0
		var fight = _teamfight(_obj_name(obj), "blue" if want["blue"] > want["red"] else "red")
		_prep = {"blue": 0.0, "red": 0.0}
		var taker: String = fight["winner"]
		# 搶龍：輸掉團戰的一方打野仍可能以懲戒搶下
		if fight["margin"] <= 1 and _alive(other(taker)).any(func(u): return u["role"] == "JUNGLE"):
			var mj: Dictionary = units[taker][1]
			var ej: Dictionary = units[other(taker)][1]
			var steal = 0.06 + (_perf(ej, {"mechanics": 1.0}) - _perf(mj, {"mechanics": 1.0})) * 0.4
			if rng.chance(clampf(steal, 0.01, 0.25)):
				_event("steal", "%s 打野 %s 懲戒搶下%s！" % [team(other(taker)).short_name, _h(ej), _obj_name(obj)], [other(taker)], ["打野操作（懲戒）"], [ej["player"].id if ej["player"] else ""])
				taker = other(taker)
		_award_objective(taker, obj, ["團戰勝利"])
		if fight["margin"] >= 3 and minute >= 20:
			_push(taker, fight["margin"] - 1, "團戰大勝後推進")
	elif bc or rc:
		var taker := "blue" if bc else "red"
		var trader = other(taker)
		_award_objective(taker, obj, ["對手判斷無法爭奪"])
		_trade(trader, obj, near_lanes)
	else:
		var taker := "blue"
		var lb := 0.0
		for lane in near_lanes:
			lb += priority["blue"][lane]
		taker = "blue" if lb >= 0.0 else "red"
		_award_objective(taker, obj, ["線權控制"])
	_schedule_next(obj)


## 資源交換：放棄物件的一方在地圖另一側換取資源（塔、鍍層、野區）。
func _trade(side: String, given_up: String, near_lanes: Array) -> void:
	var far := "top" if "bot" in near_lanes else "bot"
	_where = "lane:" + far
	for u in _alive(side):
		_involve(u)
	if minute >= 14:
		siege[side][far] += 0.8
		if detail:
			_event("trade", "%s 放棄%s，轉而向%s路施壓" % [team(side).short_name, _obj_name(given_up), _lane_name(far)], [side], ["資源交換"])
		_try_destroy(side, far, "以%s交換%s路推進" % [_obj_name(given_up), _lane_name(far)])
	else:
		for u in units[side]:
			u["gold"] += 120.0
		siege[side][far] += 0.5
		if detail:
			_event("trade", "%s 放棄%s，轉而在%s路取得鍍層與野區資源" % [team(side).short_name, _obj_name(given_up), _lane_name(far)], [side], ["資源交換"])


func _award_objective(side: String, obj: String, causes: Array) -> void:
	if detail:
		for u in _alive(side):
			_involve(u, "obj:" + obj)
		_marks.append({"t": obj, "side": side, "p": _loc_point("obj:" + obj)})
	match obj:
		"dragon":
			dragons[side] += 1
			for u in units[side]:
				u["gold"] += 40.0
			var txt = "%s 拿下第 %d 條小龍" % [team(side).short_name, dragons[side]]
			if dragons[side] == 4:
				txt += "，取得龍魂"
			_event("dragon", txt, [side], causes)
		"elder":
			elder_until[side] = minute + 3
			_event("elder", "%s 拿下遠古龍！" % team(side).short_name, [side], causes)
		"grubs":
			grubs_taken = true
			grubs[side] += 3
			siege[side]["top"] += 0.4
			_event("grubs", "%s 拿下虛空幼蟲" % team(side).short_name, [side], causes)
		"herald":
			herald_taken = true
			siege[side]["mid"] += 0.9
			_event("herald", "%s 拿下預示者，準備衝塔" % team(side).short_name, [side], causes)
		"baron":
			barons[side] += 1
			baron_until[side] = minute + 3
			for u in units[side]:
				u["gold"] += 300.0
			_event("baron", "%s 拿下巴龍！" % team(side).short_name, [side], causes)


func _schedule_next(obj: String) -> void:
	if obj == "dragon" or obj == "elder":
		next_dragon = minute + 6
	elif obj == "baron":
		next_baron = minute + 7


# ---------------------------------------------------------------- 中後期決策

## 戰術調整（指揮 + 教練）：依經濟差、陣容時間曲線與原型選擇姿態。
func _shotcall() -> void:
	for side in SIDES:
		var t = team(side)
		var old: String = stance[side]
		if t.focus.has(str(minute)) and str(t.focus[str(minute)]) != focus[side]:
			focus[side] = str(t.focus[str(minute)])
			if focus[side] != "":
				_event("order", "%s 教練指定目標：%s" % [t.short_name, focus_name(focus[side])], [side], ["玩家即時戰術指令"])
		if t.orders.has(str(minute)):
			stance[side] = t.orders[str(minute)]
			_event("order", "%s 教練下達指示：%s" % [t.short_name, _stance_name(stance[side])], [side], ["玩家即時戰術指令"])
			continue
		var gd = (_team_gold(side) - _team_gold(other(side))) / maxf(_team_gold(side) + _team_gold(other(side)), 1.0) * 2.0
		var scale_diff: float = (comp[side]["late"] - comp[other(side)]["late"]) / 3.0
		var share: Dictionary = comp[side]["share"]
		var utility = {
			"press": gd * 4.0 - scale_diff * 0.6 + share["engage"] + share["teamfight"] * 0.5,
			"stall": -gd * 3.0 + scale_diff * 1.2 + share["protect"] * 0.5,
			"control": 0.35 + share["teamfight"] * 0.3,
			"split": share["split"] * 2.4 - 0.1,
			"pick": share["pick"] * 2.0 + (vision[side] - vision[other(side)]),
			"siege": share["poke"] * 2.0 + gd,
		}
		var adapt = (t.coach_stat("adaptability") / 100.0 * 0.5 + t.shotcall_quality() * 0.5)
		var best := ""
		var best_v := -INF
		for k in utility:
			var v: float = utility[k] + rng.normal(0.0, 0.45 * (1.1 - adapt))
			if k == old:
				v += 0.1 * (1.0 - adapt)  # 適應力低的隊伍傾向維持原本打法
			if v > best_v:
				best_v = v
				best = k
		stance[side] = best
		if best != old and detail:
			var why: Array = []
			if gd < -0.1 and scale_diff > 0:
				why.append("經濟落後但陣容後期較強")
			elif gd > 0.1:
				why.append("經濟領先 %.0f%%" % (gd * 50.0))
			if share["split"] > 0.25 and best == "split":
				why.append("陣容具備分推能力")
			if best == "pick":
				why.append("陣容擅長抓單")
			_event("adapt", "%s 調整戰術：%s → %s" % [t.short_name, _stance_name(old), _stance_name(best)], [side], why if why.size() > 0 else ["指揮判斷"])


func _macro() -> void:
	# 1) 分推
	for side in SIDES:
		if stance[side] == "split":
			_split_push(side)
			if winner != "":
				return
	# 2) 抓單
	for side in SIDES:
		var c: Dictionary = comp[side]
		var p = 0.022 + c["tags"]["pick"] * 0.005 + (vision[side] - vision[other(side)]) * 0.12
		if stance[side] == "pick":
			p += 0.05
		if rng.chance(clampf(p, 0.01, 0.2)):
			var victims = _alive(other(side))
			if victims.is_empty():
				continue
			var weights = victims.map(func(u): return (1.3 - (u["player"].skill("positioning") if u["player"] else 40.0) / 100.0) * (1.3 - (u["player"].skill("map_awareness") if u["player"] else 40.0) / 100.0))
			var victim: Dictionary = victims[rng.weighted_index(weights)]
			var killers = _alive(side)
			if killers.is_empty():
				continue
			var killer: Dictionary = rng.pick(killers)
			_where = "jungle:" + other(side)
			var causes: Array = ["%s 站位/地圖意識不足" % _h(victim)]
			if vision[side] > vision[other(side)] + 0.1:
				causes.append("視野控制優勢")
			_kill(side, killer, victim, [], "pick", "%s 抓到落單的 %s" % [team(side).short_name, _h(victim)], causes)
			if winner != "":
				return
	# 3) 主動開團
	var fight_p = 0.06 + 0.006 * (minute - 15)
	var initiator := ""
	var best_will := -INF
	for side in SIDES:
		var will := 0.0
		match stance[side]:
			"press": will = 0.12
			"siege": will = 0.05
			"stall": will = -0.10
			"split": will = -0.03
		will += log(maxf(_team_power(side), 0.01) / maxf(_team_power(other(side)), 0.01))
		if will > best_will:
			best_will = will
			initiator = side
	fight_p += maxf(best_will, -0.08)
	# 對手拖後期時，需要開戰能力才能強迫開團
	if stance[other(initiator)] == "stall":
		fight_p *= clampf(0.5 + (comp[initiator]["tags"]["engage"] - comp[other(initiator)]["tags"]["disengage"]) * 0.08, 0.2, 1.2)
	if minute >= 45:
		fight_p += 0.3
	if rng.chance(clampf(fight_p, 0.02, 0.9)):
		_where = "lane:mid"
		var f = _teamfight("中路/野區", initiator)
		if f["margin"] >= 2:
			var w: String = f["winner"]
			if minute >= next_baron - 0 and minute >= 20 and f["margin"] >= 3 and baron_until[w] < minute:
				_award_objective(w, "baron", ["團戰勝利後轉巴龍"])
				next_baron = minute + 7
			_push(w, f["margin"] - 1 + (1 if baron_until[w] >= minute else 0), "團戰勝利後推進")


func _split_push(side: String) -> void:
	var splitter: Dictionary = units[side][0]
	var best_i := 0
	for i in units[side].size():
		var c: Champion = units[side][i]["champ"]
		if c and c.tag("splitpush") > (units[side][best_i]["champ"].tag("splitpush") if units[side][best_i]["champ"] else 0.0):
			best_i = i
	splitter = units[side][best_i]
	if splitter["dead_until"] > minute:
		return
	var lane := "top" if best_i <= 1 else "bot"
	if focus[side] in ["top", "bot"]:
		lane = focus[side]
	_where = "lane:" + lane
	_involve(splitter)
	var enemy = other(side)
	var q = team(enemy).shotcall_quality()
	# 對手回應：派人守邊 / 以多打少強開 / 無視
	var defenders = _alive(enemy)
	if defenders.is_empty():
		return
	var best_def: Dictionary = defenders[0]
	for d in defenders:
		if _fight_perf(d) > _fight_perf(best_def):
			best_def = d
	var duel_p = _perf(splitter, {"mechanics": 0.6, "laning": 0.4}) * (1.0 + splitter["champ"].tag("splitpush") * 0.12) * pow(splitter["gold"] / maxf(_avg_gold_all(), 1.0), 0.4)
	var def_p = _perf(best_def, {"mechanics": 0.6, "laning": 0.4}) * pow(best_def["gold"] / maxf(_avg_gold_all(), 1.0), 0.4)
	var respond_correctly = rng.chance(0.35 + q * 0.5)
	if respond_correctly and def_p >= duel_p * 0.9:
		# 派出單挑能力足夠的選手守邊
		if rng.chance(def_p / (def_p + duel_p) * 0.5):
			_kill(enemy, best_def, splitter, [], "split_caught", "%s 守邊成功，擊殺分推的 %s" % [_h(best_def), _h(splitter)], ["%s 判斷正確，派出單挑能力足夠的選手" % team(enemy).short_name])
		else:
			siege[side][lane] += 0.25
	elif respond_correctly:
		# 單挑打不贏 → 以多打少強開
		_event("force_4v5", "%s 趁 %s 分推時在中路以五打四開戰" % [team(enemy).short_name, _h(splitter)], [enemy], ["%s 守邊單挑不利，選擇以多打少" % team(enemy).short_name])
		splitter["dead_until"] = minute + 1  # 暫時不在團戰中（並非死亡）
		_where = "lane:mid"
		var f = _teamfight("中路", enemy)
		splitter["dead_until"] = 0
		_where = "lane:" + lane
		siege[side][lane] += 0.6
		if f["winner"] == enemy and f["margin"] >= 2:
			_push(enemy, f["margin"] - 1, "以多打少獲勝")
	else:
		siege[side][lane] += 0.9
		if detail:
			_event("split", "%s 的 %s 在%s路分推，對手回應太慢" % [team(side).short_name, _h(splitter), _lane_name(lane)], [side], ["%s 判斷失誤" % team(enemy).short_name])


func _passive_siege() -> void:
	if minute < 12:
		return
	for side in SIDES:
		for lane in LANES:
			var pr: float = priority[side][lane] if minute <= 20 else priority[side][lane] * 0.5
			var pressure = maxf(pr, 0.0) * 0.12 + comp[side]["tags"]["siege"] * 0.008
			if stance[side] == "siege":
				pressure += 0.12
			if focus[side] == lane:
				pressure += 0.10  # 指定推進的兵線
			elif focus[side] in LANES:
				pressure -= 0.02
			if baron_until[side] >= minute:
				pressure += 0.45
			if structures[other(side)][lane] >= 4:
				pressure += 0.10  # 超級兵
			pressure -= comp[other(side)]["tags"]["waveclear"] * 0.012
			if stance[other(side)] == "stall":
				pressure -= 0.08
			siege[side][lane] += maxf(pressure, 0.0)
			_try_destroy(side, lane, "持續推進壓力")
			if winner != "":
				return


# ---------------------------------------------------------------- 團戰

## 團戰：開戰 → 失誤 → 逐回合擊殺 → 劣勢方決定是否撤退。
## 回傳 {"winner", "margin"(存活人數差), "kills": {side: n}}
func _teamfight(where: String, initiator: String) -> Dictionary:
	var causes: Array = []
	var participants := {}
	for side in SIDES:
		participants[side] = _alive(side)
		for u in participants[side]:
			_involve(u)
	# 一方無人可戰（全員陣亡或回城）：不構成團戰
	if participants["blue"].is_empty() or participants["red"].is_empty():
		var only = "blue" if participants["red"].is_empty() else "red"
		return {"winner": only, "margin": participants[only].size(), "kills": {"blue": 0, "red": 0}}
	var mult = {"blue": _side_multiplier("blue"), "red": _side_multiplier("red")}
	var pb_final = _sum_power(participants["blue"]) * mult["blue"]
	var pr_final = _sum_power(participants["red"]) * mult["red"]
	# 1) 賽前失誤：被抓、技能空放
	var kills = {"blue": 0, "red": 0}
	for side in SIDES:
		for u in participants[side].duplicate():
			var late_mult := 1.0
			if minute >= 28 and u["player"]:
				late_mult = 1.3 - u["player"].skill("clutch") / 100.0 * 0.6
			if _maybe_mistake(u, late_mult):
				if rng.chance(0.55) and participants[other(side)].size() > 0:
					var killer: Dictionary = rng.pick(participants[other(side)])
					_kill(other(side), killer, u, [], "caught", "", [])
					participants[side].erase(u)
					kills[other(side)] += 1
					causes.append("%s 開戰前被抓" % _h(u))
				else:
					u["debuff"] = 0.5
					causes.append("%s 關鍵技能空放" % _h(u))
	# 2) 開戰：開戰方以 engage 標籤嘗試先手
	var init_c: Dictionary = comp[initiator]["tags"]
	var def_c: Dictionary = comp[other(initiator)]["tags"]
	var engage_p = 0.45 + (init_c["engage"] + init_c["pick"] * 0.5 - def_c["disengage"] - def_c["peel"] * 0.5) * 0.05
	if rng.chance(clampf(engage_p, 0.1, 0.85)) and participants[other(initiator)].size() > 0:
		var target: Dictionary = _weakest_positioned(participants[other(initiator)])
		target["debuff"] = maxf(target["debuff"], 0.6)
		causes.append("%s 先手開到 %s" % [team(initiator).short_name, _h(target)])
	elif participants[other(initiator)].size() > 0:
		causes.append("%s 開戰失敗被反打" % team(initiator).short_name)
		if participants[initiator].size() > 0:  # 開戰方可能在開戰前全員被抓
			var tgt: Dictionary = _weakest_positioned(participants[initiator])
			tgt["debuff"] = maxf(tgt["debuff"], 0.3)
	# 3) 逐回合
	var k = Tuning.f("fight_decisiveness")
	var rounds := 0
	var disengaged := ""
	while participants["blue"].size() > 0 and participants["red"].size() > 0 and rounds < 10:
		rounds += 1
		var pb = _sum_power(participants["blue"]) * mult["blue"]
		var pr = _sum_power(participants["red"]) * mult["red"]
		var p_blue = pow(pb, k) / (pow(pb, k) + pow(pr, k))
		var scorer := "blue" if rng.chance(p_blue) else "red"
		var loser = other(scorer)
		var victim = _weakest_positioned(participants[loser])
		var killer: Dictionary = _strongest(participants[scorer])
		var assists: Array = participants[scorer].filter(func(u): return u != killer)
		assists = assists.slice(0, rng.range_i(1, 3))
		_kill(scorer, killer, victim, assists, "teamfight_kill", "", [])
		participants[loser].erase(victim)
		kills[scorer] += 1
		# 撤退判斷：劣勢方的決策品質與反開能力決定能否止損
		var behind = participants[loser].size() < participants[scorer].size()
		if behind and participants[loser].size() > 0:
			var lt = team(loser)
			var p_dis = Tuning.f("disengage_base") * lt.shotcall_quality() * 1.6 + comp[loser]["tags"]["disengage"] * 0.03
			if rng.chance(clampf(p_dis, 0.05, 0.7)):
				disengaged = loser
				break
	for side in SIDES:
		for u in units[side]:
			u["debuff"] = 0.0
	var alive_b = participants["blue"].size()
	var alive_r = participants["red"].size()
	var win = "blue" if alive_b > alive_r else ("red" if alive_r > alive_b else ("blue" if kills["blue"] >= kills["red"] else "red"))
	var margin = absi(alive_b - alive_r)
	if counter[win] > 0.04:
		causes.append("陣容原型剋制（%s 對 %s）" % [_arch_name(comp[win]["primary"]), _arch_name(comp[other(win)]["primary"])])
	if team(win).execution() > team(other(win)).execution() + 0.08:
		causes.append("團隊執行力較佳")
	var gd = _team_gold(win) - _team_gold(other(win))
	if gd > 2500:
		causes.append("經濟領先 %.1fk" % (gd / 1000.0))
	elif gd < -2500:
		causes.append("經濟落後 %.1fk 仍打贏" % (-gd / 1000.0))
	var share_w = (pb_final if win == "blue" else pr_final) / (pb_final + pr_final)
	causes.append("開戰前戰力 %d%% : %d%%" % [int(share_w * 100.0), 100 - int(share_w * 100.0)])
	if disengaged != "":
		causes.append("%s 及時撤退止損" % team(disengaged).short_name)
	var text = "%s團戰：%s %d 換 %d 獲勝" % [where, team(win).short_name, kills[win], kills[other(win)]]
	if kills["blue"] + kills["red"] == 0:
		text = "%s對峙：雙方互有試探，%s 取得位置優勢" % [where, team(win).short_name]
		margin = 0
	_event("teamfight", text, [win], causes, [], {"kills": kills.duplicate(), "margin": margin})
	return {"winner": win, "margin": margin, "kills": kills}


func _sum_power(list: Array) -> float:
	var s := 0.0
	for u in list:
		s += _fight_perf(u)
	return maxf(s, 0.01)


func _team_power(side: String) -> float:
	return _sum_power(_alive(side)) * _side_multiplier(side)


func _weakest_positioned(list: Array) -> Dictionary:
	if list.is_empty():
		return {"debuff": 0.0}
	var weights = list.map(func(u): return (1.25 - (u["player"].skill("positioning") if u["player"] else 40.0) / 100.0) * (1.4 if u["role"] in ["ADC", "MID"] else 1.0) * (1.0 + u["debuff"]))
	return list[rng.weighted_index(weights)]


func _strongest(list: Array) -> Dictionary:
	var weights = list.map(func(u): return _fight_perf(u))
	return list[rng.weighted_index(weights)]


# ---------------------------------------------------------------- 結構與終局

## 推進：把優勢轉成推進值，建築仍受「血量」與時間限制，不會一波直接推完。
func _push(side: String, count: int, reason: String) -> void:
	if count <= 0:
		return
	var lane = "mid"
	var best = -1
	for l in LANES:
		var lost: int = structures[other(side)][l]
		if lost < 4 and lost > best:
			best = lost
			lane = l
	if focus[side] in LANES and structures[other(side)][focus[side]] < 4:
		lane = focus[side]
	siege[side][lane] += 0.7 * count
	_try_destroy(side, lane, reason)


func _try_destroy(side: String, lane: String, reason: String) -> void:
	var guard = 0
	while winner == "" and guard < 3:
		guard += 1
		var need = _structure_health(other(side), lane, side)
		if siege[side][lane] < need:
			return
		siege[side][lane] -= need
		_destroy_structure(side, lane, reason)


func _destroy_structure(side: String, lane: String, reason: String) -> void:
	if winner != "":
		return
	var enemy = other(side)
	var s: Dictionary = structures[enemy]
	var any_inhib = s["top"] >= 4 or s["mid"] >= 4 or s["bot"] >= 4
	if s[lane] < 4:
		s[lane] += 1
		if detail:
			_marks.append({"t": "tower", "side": side, "p": RiftGeometry.tower_point(enemy, lane, s[lane] - 1)})
			for u in _alive(side):
				if not _involved.has(side + str(u["idx"])) or not _involved[side + str(u["idx"])].begins_with("tower:"):
					_involve(u, "tower:%s:%s:%d" % [enemy, lane, s[lane] - 1])
		for u in units[side]:
			u["gold"] += 60.0
		var names = ["一塔", "二塔", "高地塔", "兵營"]
		if detail:
			_event("structure", "%s 摧毀 %s %s路%s" % [team(side).short_name, team(enemy).short_name, _lane_name(lane), names[s[lane] - 1]], [side], [reason])
	elif any_inhib:
		if s["nexus_towers"] < 2:
			s["nexus_towers"] += 1
			if detail:
				_marks.append({"t": "tower", "side": side, "p": RiftGeometry.NEXUS_TOWERS[enemy][s["nexus_towers"] - 1]})
			if detail:
				_event("structure", "%s 摧毀主堡塔" % team(side).short_name, [side], [reason])
		else:
			winner = side
			if detail:
				_marks.append({"t": "nexus", "side": side, "p": RiftGeometry.NEXUS[enemy]})
				for u in _alive(side):
					_involve(u, "nexus:" + enemy)
			_event("end", "%s 摧毀主堡，贏得比賽！（%d 分鐘）" % [team(side).short_name, minute], [side], [reason])


## 下一座建築需要的推進值：外塔 1、二塔 1.6、高地塔 2.2、兵營 1.4；
## 時間未到時（鍍層保護、二塔/高地防守優勢）需要更多推進。
func _structure_health(defender: String, lane: String, attacker: String) -> float:
	var lost: int = structures[defender][lane]
	var hp = [1.3, 2.0, 2.6, 1.6, 1.3][mini(lost, 4)]
	if lost == 0 and minute < 14:
		hp *= 1.6
	if lost == 1 and minute < 20:
		hp *= 1.4
	if lost >= 2 and minute < 24 and baron_until[attacker] < minute:
		hp *= 1.5
	return hp


func _structures_lost(side: String) -> int:
	var s: Dictionary = structures[side]
	return s["top"] + s["mid"] + s["bot"] + s["nexus_towers"]


# ---------------------------------------------------------------- 輔助

func _kill(side: String, killer: Dictionary, victim: Dictionary, assists: Array, kind: String, text: String, causes: Array) -> void:
	var bounty := 300.0
	var streak: int = victim["kills"] - victim["deaths"]
	if streak >= 3:
		bounty += 100.0 * mini(streak - 2, 5)  # 終結賞金：落後方追分機制
	killer["kills"] += 1
	killer["gold"] += bounty
	killer["impact"] += 1.0
	victim["deaths"] += 1
	victim["impact"] -= 0.7
	var respawn = 0 if minute < 18 else (1 if minute < 32 else 2)
	victim["dead_until"] = minute + respawn + 1 if respawn > 0 else minute + 1
	if detail:
		_involve(killer)
		_involve(victim)
		for a in assists:
			_involve(a)
		var vc: Champion = victim.get("champ")
		_marks.append({"t": "kill", "side": side, "p": _loc_point(_where if _where != "" else "lane:mid") + RiftGeometry.spread(int(victim.get("idx", 0)), 5, 0.015),
			"victim": vc.id if vc else ""})
	for a in assists:
		if a != killer:
			a["assists"] += 1
			a["gold"] += 120.0
			a["impact"] += 0.4
	if text != "" and (detail or kind in ["solo_kill", "gank"]):
		_event(kind, text, [side], causes, [killer["player"].id if killer["player"] else "", victim["player"].id if victim["player"] else ""])


## 失誤判定：穩定性越低、壓力與疲勞越高越容易失誤。
func _maybe_mistake(u: Dictionary, scale: float) -> bool:
	var p: Player = u["player"]
	if p == null:
		return rng.chance(0.1 * scale)
	var chance = Tuning.f("mistake_base") * scale
	chance *= 1.6 - p.skill("consistency") / 100.0
	chance *= 1.0 + p.stress / 120.0 * stakes
	chance *= 1.0 + p.fatigue / 150.0
	chance *= 1.0 - u["form"]
	if rng.chance(chance):
		u["mistakes"] += 1
		u["impact"] -= 0.5
		return true
	return false


func _update_vision() -> void:
	for side in SIDES:
		var v := 0.0
		for u in units[side]:
			var w = 2.0 if u["role"] == "SUPPORT" else (1.4 if u["role"] == "JUNGLE" else 0.8)
			v += _perf(u, {"vision": 0.7, "map_awareness": 0.3}) * w
		v /= 6.8
		if stance[side] == "control" or stance[side] == "pick":
			v += 0.05
		vision[side] = clampf(v, 0.0, 1.0)


func _initial_stance(side: String) -> String:
	var plan: String = draft["plan"][side]
	match plan:
		"early_aggression": return "press"
		"split_push": return "split"
		"pick": return "pick"
		"poke_siege": return "siege"
		"late_scaling", "protect": return "stall"
	return "control"


func _team_gold(side: String) -> float:
	var g := 0.0
	for u in units[side]:
		g += u["gold"]
	return g


func _avg_gold_all() -> float:
	return (_team_gold("blue") + _team_gold("red")) / 10.0


func _event(type: String, text: String, sides: Array, causes: Array, actors: Array = [], data: Dictionary = {}) -> void:
	if not detail and not (type in ["end", "baron", "elder", "teamfight"]):
		return
	var e = {"minute": minute, "type": type, "text": text, "sides": sides, "causes": causes, "actors": actors,
		"gold_diff": int(_team_gold("blue") - _team_gold("red"))}
	if not data.is_empty():
		e["data"] = data
	events.append(e)


func _h(u: Dictionary) -> String:
	var p: Player = u["player"]
	var c: Champion = u["champ"]
	return "%s(%s)" % [p.handle if p else "?", c.name if c else "?"]


func _lane_name(lane: String) -> String:
	return {"top": "上", "mid": "中", "bot": "下"}.get(lane, lane)


func _obj_name(obj: String) -> String:
	return {"dragon": "小龍", "elder": "遠古龍", "grubs": "虛空幼蟲", "herald": "預示者", "baron": "巴龍"}.get(obj, obj)


func _focus_obj(side: String, obj: String) -> bool:
	return focus[side] == obj or (focus[side] == "dragon" and obj == "elder")


static func focus_name(f: String) -> String:
	return {"dragon": "小龍", "baron": "巴龍", "top": "上路推進", "mid": "中路推進", "bot": "下路推進"}.get(f, f)


func _stance_name(s: String) -> String:
	return {"press": "主動進攻", "stall": "拖後期", "control": "物件控制", "split": "分推", "pick": "抓單", "siege": "消耗圍塔"}.get(s, s)


func _arch_name(a: String) -> String:
	return {"engage": "開戰", "pick": "抓單", "poke": "消耗", "protect": "保護後排", "split": "分推", "teamfight": "團戰"}.get(a, a)


## 對英雄傷害（估算）：經濟、參與擊殺與英雄類型決定，射手法師高、坦克輔助低。
const DAMAGE_CLASS := {"marksman": 1.3, "mage": 1.25, "assassin": 1.15, "fighter": 1.0, "tank": 0.6, "enchanter": 0.45}

func _damage_estimate(u: Dictionary) -> int:
	var cls: String = u["champ"].class_type if u["champ"] else "fighter"
	var base: float = u["gold"] * 0.95 + u["kills"] * 900.0 + u["assists"] * 380.0
	return int(base * DAMAGE_CLASS.get(cls, 1.0) * (0.92 + float(absi(hash(str(u["idx"]) + cls + str(minute))) % 17) / 100.0))


func _build_result() -> Dictionary:
	var stats := {}
	for side in SIDES:
		var team_gold = _team_gold(side)
		for u in units[side]:
			var p: Player = u["player"]
			if p == null:
				continue
			var share: float = u["gold"] / maxf(team_gold, 1.0)
			var rating = 6.0 + u["kills"] * 0.45 + u["assists"] * 0.2 - u["deaths"] * 0.45 + (share - 0.2) * 8.0 - u["mistakes"] * 0.4
			rating += 0.6 if side == winner else -0.3
			stats[p.id] = {"side": side, "role": u["role"], "champion": u["champ"].id if u["champ"] else "",
				"kills": u["kills"], "deaths": u["deaths"], "assists": u["assists"], "gold": int(u["gold"]),
				"mistakes": u["mistakes"], "rating": clampf(rating, 1.0, 10.0), "damage": _damage_estimate(u)}
	var mvp := ""
	var best := -1.0
	for pid in stats:
		if stats[pid]["side"] == winner and stats[pid]["rating"] > best:
			best = stats[pid]["rating"]
			mvp = pid
	var kills := {}
	for side in SIDES:
		var k := 0
		for u in units[side]:
			k += u["kills"]
		kills[side] = k
	return {
		"winner": winner, "winner_club": team(winner).club_id, "loser_club": team(other(winner)).club_id,
		"duration": minute, "kills": kills,
		"gold": {"blue": int(_team_gold("blue")), "red": int(_team_gold("red"))},
		"dragons": dragons.duplicate(), "barons": barons.duplicate(),
		"towers_destroyed": {"blue": _structures_lost("red"), "red": _structures_lost("blue")},
		"stances": stance.duplicate(), "events": events, "players": stats, "mvp": mvp,
		"frames": frames, "champs": _champ_ids(), "gold_curve": gold_curve,
		"draft": {"bans": draft["bans"], "picks": draft["picks"], "log": draft["log"] if detail else [], "plan": draft["plan"],
			"primary": {"blue": comp["blue"]["primary"], "red": comp["red"]["primary"]}},
	}


# ---------------------------------------------------------------- 戰況地圖（不使用亂數，不影響比賽結果）

func _champ_ids() -> Dictionary:
	var out := {}
	for side in SIDES:
		out[side] = units[side].map(func(u): return u["champ"].id if u["champ"] else "")
	return out


func _involve(u: Dictionary, loc: String = "") -> void:
	if not detail or not u.has("side"):
		return
	var l = loc if loc != "" else _where
	if l != "":
		_involved[u["side"] + str(u["idx"])] = l


func _front(lane: String) -> float:
	var pr: float = priority["blue"].get(lane, 0.0)
	return RiftGeometry.lane_front(lane, pr, structures["blue"][lane], structures["red"][lane])


func _loc_point(loc: String) -> Vector2:
	if loc.begins_with("lane:"):
		var lane = loc.substr(5)
		return RiftGeometry.lane_point(lane, _front(lane))
	if loc.begins_with("obj:"):
		return RiftGeometry.DRAGON_PIT if loc.substr(4) in ["dragon", "elder"] else RiftGeometry.BARON_PIT
	if loc.begins_with("jungle:"):
		var camps: Array = RiftGeometry.CAMPS[loc.substr(7)]
		return camps[minute % camps.size()]
	if loc.begins_with("tower:"):
		var parts = loc.split(":")
		var tp = RiftGeometry.tower_point(parts[1], parts[2], int(parts[3]))
		# 站在塔前（進攻方那一側）
		return tp + (RiftGeometry.NEXUS[parts[1]] - tp).normalized() * -0.03
	if loc.begins_with("nexus:"):
		var side = loc.substr(6)
		return RiftGeometry.NEXUS[side] + (Vector2(0.5, 0.5) - RiftGeometry.NEXUS[side]).normalized() * 0.04
	if loc.begins_with("base:"):
		return RiftGeometry.FOUNTAIN[loc.substr(5)]
	return Vector2(0.5, 0.5)


## 沒有參與事件的選手：依時期與戰術姿態站在合理的位置。
func _default_loc(side: String, u: Dictionary) -> Vector2:
	var role: String = u["role"]
	var lane = _lane_of(role)
	if minute < 14 and team(side).lane_swap and lane != "mid":
		lane = "bot" if lane == "top" else "top"
	var back = -0.018 if side == "blue" else 0.018
	if minute == 0:
		return RiftGeometry.FOUNTAIN[side]
	if role == "JUNGLE":
		var camps: Array = RiftGeometry.CAMPS[side]
		return camps[(minute + (0 if side == "blue" else 2)) % camps.size()]
	if minute <= 14:
		return RiftGeometry.lane_point(lane, _front(lane) + back)
	# 中後期：上路守邊（或分推），其餘集結中路；後期全隊集結
	if role == "TOP" and (minute < 26 or stance[side] == "split"):
		return RiftGeometry.lane_point("top", _front("top") + back)
	if role in ["ADC", "SUPPORT"] and minute < 20:
		return RiftGeometry.lane_point("bot", _front("bot") + back)
	if focus[side] in LANES:
		return RiftGeometry.lane_point(focus[side], _front(focus[side]) + back * 2.0)
	if focus[side] in ["dragon", "baron"]:
		var pit = RiftGeometry.DRAGON_PIT if focus[side] == "dragon" else RiftGeometry.BARON_PIT
		return pit.lerp(RiftGeometry.NEXUS[side], 0.18)
	return RiftGeometry.lane_point("mid", _front("mid") + back * 2.0)


func _record_frame() -> void:
	if not detail:
		return
	var pos := {}
	for side in SIDES:
		var list: Array = []
		for u in units[side]:
			var key = side + str(u["idx"])
			var alive: bool = u["dead_until"] <= minute
			var p: Vector2
			if not alive:
				p = RiftGeometry.FOUNTAIN[side] + RiftGeometry.spread(u["idx"], 5, 0.02)
			elif _involved.has(key):
				p = _loc_point(_involved[key]) + RiftGeometry.spread(u["idx"] + (5 if side == "red" else 0), 10, 0.045)
			else:
				p = _default_loc(side, u) + RiftGeometry.spread(u["idx"], 5, 0.012)
			list.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), 1 if alive else 0])
		pos[side] = list
	for mk in _marks:
		if mk["p"] is Vector2:
			mk["p"] = [snappedf(mk["p"].x, 0.001), snappedf(mk["p"].y, 0.001)]
	var kda := {}
	for side in SIDES:
		kda[side] = units[side].map(func(u): return [u["kills"], u["deaths"], u["assists"]])
	frames.append({"m": minute, "pos": pos, "marks": _marks, "kda": kda, "st": {"blue": structures["blue"].duplicate(), "red": structures["red"].duplicate()},
		"gd": int(_team_gold("blue") - _team_gold("red")),
		"lf": [snappedf(_front("top"), 0.001), snappedf(_front("mid"), 0.001), snappedf(_front("bot"), 0.001)],
		"vis": [snappedf(vision["blue"], 0.01), snappedf(vision["red"], 0.01)]})
	_marks = []
	_involved = {}
	_where = ""
