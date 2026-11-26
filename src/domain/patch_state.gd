## 版本狀態：每個英雄的版本強度修正（-2..+2）。世界模擬每個賽季會產生新版本。
class_name PatchState
extends RefCounted

var version: String = "1.0"
var tiers: Dictionary = {}   ## champion_id -> -2..2
var meta_plan: String = ""   ## 版本答案打法（StyleMatchup.CYCLE 其中之一），見 MetaRace
var started_day: int = 0     ## 版本上線的日子


func meta(champ_id: String) -> float:
	return float(tiers.get(champ_id, 0.0))


func to_dict() -> Dictionary:
	return {"version": version, "tiers": tiers, "meta_plan": meta_plan, "started_day": started_day}


## 版本強勢英雄（tier 2），依 id 排序。
func strong() -> Array:
	var out: Array = tiers.keys().filter(func(c): return float(tiers[c]) >= 2.0)
	out.sort()
	return out


static func from_dict(d: Dictionary) -> PatchState:
	var p := PatchState.new()
	p.version = d.get("version", "1.0")
	p.tiers = d.get("tiers", {})
	p.meta_plan = str(d.get("meta_plan", ""))
	p.started_day = int(d.get("started_day", 0))
	return p
