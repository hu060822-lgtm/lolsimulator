## 賽前情報：對手的招牌打法、近況、王牌選手與拿手英雄，以及「勝率因素」拆解。
##
## 目的是讓玩家在比賽前就看得到自己的決策（戰術方向、先發、狀態管理、教練團）
## 對勝率的影響，而不是只看到總評高低。勝率是估計值（邏輯函數，係數依引擎校準），
## 不使用亂數、不改動世界狀態。
class_name MatchBriefing
extends RefCounted

## 每 1 點「等效能力差」對單局勝率的斜率（tools/calibrate.gd：能力差 4.5 → 熱門約 71%）。
const SLOPE := 0.2


static func build(w: WorldState, fx: Dictionary, me_id: String) -> Dictionary:
	var opp_id: String = fx["away"] if fx["home"] == me_id else fx["home"]
	var me: Club = w.clubs[me_id]
	var opp: Club = w.clubs[opp_id]
	for c in [me, opp]:
		if not LineupSelector.is_valid(w, c):
			LineupSelector.pick(w, c)
	var ta = TeamContext.from_club(w, me)
	var tb = TeamContext.from_club(w, opp)
	var my_comp = comfort_comp(w, me)
	var opp_comp = comfort_comp(w, opp)
	var my_plan = resolve_plan(ta.plan, my_comp)
	var opp_plan = resolve_plan(tb.plan, opp_comp)
	var factors = factor_breakdown(w, ta, tb, my_plan, opp_plan)
	var total = 0.0
	for f in factors:
		total += float(f["points"])
	# 再懸殊的對戰也有爆冷可能（引擎中能力差 6 以上仍有約 1 成爆冷），估計值限制在 8%～92%
	var p_game = clampf(1.0 / (1.0 + exp(-SLOPE * total)), 0.08, 0.92)
	var bo = int(fx.get("best_of", 1))
	var rec = StyleMatchup.best_counter(opp_plan, my_comp)
	return {
		"opponent": opp_id, "best_of": bo, "stage": fx.get("stage", "regular"),
		"my_plan": my_plan, "my_plan_set": ta.plan, "opp_plan": opp_plan, "opp_plan_set": tb.plan,
		"relation": StyleMatchup.relation(my_plan, opp_plan), "relation_reason": StyleMatchup.reason(my_plan, opp_plan),
		"recommended": rec, "recommended_reason": StyleMatchup.reason(rec, opp_plan),
		"avoid": StyleMatchup.beaten_by(opp_plan),
		"factors": factors, "win_game": p_game, "win_series": series_prob(p_game, bo),
		"opp_form": recent_form(w, opp_id), "my_form": recent_form(w, me_id),
		"opp_star": star_player(w, opp), "opp_champs": signature_champions(w, opp, 4),
		"opp_streak": opp.streak,
		"my_exposed": most_played(w, me, 3), "my_pockets": pocket_picks(w, me, 4),
	}


## 各項勝率因素，單位是「等效能力點」（正值 = 對我方有利）。
static func factor_breakdown(w: WorldState, ta: TeamContext, tb: TeamContext, my_plan: String, opp_plan: String) -> Array:
	var ca_a = lineup_ca(ta)
	var ca_b = lineup_ca(tb)
	var base = (ca_a + ca_b) / 2.0
	var out: Array = []
	out.append({"id": "skill", "label": "選手實力", "points": ca_a - ca_b,
		"detail": "先發平均能力 %d vs %d" % [roundi(ca_a), roundi(ca_b)]})
	var fa = avg_form(w, ta)
	var fb = avg_form(w, tb)
	out.append({"id": "form", "label": "狀態（士氣／自信／疲勞）", "points": (fa - fb) * base,
		"detail": "我方 %+.0f%%、對手 %+.0f%%" % [fa * 100.0, fb * 100.0]})
	var ea = ta.execution()
	var eb = tb.execution()
	out.append({"id": "execution", "label": "默契與執行力", "points": Tuning.f("execution_spread") * (ea - eb) * base,
		"detail": "默契 %d vs %d" % [roundi(ta.chemistry), roundi(tb.chemistry)]})
	var da = ta.draft_quality()
	var db = tb.draft_quality()
	out.append({"id": "staff", "label": "教練團（BP／指揮）", "points": (da - db) * 8.0 + (ta.shotcall_quality() - tb.shotcall_quality()) * 6.0,
		"detail": "BP 品質 %d%% vs %d%%" % [roundi(da * 100.0), roundi(db * 100.0)]})
	var rel = StyleMatchup.relation(my_plan, opp_plan)
	out.append({"id": "style", "label": "打法相剋", "points": StyleMatchup.EDGE * rel * 0.8 * base * 1.6,
		"detail": StyleMatchup.reason(my_plan, opp_plan) if rel != 0 else "雙方打法沒有明顯相剋"})
	return out


