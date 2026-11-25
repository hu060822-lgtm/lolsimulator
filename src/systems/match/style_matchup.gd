## 打法互剋：七種戰術方向排成一個循環，每種打法剋制後面兩種、被前面兩種剋制。
##
## 這讓「選對戰術」成為可以準備的決策：先看賽前情報知道對手的招牌打法，
## 再挑一個剋制它的方向（同時要和自己的英雄池相符）。
## 剋制優勢在比賽前段最明顯，26 分鐘後雙方都已調整，效果減半（見 MatchEngine._side_multiplier）。
class_name StyleMatchup
extends RefCounted

const CYCLE := ["early_aggression", "late_scaling", "poke_siege", "teamfight", "split_push", "pick", "protect"]
const EDGE := 0.05  ## 剋制方的戰力加成（被剋制方對稱扣除）

## 「A 剋制 B」的理由（以 A 的角度描述）。
const WHY := {
	"early_aggression": {"late_scaling": "前期壓制讓對手發育不起來", "poke_siege": "消耗陣容前期弱，被強開就崩"},
	"late_scaling": {"poke_siege": "穩定清線，撐過消耗後反打", "teamfight": "拖到後期團戰我方更強"},
	"poke_siege": {"teamfight": "開團前先把對手血量磨掉", "split_push": "四人壓塔，逼分推者回防"},
	"teamfight": {"split_push": "五打四直接強開", "pick": "抱團行動，不給抓單機會"},
	"split_push": {"pick": "邊線牽制，讓對手抓不到人", "protect": "保護陣容處理不了邊路壓力"},
	"pick": {"protect": "繞過前排先抓核心", "early_aggression": "視野反蹲，前期入侵反被抓"},
	"protect": {"early_aggression": "前排與保護技能化解衝塔", "late_scaling": "核心輸出受保護，後期更穩"},
}


## a 對 b 的剋制關係：+1 剋制、-1 被剋制、0 無明顯關係（含 flexible 或相同打法）。
static func relation(a: String, b: String) -> int:
	var ia = CYCLE.find(a)
	var ib = CYCLE.find(b)
	if ia < 0 or ib < 0 or ia == ib:
		return 0
	var d = (ib - ia + CYCLE.size()) % CYCLE.size()
	if d == 1 or d == 2:
		return 1
	if d == CYCLE.size() - 1 or d == CYCLE.size() - 2:
		return -1
	return 0


static func edge(a: String, b: String) -> float:
	return EDGE * relation(a, b)


## 剋制 plan 的打法（兩種）。
static func counters_of(plan: String) -> Array:
	return CYCLE.filter(func(x): return relation(x, plan) == 1)


## 被 plan 剋制的打法。
static func beaten_by(plan: String) -> Array:
	return CYCLE.filter(func(x): return relation(plan, x) == 1)


static func reason(a: String, b: String) -> String:
	if relation(a, b) == 1:
		return WHY.get(a, {}).get(b, "打法相剋")
	if relation(a, b) == -1:
		return WHY.get(b, {}).get(a, "打法相剋")
	return ""


## 從剋制 opp 的打法中，挑和自己陣容（comp，可為空）最契合的一個。
static func best_counter(opp: String, comp: Dictionary = {}) -> String:
	var opts = counters_of(opp)
	if opts.is_empty():
		return ""
	if comp.is_empty():
		return opts[0]
	var best: String = opts[0]
	var best_v = -INF
	for p in opts:
		var v = CompAnalyzer.plan_fit(p, comp)
		if v > best_v:
			best_v = v
			best = p
	return best
