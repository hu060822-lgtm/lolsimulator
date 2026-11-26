## 關鍵抉擇：比賽中依局勢出現的「抉擇卡」，每張卡有 2～3 個選項，各有不同的風險與代價。
##
## 這不是調數值，而是改變比賽走向的決定：偷打巴龍還是拿巴龍當誘餌？死守龍魂還是放龍換塔？
## 落後 5 千時要賭打野偷龍、四一分推，還是全隊龜縮？對面的大哥殺瘋了，要全隊去針對他嗎？
##
## - 即時指揮時，玩家在暫停點看到抉擇卡並親自決定（GameSession.live_decide）。
## - 其他情況（AI 對戰、快速模擬、交給教練）由指揮在戰術調整點依風險偏好決定。
## - 每種抉擇每隊每局最多一次；結果以亂數判定，成功率取決於當下戰力、視野、人數與選手能力。
class_name MatchDecisions
extends RefCounted

const AI_CHANCE := 0.4      ## AI 指揮在每個調整點考慮抉擇的機率
const PRIORITY := ["baron", "soul", "carry", "behind", "tilt", "tempo"]


## 這一隊目前可做的抉擇（依優先順序）。每項：{id, title, text, options: [{id, label, desc, chance, risk}]}
## chance = -1 代表確定發生（穩健選項）。
static func available(e: MatchEngine, side: String) -> Array:
	var out: Array = []
	if e.winner != "" or e._alive(side).size() < 3:
		return out
	var o := e.other(side)
	for id in PRIORITY:
		if e.decided.has(side + ":" + id):
			continue
		var d := _build(e, side, o, id)
		if not d.is_empty():
			out.append(d)
	return out