static func lineup_ca(t: TeamContext) -> float:
	var vals: Array = []
	for role in Attr.ROLES:
		var p: Player = t.players.get(role)
		vals.append(p.current_ability(role) if p else 30.0)
	return MathX.mean(vals)


## 與 MatchEngine._day_form 相同的期望值（不含亂數）。
static func avg_form(w: WorldState, t: TeamContext) -> float:
	var vals: Array = []
	for p in t.players.values():
		var f: float = (p.confidence - 50.0) / 100.0 * 0.06 + (p.morale - 50.0) / 100.0 * 0.03 + (p.motivation - 60.0) / 100.0 * 0.05 - p.fatigue / 100.0 * 0.07
		f -= maxf(p.stress - 40.0, 0.0) / 100.0 * 0.08 * (1.2 - p.trait_value("composure") / 100.0)
		vals.append(f)
	return MathX.mean(vals) if not vals.is_empty() else 0.0


## Bo-N 系列賽勝率（每局獨立、勝率相同）。
static func series_prob(p: float, bo: int) -> float:
	var need = bo / 2 + 1
	var total = 0.0
	# 先拿到 need 勝、對手拿 k 勝（k < need）
	for k in need:
		total += _binom(need - 1 + k, k) * pow(p, need) * pow(1.0 - p, k)
	return total


static func _binom(n: int, k: int) -> float:
	var r = 1.0
	for i in k:
		r *= float(n - i) / float(i + 1)
	return r


## 以先發各自拿手的兩隻英雄近似「這支隊伍想打的陣容」。
static func comfort_comp(w: WorldState, club: Club) -> Dictionary:
	var champs: Array = []
	for role in club.lineup:
		var p: Player = w.players.get(club.lineup[role])
		if p == null:
			continue
		for cid in p.top_champions(2):
			if w.champions.has(cid):
				champs.append(w.champions[cid])
	return CompAnalyzer.analyze(champs) if champs.size() >= 3 else {}


static func resolve_plan(plan: String, comp: Dictionary) -> String:
	if plan != "flexible" and plan != "":
		return plan
	return CompAnalyzer.best_plan(comp) if not comp.is_empty() else "teamfight"


## 最近 5 場系列賽："W" / "L"，由舊到新。
static func recent_form(w: WorldState, club_id: String, n: int = 5) -> Array:
	var played: Array = []
	for lg in LeagueEngine.all_competitions(w):
		for fx in lg.fixtures:
			if fx["played"] and (fx["home"] == club_id or fx["away"] == club_id):
				played.append([int(fx["day"]), "W" if fx["result"].get("winner", "") == club_id else "L"])
	played.sort_custom(func(a, b): return a[0] < b[0])
	return played.slice(maxi(played.size() - n, 0)).map(func(x): return x[1])


static func star_player(w: WorldState, club: Club) -> Dictionary:
	var best: Player = null
	var best_role = ""
	for role in club.lineup:
		var p: Player = w.players.get(club.lineup[role])
		if p and (best == null or p.current_ability(role) > best.current_ability(best_role)):
			best = p
			best_role = role
	if best == null:
		return {}
	return {"id": best.id, "handle": best.handle, "role": best_role, "champions": best.top_champions(3)}


## 近期正式賽最常用的英雄（對手最可能研究並禁用）。
static func most_played(w: WorldState, club: Club, n: int) -> Array:
	var ids: Array = club.pick_history.keys().filter(func(c): return float(club.pick_history[c]) >= 1.0)
	ids.sort_custom(func(a, b): return club.pick_history[a] > club.pick_history[b])
	return ids.slice(0, n)


## 秘密武器：先發熟練度 70 以上、但近期沒在正式賽用過的英雄。
static func pocket_picks(w: WorldState, club: Club, n: int) -> Array:
	var out: Array = []
	for role in Attr.ROLES:
		var p: Player = w.players.get(club.lineup.get(role, ""))
		if p == null:
			continue
		for cid in p.top_champions(6):
			if p.mastery(cid) >= 70.0 and float(club.pick_history.get(cid, 0.0)) < 0.5 and w.champions.has(cid):
				var ch: Champion = w.champions[cid]
				if role in ch.roles:
					out.append({"champion": cid, "role": role, "player": p.handle, "mastery": p.mastery(cid)})
					break
	out.sort_custom(func(a, b): return a["mastery"] > b["mastery"])
	return out.slice(0, n)


