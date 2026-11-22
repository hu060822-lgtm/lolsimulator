## 版本狀態：每個英雄的版本強度修正（-2..+2）。世界模擬每個賽季會產生新版本。
class_name PatchState
extends RefCounted

var version: String = "1.0"
var tiers: Dictionary = {}   ## champion_id -> -2..2


func meta(champ_id: String) -> float:
	return float(tiers.get(champ_id, 0.0))


func to_dict() -> Dictionary:
	return {"version": version, "tiers": tiers}


static func from_dict(d: Dictionary) -> PatchState:
	var p := PatchState.new()
	p.version = d.get("version", "1.0")
	p.tiers = d.get("tiers", {})
	return p
