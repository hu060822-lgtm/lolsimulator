## 英雄資料（來自資料模組，引擎只看標籤與曲線，不看名稱）。
class_name Champion
extends RefCounted

## 標籤：0–3 的強度。比賽引擎與 BP 引擎只透過這些標籤理解英雄。
const TAGS := ["engage", "disengage", "poke", "pick", "splitpush", "teamfight", "peel", "frontline", "burst", "dps", "waveclear", "mobility", "siege"]

var id: String
var name: String
var roles: Array = []
var tags: Dictionary = {}
var early: float = 5.0  ## 1–10 前期強度
var mid: float = 5.0
var late: float = 5.0
var lane: float = 5.0   ## 對線強度
var damage: String = "AD"
var difficulty: float = 5.0


static func from_dict(d: Dictionary) -> Champion:
	var c := Champion.new()
	c.id = d["id"]
	c.name = d.get("name", c.id)
	c.roles = d.get("roles", [])
	c.tags = d.get("tags", {})
	var curve: Dictionary = d.get("curve", {})
	c.early = float(curve.get("early", 5))
	c.mid = float(curve.get("mid", 5))
	c.late = float(curve.get("late", 5))
	c.lane = float(d.get("lane", 5))
	c.damage = d.get("damage", "AD")
	c.difficulty = float(d.get("difficulty", 5))
	return c


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "roles": roles, "tags": tags,
		"curve": {"early": early, "mid": mid, "late": late}, "lane": lane,
		"damage": damage, "difficulty": difficulty}


func tag(t: String) -> float:
	return float(tags.get(t, 0))


## 某分鐘的英雄強度（0.5–1.5 左右），內插前/中/後期曲線。
func power_at(minute: float) -> float:
	var v: float
	if minute <= 14.0:
		v = lerpf(early, mid, minute / 14.0 * 0.5)
	elif minute <= 26.0:
		v = lerpf(lerpf(early, mid, 0.5), mid, (minute - 14.0) / 12.0)
	else:
		v = lerpf(mid, late, clampf((minute - 26.0) / 12.0, 0.0, 1.0))
	return 0.6 + v / 10.0 * 0.8