static func _build(e: MatchEngine, side: String, o: String, id: String) -> Dictionary:
	var adv := _adv(e, side)
	var vis: float = e.vision[side] - e.vision[o]
	var alive_diff: int = e._alive(side).size() - e._alive(o).size()
	match id:
		"baron":
			if e.minute < 19 or e.minute + 3 < e.next_baron or e.baron_until[side] >= e.minute or e.baron_until[o] >= e.minute:
				return {}
			var pick_share: float = e.comp[side]["share"]["pick"]
			return {"id": id, "title": "巴龍開放", "text": "巴龍坑周圍沒有對手的視野，指揮在等你的決定。",
				"options": [
					_opt("rush", "偷打巴龍", "成功就帶 buff 推進；被抓到會丟巴龍又被團滅", _clamp(0.40 + 0.9 * adv + 0.3 * vis + 0.12 * alive_diff, 0.10, 0.85), "high"),
					_opt("bait", "拿巴龍當誘餌", "佈好視野假打巴龍，等對手進來抓人", _clamp(0.32 + 0.8 * vis + 0.4 * adv + pick_share * 0.4, 0.10, 0.75), "mid"),
					_opt("trade", "放巴龍換塔", "讓對手拿巴龍，我方趁機推掉兩路外塔", -1.0, "safe"),
				]}
		"soul":
			var mine: int = e.dragons[side]
			var theirs: int = e.dragons[o]
			if e.minute + 3 < e.next_dragon or (mine != 3 and theirs != 3) or mine >= 4 or theirs >= 4:
				return {}
			var fight := _clamp(0.5 + 1.1 * adv + 0.2 * vis + 0.1 * alive_diff, 0.1, 0.9)
			if mine == 3:
				return {"id": id, "title": "龍魂點", "text": "再拿一條小龍就能取得龍魂。",
					"options": [
						_opt("all_in", "全隊集結搶龍魂", "提早布視野打一波龍魂團", fight, "high"),
						_opt("safe", "穩穩控龍", "不強開，等對手犯錯（交給指揮）", -1.0, "safe"),
					]}
			return {"id": id, "title": "對手龍魂點", "text": "對手再拿一條龍就取得龍魂。",
				"options": [
					_opt("all_in", "死守龍坑", "全隊提前集結，硬接這波龍魂團", fight, "high"),
					_opt("trade", "放龍換塔", "讓出龍魂，換兩座塔與經濟", -1.0, "safe"),
				]}
		"carry":
			var star := _enemy_carry(e, o)
			if star.is_empty():
				return {}
			return {"id": id, "title": "對手大哥殺瘋了", "text": "%s %d/%d，對方的經濟都壓在他身上。" % [e._h(star), int(star["kills"]), int(star["deaths"])],
				"carry_idx": int(star["idx"]),
				"options": [
					_opt("hunt", "全隊針對 %s" % e._h(star), "視野包圍去抓他，抓到會打擊他的心態", _clamp(0.35 + 0.5 * vis + 0.3 * adv + 0.1 * alive_diff, 0.10, 0.75), "high"),
					_opt("avoid", "避開他，打另一路", "不跟他正面衝突，在地圖另一側換資源", -1.0, "safe"),
				]}
		"behind":
			var gd: float = e._team_gold(side) - e._team_gold(o)
			if e.minute < 18 or gd > -3000:
				return {}
			var jg: Dictionary = e.units[side][1]
			var mech: float = jg["player"].skill("mechanics") if jg["player"] else 40.0
			var obj := "巴龍" if e.minute >= e.next_baron and e.minute >= 20 else "小龍"
			return {"id": id, "title": "經濟落後 %.1fk" % (-gd / 1000.0), "text": "正面打不贏，需要改變節奏。",
				"options": [
					_opt("steal", "打野偷%s" % obj, "打野單獨潛入偷資源，失敗就送一顆人頭", _clamp(0.18 + (mech - 60.0) / 100.0 * 0.6 + 0.3 * vis, 0.08, 0.45), "high"),
					_opt("split", "四一分推", "最強的單帶拉扯邊路，其他人守中", -1.0, "mid"),
					_opt("turtle", "全隊龜縮守塔", "清線守高地，拖到後期等對手犯錯", -1.0, "safe"),
				]}
		"tilt":
			var u := _tilted(e, side)
			if u.is_empty():
				return {}
			var comp_v: float = u["player"].trait_value("composure") if u["player"] else 50.0
			return {"id": id, "title": "%s 心態快崩了" % e._h(u), "text": "已經死了 %d 次，語音裡越來越安靜。" % int(u["deaths"]),
				"tilt_idx": int(u["idx"]),
				"options": [
					_opt("comfort", "安撫並保護他", "改打保守，全隊幫他穩住（穩定但放慢節奏）", -1.0, "safe"),
					_opt("gamble", "讓他放手去打", "賭他打出來；抗壓性越高越可能成功", _clamp(0.35 + (comp_v - 50.0) / 150.0, 0.15, 0.7), "high"),
				]}
		"tempo":
			if e.minute < 12 or e.minute > 16:
				return {}
			var jg: Dictionary = e.units[side][1]
			var ej: Dictionary = e.units[o][1]
			var jdiff: float = (e._perf(jg, {"mechanics": 0.5, "map_awareness": 0.5}) - e._perf(ej, {"mechanics": 0.5, "map_awareness": 0.5})) * 2.0
			var bot_prio: float = e.priority[side]["bot"]
			return {"id": id, "title": "對線期尾聲", "text": "第一座外塔快掉了，接下來的節奏由你決定。",
				"options": [
					_opt("invade", "入侵對手野區", "打野帶中路反野，抓到對手打野就能控住地圖", _clamp(0.40 + 0.8 * adv + 0.4 * vis + jdiff, 0.15, 0.8), "mid"),
					_opt("dive", "下路越塔強殺", "打野、中路一起越塔，成功推掉下路外塔", _clamp(0.35 + 1.0 * adv + 0.3 * bot_prio, 0.10, 0.75), "high"),
					_opt("farm", "穩定發育", "不冒險，全隊吃線發育（確定 +150 經濟／人）", -1.0, "safe"),
				]}
	return {}


static func _opt(id: String, label: String, desc: String, chance: float, risk: String) -> Dictionary:
	return {"id": id, "label": label, "desc": desc, "chance": chance, "risk": risk}


static func _clamp(v: float, lo: float, hi: float) -> float:
	return clampf(v, lo, hi)


static func _adv(e: MatchEngine, side: String) -> float:
	return log(maxf(e._team_power(side), 0.01) / maxf(e._team_power(e.other(side)), 0.01))


static func _enemy_carry(e: MatchEngine, o: String) -> Dictionary:
	var best: Dictionary = {}
	for u in e._alive(o):
		if int(u["kills"]) - int(u["deaths"]) >= 4 and (best.is_empty() or int(u["kills"]) > int(best["kills"])):
			best = u
	return best


static func _tilted(e: MatchEngine, side: String) -> Dictionary:
	for u in e.units[side]:
		if int(u["deaths"]) >= 4 and int(u["deaths"]) >= int(u["kills"]) + 3:
			return u
	return {}


static func _find(e: MatchEngine, side: String, id: String) -> Dictionary:
	for d in available(e, side):
		if d["id"] == id:
			return d
	return {}


