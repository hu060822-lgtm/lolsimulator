## 本季目標：董事會在季初開出三個目標，季末逐項驗收。
##
## - 名次目標：例行賽名次不低於外界預期。
## - 舞台目標：強隊要打進國際賽（Worlds），其他隊伍要打進季後賽。
## - 附加目標（依俱樂部經營方針挑一個）：培養新秀（U21 選手出賽）、控制薪資、宿敵戰至少贏一場、品牌成長。
## - 每達成一項：董事會信心 +5、經理聲望 +1；每失敗一項：董事會信心 -5。
## 目標存在 w.manager["goals"]：{year, club_id, list:[{id, text, target, base, met}]}。
class_name SeasonGoals
extends RefCounted

const BOARD_PER_GOAL := 5.0
const REP_PER_GOAL := 1.0
const YOUTH_GAMES := 6
const BRAND_GAIN := 5.0


static func current(w: WorldState) -> Dictionary:
	var me: Club = w.human_club()
	if me == null:
		return {}
	var m := ManagerCareer.data(w)
	var g: Dictionary = m.get("goals", {})
	if g.is_empty() or int(g.get("year", 0)) != w.year or g.get("club_id", "") != me.id:
		g = generate(w)
	return g


## 季初產生本季目標。
static func generate(w: WorldState) -> Dictionary:
	var me: Club = w.human_club()
	if me == null:
		return {}
	var lg: League = w.leagues.get(me.league_id)
	var list: Array = []
	var expected := roundi(Media.expected_position(w, me))
	list.append({"id": "rank", "target": expected, "text": "例行賽拿到第 %d 名或更好" % expected})
	if lg and lg.tier <= 1 and me.reputation >= 70.0:
		list.append({"id": "intl", "target": 1, "text": "打進世界賽"})
	else:
		var po := int(lg.format.get("playoffs", {}).get("teams", 4)) if lg else 4
		list.append({"id": "playoffs", "target": po, "text": "打進季後賽（前 %d 名）" % po})
	var extra := "rival"
	match me.philosophy:
		"develop":
			extra = "youth"
		"moneyball":
			extra = "budget"
		"win_now":
			extra = "rival"
		_:
			extra = ["rival", "brand", "youth"][w.rng.range_i(0, 2)]
	match extra:
		"youth":
			list.append({"id": "youth", "target": YOUTH_GAMES, "text": "讓 21 歲以下選手至少出賽 %d 場" % YOUTH_GAMES})
		"budget":
			list.append({"id": "budget", "target": me.wage_budget, "text": "季末選手薪資不超過預算"})
		"brand":
			list.append({"id": "brand", "target": BRAND_GAIN, "base": me.brand, "text": "品牌價值成長 %d 點" % int(BRAND_GAIN)})
		_:
			var r := Rivalry.current(w)
			var rn: String = w.clubs[r["club_id"]].short_name if not r.is_empty() and r["club_id"] != "" else "宿敵"
			list.append({"id": "rival", "target": 1, "text": "宿敵戰至少贏 %s 一次" % rn})
	var g := {"year": w.year, "club_id": me.id, "list": list}
	ManagerCareer.data(w)["goals"] = g
	return g


## 目前進度（介面用）：回傳 {done: bool|null, progress: String}。null 表示賽季中尚無定論。
static func progress(w: WorldState, goal: Dictionary) -> Dictionary:
	var me: Club = w.human_club()
	match goal["id"]:
		"youth":
			var n := youth_games(w, me)
			return {"done": true if n >= int(goal["target"]) else null, "progress": "%d / %d 場" % [n, int(goal["target"])]}
		"budget":
			var bill := TransferMarket.wage_bill(w, me)
			return {"done": null, "progress": "$%dK / $%dK" % [bill / 1000, int(goal["target"]) / 1000]}
		"brand":
			var d := me.brand - float(goal.get("base", me.brand))
			return {"done": true if d >= float(goal["target"]) else null, "progress": "%+.1f / +%d" % [d, int(goal["target"])]}
		"rival":
			var r := Rivalry.current(w)
			var won := int(r.get("w", 0))
			return {"done": true if won >= 1 else null, "progress": "%d 勝 %d 敗" % [won, int(r.get("l", 0))]}
		"rank", "playoffs":
			var lg: League = w.leagues.get(me.league_id)
			var pos := LeagueEngine.sorted_standings(lg).find(me.id) + 1 if lg else 0
			return {"done": null, "progress": "目前第 %d 名" % pos}
	return {"done": null, "progress": ""}


static func youth_games(w: WorldState, me: Club) -> int:
	var n := 0
	for pid in me.roster:
		var p: Player = w.players[pid]
		if p.age(w.year) <= 21:
			n += int(p.season_stats.get("games", 0))
	return n


## 季末驗收（end_season 內、經理評價之前呼叫；此時俱樂部本季紀錄已寫入 history）。
static func evaluate(w: WorldState) -> Dictionary:
	var me: Club = w.human_club()
	if me == null or me.history.is_empty():
		return {}
	var g := current(w)
	var h: Dictionary = me.history[-1]
	var pos := int(h.get("position", 99))
	var met_n := 0
	var lines: Array = []
	for goal in g["list"]:
		var met := false
		match goal["id"]:
			"rank", "playoffs":
				met = pos <= int(goal["target"])
			"intl":
				met = str(h.get("worlds", "")) != ""
			"youth":
				met = youth_games(w, me) >= int(goal["target"])
			"budget":
				met = TransferMarket.wage_bill(w, me) <= int(goal["target"])
			"brand":
				met = me.brand - float(goal.get("base", me.brand)) >= float(goal["target"])
			"rival":
				met = int(Rivalry.current(w).get("w", 0)) >= 1
		goal["met"] = met
		if met:
			met_n += 1
		lines.append(("✔ " if met else "✘ ") + str(goal["text"]))
	var total: int = g["list"].size()
	var board := (met_n - (total - met_n)) * BOARD_PER_GOAL
	me.board_confidence = clampf(me.board_confidence + board, 0.0, 100.0)
	var m := ManagerCareer.data(w)
	m["reputation"] = clampf(float(m.get("reputation", 30.0)) + met_n * REP_PER_GOAL, 0.0, 100.0)
	var verdict := "董事會非常滿意" if met_n == total else ("董事會勉強接受" if met_n * 2 >= total else "董事會相當失望")
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "season_goals", "player_id": "",
		"text": "本季目標驗收：達成 %d / %d 項，%s（董事會信心 %+d）。\n%s" % [met_n, total, verdict, int(board), "\n".join(lines)],
		"resolved": false, "options": ["acknowledge"]})
	w.log.add("season_goals", w.day, [me.id], {"met": met_n, "total": total}, [])
	return {"met": met_n, "total": total, "board": board}
