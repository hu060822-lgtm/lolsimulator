## 俱樂部。玩家俱樂部與 AI 俱樂部使用完全相同的資料結構與規則（is_human 只決定誰做決策）。
class_name Club
extends RefCounted

const PHILOSOPHIES := ["win_now", "develop", "balanced", "moneyball"]

var id: String
var name: String
var short_name: String
var region: String
var league_id: String
var is_human: bool = false
var cash: int = 1000000
var wage_budget: int = 600000        ## 年度薪資預算
var reputation: float = 50.0         ## 0..100
var fanbase: int = 50000
var philosophy: String = "balanced"
var roster: Array = []               ## player ids
var coach_id: String = ""
## 預設戰術：plan 為整體方向，與 BP 及比賽中的決策連動
var tactics: Dictionary = {"plan": "flexible", "aggression": 0.5}
var lineup: Dictionary = {}          ## role -> player_id（先發）
var chemistry: float = 50.0          ## 團隊默契 0..100
var draft_familiarity: float = 40.0  ## BP 演練熟悉度
var training_plan: Dictionary = {}
var history: Array = []              ## [{year, league_id, position, playoff_result, titles}]
var titles: int = 0
var world_titles: int = 0
var msi_titles: int = 0
var board_confidence: float = 60.0    ## 董事會信心 0..100（見 Organization）
var brand: float = 40.0               ## 品牌價值 0..100（見 Organization）
var crisis_flags: Dictionary = {}     ## 本季已觸發的危機（避免重複）
var opinion: float = 0.0             ## 外界評價 -100..100（見 Media）
var streak: int = 0                  ## 連勝（正）/ 連敗（負）
var finance_log: Array = []          ## 歷年帳本 [{year, income, expense, cash_end}]
var ledger: Dictionary = {"income": {}, "expense": {}}  ## 本季帳本
var staff: Dictionary = {}           ## 職位 -> staff_id（主教練仍用 coach_id）
var sponsors: Array = []             ## 生效中的贊助合約
var sponsor_offers: Array = []       ## 待選擇的贊助報價（玩家）
var scout_knowledge: Dictionary = {}  ## player_id -> 0..1（僅玩家俱樂部使用）


static func from_dict(d: Dictionary) -> Club:
	var c := Club.new()
	for k in d:
		if k in c:
			c.set(k, d[k])
	c.cash = int(c.cash)
	c.wage_budget = int(c.wage_budget)
	c.fanbase = int(c.fanbase)
	c.titles = int(c.titles)
	c.world_titles = int(c.world_titles)
	c.msi_titles = int(c.msi_titles)
	c.streak = int(c.streak)
	if c.short_name.strip_edges() == "":
		c.short_name = make_short_name(c.name)
	return c


## 自動產生縮寫：多字取字首（最多 4 碼），單字取前 3 碼。
static func make_short_name(full: String) -> String:
	var words = full.strip_edges().split(" ", false)
	if words.size() == 0:
		return "CLB"
	if words.size() == 1:
		return words[0].substr(0, 3).to_upper()
	var s := ""
	for wd in words.slice(0, 4):
		s += wd.substr(0, 1)
	return s.to_upper()


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "short_name": short_name, "region": region,
		"league_id": league_id, "is_human": is_human, "cash": cash, "wage_budget": wage_budget,
		"reputation": reputation, "fanbase": fanbase, "philosophy": philosophy,
		"roster": roster, "coach_id": coach_id, "tactics": tactics, "lineup": lineup,
		"chemistry": chemistry, "draft_familiarity": draft_familiarity,
		"training_plan": training_plan, "history": history, "titles": titles, "world_titles": world_titles, "msi_titles": msi_titles, "opinion": opinion, "board_confidence": board_confidence, "brand": brand, "crisis_flags": crisis_flags, "streak": streak,
		"finance_log": finance_log, "scout_knowledge": scout_knowledge,
		"ledger": ledger, "staff": staff, "sponsors": sponsors, "sponsor_offers": sponsor_offers}