## 執行抉擇。回傳 {ok, success, text}。
static func resolve(e: MatchEngine, side: String, id: String, option: String) -> Dictionary:
	var d := _find(e, side, id)
	if d.is_empty():
		return {"ok": false, "text": "這個抉擇已經失效"}
	var opt: Dictionary = {}
	for x in d["options"]:
		if x["id"] == option:
			opt = x
	if opt.is_empty():
		return {"ok": false, "text": "沒有這個選項"}
	e.decided[side + ":" + id] = true
	var chance: float = opt["chance"]
	var success: bool = chance < 0.0 or e.rng.chance(chance)
	var o := e.other(side)
	var tn: String = e.team(side).short_name
	var on: String = e.team(o).short_name
	var text := ""
	match id + ":" + option:
		"baron:rush":
			e._where = "obj:baron"
			if success:
				e._award_objective(side, "baron", ["關鍵抉擇：偷打巴龍成功"])
				e._push(side, 2, "巴龍 buff 推進")
				text = "%s 偷打巴龍成功，帶著 buff 推進！" % tn
			else:
				e._award_objective(o, "baron", ["抓到對手偷巴龍"])
				_kills(e, o, side, 2, "caught")
				text = "%s 偷巴龍被 %s 抓到，丟了巴龍還倒了兩人" % [tn, on]
			e.next_baron = e.minute + 7
		"baron:bait":
			e._where = "obj:baron"
			if success:
				_kills(e, side, o, 2, "pick")
				e._award_objective(side, "baron", ["誘敵成功後拿下巴龍"])
				e.next_baron = e.minute + 7
				text = "%s 在巴龍坑設伏，抓到兩人後順勢拿下巴龍！" % tn
			else:
				_kills(e, o, side, 1, "pick")
				text = "%s 看穿了誘餌，反過來抓到 %s 一人" % [on, tn]
		"baron:trade":
			e._award_objective(o, "baron", ["對手放巴龍"])
			e.next_baron = e.minute + 7
			_siege(e, side, 1.6)
			text = "%s 放掉巴龍，趁機在兩路推塔" % tn
		"soul:all_in":
			e._prep[side] = 0.25
			e._where = "obj:dragon"
			var f: Dictionary = e._teamfight("龍魂團", side)
			e._prep = {"blue": 0.0, "red": 0.0}
			success = f["winner"] == side
			e._award_objective(f["winner"], "dragon", ["龍魂團勝利"])
			e.next_dragon = e.minute + 6
			text = "%s 打贏龍魂團！" % tn if success else "%s 輸掉龍魂團" % tn
		"soul:safe":
			e.stance[side] = "control"
			e.focus[side] = "dragon"
			text = "%s 選擇穩穩控龍，等對手犯錯" % tn
		"soul:trade":
			e._award_objective(o, "dragon", ["對手放龍"])
			e.next_dragon = e.minute + 6
			_siege(e, side, 1.6)
			text = "%s 讓出龍魂，換到兩路推進" % tn
		"carry:hunt":
			var star: Dictionary = e.units[o][int(d["carry_idx"])]
			e._where = "jungle:" + o
			if success and star["dead_until"] <= e.minute:
				var killer: Dictionary = e._strongest(e._alive(side))
				e._kill(side, killer, star, [], "pick", "%s 全隊包抄，抓到 %s" % [tn, e._h(star)], ["關鍵抉擇：針對大哥"])
				star["form"] = float(star["form"]) - 0.06
				text = "%s 成功針對 %s，他的節奏被打斷了" % [tn, e._h(star)]
			else:
				success = false
				var victim: Dictionary = e._weakest_positioned(e._alive(side))
				if victim.has("idx"):
					e._kill(o, star, victim, [], "pick", "%s 反殺前來包抄的 %s" % [e._h(star), e._h(victim)], ["針對失敗"])
				text = "%s 針對失敗，%s 又多一顆人頭" % [tn, e._h(star)]
		"carry:avoid":
			_siege(e, side, 1.0)
			text = "%s 避開對手大哥，在另一側推進" % tn
		"behind:steal":
			var jg: Dictionary = e.units[side][1]
			var obj := "baron" if e.minute >= e.next_baron and e.minute >= 20 else "dragon"
			e._where = "obj:" + obj
			if success:
				e._award_objective(side, obj, ["打野偷取成功"])
				if obj == "baron":
					e.next_baron = e.minute + 7
				else:
					e.next_dragon = e.minute + 6
				text = "%s 打野 %s 偷到%s！" % [tn, e._h(jg), e._obj_name(obj)]
			else:
				if jg["dead_until"] <= e.minute and not e._alive(o).is_empty():
					e._kill(o, e._strongest(e._alive(o)), jg, [], "pick", "%s 打野 %s 偷%s被抓" % [tn, e._h(jg), e._obj_name(obj)], ["偷取失敗"])
				text = "%s 打野偷%s失敗" % [tn, e._obj_name(obj)]
		"behind:split":
			e.stance[side] = "split"
			var lane := "top" if e.structures[o]["top"] <= e.structures[o]["bot"] else "bot"
			e.siege[side][lane] += 1.0
			e._try_destroy(side, lane, "四一分推")
			text = "%s 改打四一分推，%s路壓力大增" % [tn, e._lane_name(lane)]
		"behind:turtle":
			e.stance[side] = "stall"
			for l in e.siege[o]:
				e.siege[o][l] *= 0.3
			text = "%s 全隊龜縮清線，拖住對手的推進" % tn
		"tilt:comfort":
			var u: Dictionary = e.units[side][int(d["tilt_idx"])]
			u["form"] = maxf(float(u["form"]), 0.0) + 0.03
			e.stance[side] = "control"
			text = "%s 改打保守，穩住 %s 的心態" % [tn, e._h(u)]
		"tilt:gamble":
			var u2: Dictionary = e.units[side][int(d["tilt_idx"])]
			if success:
				u2["form"] = float(u2["form"]) + 0.12
				text = "%s 放開手腳，%s 找回手感了！" % [tn, e._h(u2)]
			else:
				u2["form"] = float(u2["form"]) - 0.08
				text = "%s 越打越急，%s 狀態更差了" % [tn, e._h(u2)]
		"tempo:invade":
			var jg: Dictionary = e.units[side][1]
			var ej: Dictionary = e.units[o][1]
			e._where = "jungle:" + o
			if success and ej["dead_until"] <= e.minute:
				e._kill(side, jg, ej, [], "invade_kill", "%s 反野抓到對手打野 %s" % [tn, e._h(ej)], ["關鍵抉擇：入侵野區"])
				jg["gold"] += 250.0
				text = "%s 入侵成功，掌控了對手野區" % tn
			else:
				success = false
				if jg["dead_until"] <= e.minute:
					e._kill(o, ej, jg, [], "invade_punished", "%s 入侵被抓，打野 %s 陣亡" % [tn, e._h(jg)], ["入侵失敗"])
				text = "%s 入侵失敗，反被 %s 抓到" % [tn, on]
		"tempo:dive":
			e._where = "lane:bot"
			if success:
				_kills(e, side, o, 2, "lane_kill")
				e.siege[side]["bot"] += 1.5
				e._try_destroy(side, "bot", "越塔強殺")
				text = "%s 越塔成功，雙殺並推掉下路外塔！" % tn
			else:
				_kills(e, o, side, 2, "lane_kill")
				text = "%s 越塔失敗，被塔與對手反殺兩人" % tn
		"tempo:farm":
			for u in e.units[side]:
				u["gold"] += 150.0
			text = "%s 選擇穩定發育" % tn
	var causes: Array = ["關鍵抉擇：%s" % opt["label"]]
	if chance >= 0.0:
		causes.append("成功率約 %d%%" % roundi(chance * 100.0))
	e._event("decision", text, [side], causes, [], {"decision": id, "option": option, "success": success})
	e.decision_log.append({"side": side, "minute": e.minute, "id": id, "option": option, "label": opt["label"], "success": success, "chance": chance, "text": text})
	return {"ok": true, "success": success, "text": text}


