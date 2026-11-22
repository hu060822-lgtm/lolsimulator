## 財務：收入來源、支出、贊助合約、賽季帳本。
##
## 收入：聯賽分潤、贊助、周邊商品（粉絲）、直播與媒體（聲望）、獎金、轉會收入。
## 支出：選手薪資、員工薪資、轉會費、解約補償、球探費用。
## 每季帳本存在 club.ledger，賽季結束時封存到 club.finance_log。
class_name Finance
extends RefCounted

const INCOME_NAMES := {"league_share": "聯賽分潤", "sponsors": "贊助", "merch": "周邊商品", "media": "直播與媒體",
	"prize": "獎金", "sponsor_bonus": "贊助績效獎金", "transfer_in": "轉會收入", "events": "活動與事件"}
const EXPENSE_NAMES := {"player_wages": "選手薪資", "staff_wages": "員工薪資", "transfer_out": "轉會支出",
	"staff_severance": "員工解約補償", "scouting": "球探費用", "operations": "營運成本", "dividends": "投資方分紅", "events": "事件支出"}
const SPONSOR_KINDS := {"main": "主贊助", "apparel": "服裝贊助", "partner": "合作夥伴"}
const DEFAULT_SPONSOR_NAMES := ["Nova Energy", "Quantum Peripherals", "Skyline Telecom", "Aurora Drinks", "Vertex Motors",
	"Pixelforge", "Lumen Bank", "Harbor Logistics", "Crest Apparel", "Zenith Cloud", "Echo Audio", "Summit Snacks"]


static func earn(club: Club, key: String, amount: int) -> void:
	club.cash += amount
	if not club.ledger.has("income"):
		club.ledger["income"] = {}
	var inc: Dictionary = club.ledger["income"]
	inc[key] = int(inc.get(key, 0)) + amount


static func spend(club: Club, key: String, amount: int) -> void:
	club.cash -= amount
	if not club.ledger.has("expense"):
		club.ledger["expense"] = {}
	var out: Dictionary = club.ledger["expense"]
	out[key] = int(out.get(key, 0)) + amount


static func league_share(lg: League) -> int:
	return int(lg.format.get("revenue_share", 250000)) if lg else 250000


## 周邊商品：粉絲數 × 外界評價（評價好時周邊賣得更好）。
static func merch_per_year(club: Club) -> int:
	return int(club.fanbase * 0.5 * (1.0 + club.opinion / 400.0))


static func media_per_year(club: Club) -> int:
	return int(club.reputation * club.reputation * 60.0)


static func sponsor_per_year(club: Club) -> int:
	var total := 0
	for s in club.sponsors:
		total += int(s["yearly"])
	return total


## 預估年度收入（不含獎金與轉會），供介面與 AI 預算參考。
static func projected_income(w: WorldState, club: Club) -> int:
	return league_share(w.leagues.get(club.league_id)) + merch_per_year(club) + media_per_year(club) + sponsor_per_year(club)


static func weekly(w: WorldState, club: Club) -> void:
	earn(club, "league_share", league_share(w.leagues.get(club.league_id)) / 52)
	earn(club, "merch", merch_per_year(club) / 52)
	earn(club, "media", media_per_year(club) / 52)
	earn(club, "sponsors", sponsor_per_year(club) / 52)
	spend(club, "player_wages", TransferMarket.wage_bill(w, club) / 52)
	spend(club, "staff_wages", StaffSystem.wage_bill(w, club) / 52)
	spend(club, "operations", operations_per_year(club) / 52)


## 營運成本：場館、設備、行政人員、內容團隊；規模越大的俱樂部越高。
static func operations_per_year(club: Club) -> int:
	return int(150000 + club.reputation * 10000.0 + club.fanbase * 0.1)


# ---------------------------------------------------------------- 贊助

## 一份贊助報價的年度金額基準：由聲望與粉絲決定。
static func sponsor_value(club: Club, kind: String) -> int:
	var base = 50000.0 + club.reputation * 13000.0 + club.fanbase * 0.15
	return int(base * {"main": 1.0, "apparel": 0.35, "partner": 0.2}.get(kind, 0.2))


## 產生某個贊助位置的 3 種報價：穩定型、績效型、長約型。
static func make_offers(w: WorldState, club: Club, kind: String) -> Array:
	var names: Array = w.names.get("sponsors", DEFAULT_SPONSOR_NAMES)
	var v = sponsor_value(club, kind) * w.rng.range_f(0.9, 1.1)
	var lg: League = w.leagues.get(club.league_id)
	var teams = lg.club_ids.size() if lg else 8
	var expected = clampi(int(round((1.0 - club.reputation / 100.0) * teams)) + 1, 1, teams)
	var offers: Array = []
	offers.append({"kind": kind, "style": "safe", "name": str(w.rng.pick(names)), "yearly": int(v), "years": 1,
		"bonus_title": 0, "bonus_playoffs": 0, "target": 0})
	offers.append({"kind": kind, "style": "performance", "name": str(w.rng.pick(names)), "yearly": int(v * 0.7), "years": 1,
		"bonus_title": int(v * 0.9), "bonus_playoffs": int(v * 0.35), "target": expected})
	offers.append({"kind": kind, "style": "long", "name": str(w.rng.pick(names)), "yearly": int(v * 0.9), "years": 3,
		"bonus_title": int(v * 0.2), "bonus_playoffs": 0, "target": 0})
	return offers


