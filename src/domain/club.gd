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
var finance_log: Array = []


static func from_dict(d: Dictionary) -> Club:
	var c := Club.new()
	for k in d:
		if k in c:
			c.set(k, d[k])
	c.cash = int(c.cash)
	c.wage_budget = int(c.wage_budget)
	c.fanbase = int(c.fanbase)
	c.titles = int(c.titles)
	return c


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "short_name": short_name, "region": region,
		"league_id": league_id, "is_human": is_human, "cash": cash, "wage_budget": wage_budget,
		"reputation": reputation, "fanbase": fanbase, "philosophy": philosophy,
		"roster": roster, "coach_id": coach_id, "tactics": tactics, "lineup": lineup,
		"chemistry": chemistry, "draft_familiarity": draft_familiarity,
		"training_plan": training_plan, "history": history, "titles": titles,
		"finance_log": finance_log}