## AI 指揮：在戰術調整點有機率做抉擇。風險偏好看侵略性，指揮品質高的隊伍較會評估成功率。
static func ai_turn(e: MatchEngine) -> void:
	for side in MatchEngine.SIDES:
		if side == e.manual_side or e.winner != "":
			continue
		if not e.rng.chance(AI_CHANCE):
			continue
		var ds := available(e, side)
		if ds.is_empty():
			continue
		var d: Dictionary = ds[0]
		var t: TeamContext = e.team(side)
		var q := t.shotcall_quality()
		var best := ""
		var best_v := -INF
		for opt in d["options"]:
			var c: float = opt["chance"]
			var v := 0.12 if c < 0.0 else (c * 1.0 - (1.0 - c) * 0.9)
			if c >= 0.0:
				v += (t.aggression - 0.5) * 0.4
				v += e.rng.normal(0.0, 0.25 * (1.1 - q))
			if v > best_v:
				best_v = v
				best = opt["id"]
		resolve(e, side, d["id"], best)


static func _kills(e: MatchEngine, killer_side: String, victim_side: String, n: int, kind: String) -> void:
	for i in n:
		var victims := e._alive(victim_side)
		var killers := e._alive(killer_side)
		if victims.is_empty() or killers.is_empty():
			return
		e._kill(killer_side, e._strongest(killers), e._weakest_positioned(victims), [], kind, "", [])


static func _siege(e: MatchEngine, side: String, amount: float) -> void:
	var o := e.other(side)
	for lane in ["top", "bot"]:
		if e.structures[o][lane] < 4:
			e.siege[side][lane] += amount
			e._try_destroy(side, lane, "資源交換")