static func style_name(style: String) -> String:
	return {"safe": "穩定型", "performance": "績效型", "long": "長約型"}.get(style, style)


static func sign_sponsor(w: WorldState, club: Club, offer: Dictionary) -> void:
	club.sponsors = club.sponsors.filter(func(s): return s["kind"] != offer["kind"])
	var deal = offer.duplicate()
	deal["end_year"] = w.year + int(offer["years"]) - 1
	club.sponsors.append(deal)
	club.sponsor_offers = club.sponsor_offers.filter(func(o): return o["kind"] != offer["kind"])
	w.log.add("sponsor_signed", w.day, [club.id], {"name": offer["name"], "kind": offer["kind"], "yearly": offer["yearly"]}, [])


## 休賽季：到期贊助移除並發出新報價。AI 直接簽下期望值最高的；玩家在財務頁面選擇。
static func offseason_sponsors(w: WorldState, club: Club) -> void:
	club.sponsors = club.sponsors.filter(func(s): return int(s["end_year"]) > w.year)
	club.sponsor_offers.clear()
	for kind in SPONSOR_KINDS:
		if club.sponsors.any(func(s): return s["kind"] == kind):
			continue
		var offers = make_offers(w, club, kind)
		if club.is_human:
			club.sponsor_offers.append_array(offers)
		else:
			var best = offers[0]
			if club.philosophy == "win_now":
				best = offers[1]
			elif club.philosophy in ["develop", "moneyball"]:
				best = offers[2]
			sign_sponsor(w, club, best)
	if club.is_human and not club.sponsor_offers.is_empty():
		w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "sponsor_offers", "player_id": "",
			"text": "有 %d 份新的贊助報價，請到「財務」頁面選擇。開季前未選擇將自動簽下穩定型合約。" % club.sponsor_offers.size(),
			"resolved": false, "options": ["acknowledge"]})


## 開季：玩家未選的贊助位置自動簽穩定型。
static func auto_sign_remaining(w: WorldState, club: Club) -> void:
	var kinds := {}
	for o in club.sponsor_offers:
		kinds[o["kind"]] = true
	for kind in kinds:
		for o in club.sponsor_offers.duplicate():
			if o["kind"] == kind and o["style"] == "safe":
				sign_sponsor(w, club, o)
				break
	club.sponsor_offers.clear()


## 賽季結束：績效獎金。
static func pay_bonuses(w: WorldState, club: Club, position: int, champion: bool, made_playoffs: bool) -> void:
	for s in club.sponsors:
		var bonus := 0
		if champion:
			bonus += int(s.get("bonus_title", 0))
		if made_playoffs or (int(s.get("target", 0)) > 0 and position <= int(s["target"])):
			bonus += int(s.get("bonus_playoffs", 0))
		if bonus > 0:
			earn(club, "sponsor_bonus", bonus)


## 封存本季帳本。
static func close_season(w: WorldState, club: Club) -> void:
	# AI 俱樂部的投資方會把超過 3 年薪資預算的現金抽走 25%（分紅），避免資金無限累積
	if not club.is_human:
		var excess = club.cash - club.wage_budget * 3
		if excess > 0:
			spend(club, "dividends", int(excess * 0.25))
	var entry = {"year": w.year, "income": club.ledger.get("income", {}), "expense": club.ledger.get("expense", {}), "cash_end": club.cash}
	club.finance_log.append(entry)
	if club.finance_log.size() > 15:
		club.finance_log.pop_front()
	club.ledger = {"income": {}, "expense": {}}


static func totals(ledger: Dictionary) -> Dictionary:
	var inc := 0
	var out := 0
	for v in ledger.get("income", {}).values():
		inc += int(v)
	for v in ledger.get("expense", {}).values():
		out += int(v)
	return {"income": inc, "expense": out, "net": inc - out}


## 粉絲變化：成績、冠軍、聲望。
static func update_fanbase(club: Club, position: int, teams: int, champion: bool) -> void:
	var rel = 1.0 - float(position - 1) / maxf(teams - 1, 1)   # 1 = 第一名
	var growth = (rel - 0.45) * 0.12 + (0.15 if champion else 0.0)
	club.fanbase = maxi(int(club.fanbase * (1.0 + growth)) + int(club.reputation * 300), 5000)
