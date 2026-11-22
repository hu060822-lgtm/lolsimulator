## 組織：董事會信心、財務危機、品牌價值。
##
## 董事會信心（club.board_confidence，0..100）每週朝「成績 + 財務 + 外界評價」的目標值靠攏。
## - 低於 30：玩家收到董事會警告；低於 15：董事會介入（削減薪資預算、指定目標）。
## - AI 俱樂部：信心過低時撤換主教練（ClubAI.review_coach 已處理賽季末，這裡處理季中）。
## 財務危機：現金為負時董事會信心下滑；低於 -50 萬時觸發危機（玩家選擇處理方式，AI 自動出售高薪選手）。
## 品牌價值（club.brand，0..100）：由聲望、粉絲、外界評價、國際賽成績慢慢累積；
## 影響贊助金額與周邊收入。玩家可以花錢做品牌活動。
class_name Organization
extends RefCounted

const CRISIS_CASH := -500000
const BRAND_CAMPAIGNS := {
	"content": {"name": "內容企劃（紀錄片、Vlog）", "cost": 150000, "brand": 4.0, "fans_pct": 2.0},
	"merch_line": {"name": "聯名周邊系列", "cost": 250000, "brand": 6.0, "fans_pct": 1.0},
	"fan_fest": {"name": "粉絲嘉年華", "cost": 400000, "brand": 8.0, "fans_pct": 4.0},
}


static func board_target(w: WorldState, club: Club) -> float:
	var lg: League = w.leagues.get(club.league_id)
	var perf := 0.0
	if lg and lg.standings.has(club.id):
		var st: Dictionary = lg.standings[club.id]
		if int(st["w"]) + int(st["l"]) >= 2:
			var pos = LeagueEngine.sorted_standings(lg).find(club.id) + 1
			perf = (Media.expected_position(w, club) - pos) / float(lg.club_ids.size()) * 80.0
	var money = clampf(float(club.cash) / maxf(club.wage_budget, 1.0), -1.0, 2.0) * 10.0
	return clampf(55.0 + perf + money + club.opinion * 0.15, 0.0, 100.0)


static func weekly(w: WorldState, club: Club) -> void:
	var in_season = w.phase != WorldState.PHASE_OFFSEASON
	if in_season:
		club.board_confidence = lerpf(club.board_confidence, board_target(w, club), 0.12)
	if club.cash < 0:
		club.board_confidence = clampf(club.board_confidence - 2.0, 0.0, 100.0)
	_brand_week(w, club)
	_check_crises(w, club)


static func _brand_week(w: WorldState, club: Club) -> void:
	var target = club.reputation * 0.5 + clampf(club.fanbase / 20000.0, 0.0, 30.0) + club.opinion * 0.1 \
		+ club.world_titles * 3.0 + club.msi_titles * 1.5
	club.brand = clampf(lerpf(club.brand, clampf(target, 0.0, 100.0), 0.02), 0.0, 100.0)
	# AI：資金充裕時做品牌活動
	if not club.is_human and club.cash > club.wage_budget * 3 and w.rng.chance(0.05):
		run_campaign(w, club, "content")


static func run_campaign(w: WorldState, club: Club, kind: String) -> Dictionary:
	var c: Dictionary = BRAND_CAMPAIGNS.get(kind, {})
	if c.is_empty():
		return {"ok": false, "note": "未知的活動"}
	if club.cash < int(c["cost"]):
		return {"ok": false, "note": "資金不足"}
	Finance.spend(club, "brand", int(c["cost"]))
	var gain = float(c["brand"]) * clampf((100.0 - club.brand) / 60.0, 0.2, 1.0)  # 品牌越強，邊際效益越低
	club.brand = clampf(club.brand + gain, 0.0, 100.0)
	club.fanbase = int(club.fanbase * (1.0 + float(c["fans_pct"]) / 100.0))
	w.log.add("brand_campaign", w.day, [club.id], {"kind": kind, "gain": gain}, [])
	return {"ok": true, "note": "%s 完成：品牌 +%.1f" % [c["name"], gain]}


## 品牌對收入的乘數（贊助、周邊）。品牌 40 為基準 1.0。
static func brand_multiplier(club: Club) -> float:
	return 0.8 + club.brand / 200.0


