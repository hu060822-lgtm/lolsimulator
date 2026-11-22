## 陣容分析：把五隻英雄的標籤轉換成「陣容原型分佈」、時間曲線與缺陷。
## 原型之間存在剋制循環，因此陣容強弱是相對於對手的，而不是單純加總。
class_name CompAnalyzer
extends RefCounted

const ARCHETYPES := ["engage", "pick", "poke", "protect", "split", "teamfight"]

## 剋制矩陣 M[a][b] > 0 代表原型 a 對 b 有利。
## 設計：開戰 > 消耗、消耗 > 保護、保護 > 開戰；抓單 > 分推、分推 > 團戰、團戰 > 抓單。
const COUNTERS := {
	"engage": {"poke": 1.0, "protect": -1.0, "pick": 0.3, "split": 0.4},
	"poke": {"protect": 1.0, "engage": -1.0, "split": -0.3},
	"protect": {"engage": 1.0, "poke": -1.0, "pick": 0.5},
	"pick": {"split": 1.0, "teamfight": -1.0, "protect": -0.5, "poke": 0.3},
	"split": {"teamfight": 1.0, "pick": -1.0, "engage": -0.4, "poke": 0.3},
	"teamfight": {"pick": 1.0, "split": -1.0},
}


static var _single_cache: Dictionary = {}


static func analyze(champs: Array) -> Dictionary:
	return analyze_acc(accumulate(champs))


## 單一英雄的分析結果（BP 評估禁用時大量使用，結果只取決於英雄資料，可以快取）。
static func analyze_single(c: Champion) -> Dictionary:
	var key = c.id
	if not _single_cache.has(key):
		_single_cache[key] = analyze([c])
	return _single_cache[key]


## 累加陣容的標籤與曲線；BP 時先累加已選英雄，再逐一加入候選英雄（避免重算整個陣容）。
static func accumulate(champs: Array) -> Dictionary:
	var t := {}
	for tag in Champion.TAGS:
		t[tag] = 0.0
	var acc = {"t": t, "ad": 0, "ap": 0, "early": 0.0, "mid": 0.0, "late": 0.0, "n": 0}
	for c in champs:
		_add(acc, c)
	return acc


static func _add(acc: Dictionary, c: Champion) -> void:
	var t: Dictionary = acc["t"]
	for tag in c.tags:
		t[tag] = float(t.get(tag, 0.0)) + float(c.tags[tag])
	if c.damage == "AD":
		acc["ad"] += 1
	elif c.damage == "AP":
		acc["ap"] += 1
	else:
		acc["ad"] += 1
		acc["ap"] += 1
	acc["early"] += c.early
	acc["mid"] += c.mid
	acc["late"] += c.late
	acc["n"] += 1


static func analyze_acc(base: Dictionary, extra: Champion = null) -> Dictionary:
	var acc := base
	if extra:
		acc = {"t": base["t"].duplicate(), "ad": base["ad"], "ap": base["ap"], "early": base["early"],
			"mid": base["mid"], "late": base["late"], "n": base["n"]}
		_add(acc, extra)
	var t: Dictionary = acc["t"]
	var ad: int = acc["ad"]
	var ap: int = acc["ap"]
	var early: float = acc["early"]
	var mid: float = acc["mid"]
	var late: float = acc["late"]
	var count: int = acc["n"]
	var n = maxf(count, 1)
	var raw = {
		"engage": t["engage"] * 1.0 + t["frontline"] * 0.3,
		"pick": t["pick"] * 1.0 + t["burst"] * 0.5 + t["mobility"] * 0.3,
		"poke": t["poke"] * 1.0 + t["siege"] * 0.6,
		"protect": t["peel"] * 1.0 + t["disengage"] * 0.6 + t["dps"] * 0.4,
		"split": t["splitpush"] * 1.2,
		"teamfight": t["teamfight"] * 1.0 + t["frontline"] * 0.3 + t["dps"] * 0.2,
	}
	var total := 0.0
	for a in raw:
		total += raw[a]
	var share := {}
	for a in raw:
		share[a] = raw[a] / total if total > 0 else 1.0 / ARCHETYPES.size()
	var primary := "teamfight"
	for a in share:
		if share[a] > share[primary]:
			primary = a
	# 缺陷：沒有前排、傷害類型單一、沒有開戰也沒有反開、沒有清線
	var flaws: Array = []
	var fit := 1.0
	if count >= 5:
		if t["frontline"] < 2.0:
			flaws.append("no_frontline")
			fit -= 0.08
		if ad == 0 or ap == 0:
			flaws.append("one_damage_type")
			fit -= 0.07
		if t["engage"] < 2.0 and t["disengage"] < 2.0:
			flaws.append("no_engage_or_disengage")
			fit -= 0.07
		if t["waveclear"] < 1.0:
			flaws.append("no_waveclear")
			fit -= 0.04
		# 專注度：原型越集中，戰術越清晰
		fit += (share[primary] - 0.25) * 0.3
	return {"share": share, "primary": primary, "tags": t, "fit": fit, "flaws": flaws,
		"early": early / n, "mid": mid / n, "late": late / n}


## 陣容 A 對陣容 B 的原型剋制值（約 -0.4..0.4）。
static func counter_score(a: Dictionary, b: Dictionary) -> float:
	var s := 0.0
	for x in a["share"]:
		var row: Dictionary = COUNTERS.get(x, {})
		for y in b["share"]:
			s += a["share"][x] * b["share"][y] * float(row.get(y, 0.0))
	return s


## 戰術方向與陣容原型的契合度（0..1）。
static func plan_fit(plan: String, comp: Dictionary) -> float:
	var share: Dictionary = comp["share"]
	match plan:
		"early_aggression":
			return clampf((comp["early"] - 5.0) / 3.0 * 0.5 + 0.5, 0.0, 1.0)
		"late_scaling":
			return clampf((comp["late"] - 5.0) / 3.0 * 0.5 + 0.5, 0.0, 1.0)
		"split_push":
			return clampf(share["split"] * 3.0, 0.0, 1.0)
		"teamfight":
			return clampf((share["teamfight"] + share["engage"]) * 1.6, 0.0, 1.0)
		"pick":
			return clampf(share["pick"] * 3.0, 0.0, 1.0)
		"poke_siege":
			return clampf(share["poke"] * 3.0, 0.0, 1.0)
		"protect":
			return clampf(share["protect"] * 3.0, 0.0, 1.0)
	return 0.5 + (comp["fit"] - 1.0)


## 根據陣容挑最適合的戰術方向（AI 與「flexible」教練使用）。
static func best_plan(comp: Dictionary) -> String:
	var best := "teamfight"
	var best_v := -1.0
	for plan in ["early_aggression", "late_scaling", "split_push", "teamfight", "pick", "poke_siege", "protect"]:
		var v = plan_fit(plan, comp)
		if v > best_v:
			best_v = v
			best = plan
	return best