## 對手的拿手英雄：有正式賽紀錄就看紀錄（情報），否則才用熟練度推測。
static func signature_champions(w: WorldState, club: Club, n: int) -> Array:
	var seen := most_played(w, club, n)
	if seen.size() >= n:
		var roles := {}
		for role in club.lineup:
			var p: Player = w.players.get(club.lineup[role])
			if p:
				for cid in seen:
					if p.mastery(cid) > 0 and not roles.has(cid):
						roles[cid] = role
		return seen.map(func(cid): return {"champion": cid, "role": roles.get(cid, "")})
	var scored: Array = []
	for role in club.lineup:
		var p: Player = w.players.get(club.lineup[role])
		if p == null:
			continue
		for cid in p.top_champions(1):
			scored.append([p.mastery(cid), cid, role])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	return scored.slice(0, n).map(func(x): return {"champion": x[1], "role": x[2]})


## 賽後「勝負關鍵」：從一局結果整理出 3～5 個對我方有利或不利的因素。
## 每項 {text, good}：good = true 代表對我方有利。
static func key_factors(game: Dictionary, my_side: String) -> Array:
	var out: Array = []
	var opp_side = "red" if my_side == "blue" else "blue"
	var won: bool = game.get("winner", "") == my_side
	var plans: Dictionary = game.get("draft", {}).get("plan", {})
	var se: Dictionary = game.get("style_edge", {})
	var mine: String = str(plans.get(my_side, ""))
	var theirs: String = str(plans.get(opp_side, ""))
	if float(se.get(my_side, 0.0)) > 0.0:
		out.append({"text": "打法剋制：%s 壓過對手的%s（%s）" % [MatchEngine._plan_name(mine), MatchEngine._plan_name(theirs), StyleMatchup.reason(mine, theirs)], "good": true})
	elif float(se.get(my_side, 0.0)) < 0.0:
		out.append({"text": "打法被剋：對手的%s 剋制我方%s（%s）" % [MatchEngine._plan_name(theirs), MatchEngine._plan_name(mine), StyleMatchup.reason(mine, theirs)], "good": false})
	for ev in game.get("events", []):
		if ev.get("type", "") == "surprise":
			var ours: bool = my_side in ev.get("sides", [])
			out.append({"text": ("秘密武器奏效" if ours else "被對手的秘密武器打個措手不及"), "good": ours})
			break
	for dl in game.get("decisions", []):
		if dl.get("side", "") == my_side:
			out.append({"text": "抉擇「%s」%s" % [dl["label"], "成功" if dl["success"] else "失敗"], "good": dl["success"]})
	var cc: float = float(game.get("comp_counter", {}).get(my_side, 0.0))
	if absf(cc) > 0.03:
		out.append({"text": "BP：陣容%s對手" % ("剋制" if cc > 0 else "被"), "good": cc > 0})
	var curve: Array = game.get("gold_curve", [])
	if curve.size() > 15:
		var gd15 = int(curve[15]) * (1 if my_side == "blue" else -1)
		if absi(gd15) >= 1000:
			out.append({"text": "15 分鐘經濟%s %.1fk" % ["領先" if gd15 > 0 else "落後", absf(gd15) / 1000.0], "good": gd15 > 0})
		if won and gd15 <= -1500:
			out.append({"text": "逆轉勝：前期落後仍拿下比賽", "good": true})
		elif not won and gd15 >= 1500:
			out.append({"text": "被逆轉：前期優勢沒有轉化", "good": false})
	var dr: Dictionary = game.get("dragons", {})
	var ddiff = int(dr.get(my_side, 0)) - int(dr.get(opp_side, 0))
	if absi(ddiff) >= 2:
		out.append({"text": "小龍 %d：%d" % [int(dr.get(my_side, 0)), int(dr.get(opp_side, 0))], "good": ddiff > 0})
	var br: Dictionary = game.get("barons", {})
	if int(br.get(my_side, 0)) != int(br.get(opp_side, 0)):
		out.append({"text": "巴龍 %d：%d" % [int(br.get(my_side, 0)), int(br.get(opp_side, 0))], "good": int(br.get(my_side, 0)) > int(br.get(opp_side, 0))})
	# 失誤最多的選手
	var worst = ""
	var worst_m = 1
	for pid in game.get("players", {}):
		var st: Dictionary = game["players"][pid]
		if st.get("side", "") == my_side and int(st.get("mistakes", 0)) > worst_m:
			worst_m = int(st["mistakes"])
			worst = pid
	if worst != "":
		out.append({"text": "失誤：%d 次關鍵失誤" % worst_m, "good": false, "player_id": worst})
	return out.slice(0, 6)