static func _check_crises(w: WorldState, club: Club) -> void:
	var flags: Dictionary = club.crisis_flags
	# 財務危機
	if club.cash < CRISIS_CASH and not flags.has("finance"):
		flags["finance"] = w.day
		w.log.add("crisis", w.day, [club.id], {"kind": "finance", "cash": club.cash}, ["現金 %d" % club.cash])
		Media.post(w, "crisis", "%s 傳出財務危機，現金缺口超過 50 萬" % club.name, [club.id], -0.8)
		if club.is_human:
			w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "crisis", "crisis": "finance", "player_id": "",
				"text": "財務危機：俱樂部現金只剩 %s。董事會要求你立刻處理。" % _money(club.cash), "resolved": false,
				"options": ["crisis:sell_star", "crisis:investor", "crisis:austerity"],
				"option_labels": {"crisis:sell_star": "出售薪資最高的選手", "crisis:investor": "引進新投資方（+$1.5M，董事會信心大降）",
					"crisis:austerity": "緊縮開支（薪資預算 -25%，選手士氣下降）"}})
		else:
			resolve(w, club, "sell_star")
	elif club.cash > 0:
		flags.erase("finance")
	# 董事會信心
	if club.board_confidence < 30.0 and not flags.has("board_warning"):
		flags["board_warning"] = w.day
		w.log.add("crisis", w.day, [club.id], {"kind": "board_warning"}, ["董事會信心 %d" % int(club.board_confidence)])
		if club.is_human:
			w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "crisis", "crisis": "board_warning", "player_id": "",
				"text": "董事會警告：對球隊現況不滿（信心 %d）。成績或財務沒有改善的話，董事會將介入。" % int(club.board_confidence),
				"resolved": false, "options": ["acknowledge"]})
	if club.board_confidence < 15.0 and not flags.has("board_takeover"):
		flags["board_takeover"] = w.day
		club.wage_budget = int(club.wage_budget * 0.8)
		Media.post(w, "crisis", "%s 董事會介入經營，傳出高層改組" % club.name, [club.id], -0.9)
		w.log.add("crisis", w.day, [club.id], {"kind": "board_takeover"}, ["董事會信心 %d" % int(club.board_confidence)])
		if club.is_human:
			w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "crisis", "crisis": "board_takeover", "player_id": "",
				"text": "董事會介入：薪資預算削減 20%%。董事會要求本季至少打進季後賽。", "resolved": false, "options": ["acknowledge"]})
		else:
			# AI 俱樂部：撤換主教練
			if club.coach_id != "":
				StaffSystem.dismiss(w, club, "head_coach")
				StaffSystem.ai_fill(w, club)
				club.board_confidence = 35.0


## 處理危機（玩家選擇或 AI）。
static func resolve(w: WorldState, club: Club, option: String) -> Dictionary:
	match option:
		"sell_star":
			var best: Player = null
			for pid in club.roster:
				var p: Player = w.players[pid]
				if p.contract and (best == null or p.contract.salary > best.contract.salary):
					best = p
			if best:
				best.transfer_requested = true
				# 立即尋找買家：資金充裕、願意出價的俱樂部
				var buyers: Array = w.clubs.values().filter(func(c): return c.id != club.id and c.cash > TransferMarket.market_value(w, best) * 1.5)
				buyers.sort_custom(func(a, b): return a.reputation > b.reputation)
				for b in buyers.slice(0, 4):
					var fee = int(TransferMarket.market_value(w, best) * 0.8)
					var r = TransferMarket.make_transfer_offer(w, b, best, fee, int(TransferMarket.wage_demand(w, best) * 1.1), 2, "starter")
					if r.get("accepted", false):
						return {"note": "%s 以 %s 轉會至 %s" % [best.handle, _money(fee), b.name]}
				return {"note": "%s 已放上轉會名單，但暫時沒有買家" % best.handle}
			return {"note": "沒有可出售的選手"}
		"investor":
			Finance.earn(club, "investment", 1500000)
			club.board_confidence = clampf(club.board_confidence - 20.0, 0.0, 100.0)
			return {"note": "新投資方注資 $1.5M；董事會對你的信心下降"}
		"austerity":
			club.wage_budget = int(club.wage_budget * 0.75)
			for pid in club.roster:
				w.players[pid].morale = clampf(w.players[pid].morale - 6.0, 0.0, 100.0)
			club.board_confidence = clampf(club.board_confidence + 5.0, 0.0, 100.0)
			return {"note": "薪資預算削減 25%，選手士氣下降"}
	return {"note": ""}


## 新賽季：危機旗標重置，董事會信心部分回歸。
static func new_season(w: WorldState) -> void:
	for c in w.clubs.values():
		c.crisis_flags = {}
		c.board_confidence = lerpf(c.board_confidence, 60.0, 0.4)


static func label(v: float) -> String:
	if v >= 75:
		return "非常滿意"
	if v >= 55:
		return "滿意"
	if v >= 35:
		return "觀望"
	if v >= 15:
		return "不滿"
	return "即將介入"


static func _money(v: int) -> String:
	if absi(v) >= 1000000:
		return "$%.1fM" % (v / 1000000.0)
	return "$%dk" % int(v / 1000)
