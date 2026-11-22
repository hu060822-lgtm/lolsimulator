## 召喚峽谷的簡化幾何：給比賽引擎記錄選手位置，也給 UI 畫地圖。
##
## 座標為 0..1 的正規化座標，(0,0) 為左上角。藍方主堡在左下、紅方主堡在右上。
## 兵線以「從藍方主堡到紅方主堡」的折線表示，t = 0 為藍方主堡、t = 1 為紅方主堡。
class_name RiftGeometry
extends RefCounted

const LANE_PATHS := {
	"top": [Vector2(0.13, 0.80), Vector2(0.085, 0.55), Vector2(0.085, 0.14), Vector2(0.14, 0.085), Vector2(0.45, 0.085), Vector2(0.80, 0.13)],
	"mid": [Vector2(0.17, 0.83), Vector2(0.83, 0.17)],
	"bot": [Vector2(0.20, 0.87), Vector2(0.55, 0.915), Vector2(0.86, 0.915), Vector2(0.915, 0.86), Vector2(0.915, 0.45), Vector2(0.87, 0.20)],
}
## 藍方各路防禦塔位置（外塔 → 二塔 → 高地塔 → 兵營），紅方為 1 - t。
const TOWER_T := [0.36, 0.24, 0.13, 0.08]
const FOUNTAIN := {"blue": Vector2(0.045, 0.955), "red": Vector2(0.955, 0.045)}
const NEXUS := {"blue": Vector2(0.11, 0.89), "red": Vector2(0.89, 0.11)}
const NEXUS_TOWERS := {"blue": [Vector2(0.125, 0.855), Vector2(0.145, 0.875)], "red": [Vector2(0.875, 0.145), Vector2(0.855, 0.125)]}
const DRAGON_PIT := Vector2(0.675, 0.705)
const BARON_PIT := Vector2(0.325, 0.295)
const RIVER := [Vector2(0.10, 0.10), Vector2(0.30, 0.28), Vector2(0.50, 0.50), Vector2(0.72, 0.70), Vector2(0.90, 0.90)]
## 野區營地（藍方在左下兩塊、紅方在右上兩塊）
const CAMPS := {
	"blue": [Vector2(0.26, 0.48), Vector2(0.23, 0.60), Vector2(0.48, 0.74), Vector2(0.56, 0.80)],
	"red": [Vector2(0.74, 0.52), Vector2(0.77, 0.40), Vector2(0.52, 0.26), Vector2(0.44, 0.20)],
}


static func lane_point(lane: String, t: float) -> Vector2:
	var pts: Array = LANE_PATHS.get(lane, LANE_PATHS["mid"])
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] - pts[i - 1]).length()
	var d = clampf(t, 0.0, 1.0) * total
	for i in range(1, pts.size()):
		var seg = (pts[i] - pts[i - 1]).length()
		if d <= seg:
			return pts[i - 1].lerp(pts[i], d / maxf(seg, 0.0001))
		d -= seg
	return pts[-1]


## 第 index 座塔（0 = 外塔，3 = 兵營）的位置。
static func tower_point(side: String, lane: String, index: int) -> Vector2:
	var t: float = TOWER_T[clampi(index, 0, 3)]
	return lane_point(lane, t if side == "blue" else 1.0 - t)


## 兵線交戰點：依線權推進，但不會越過雙方仍存活的第一座塔。
## blue_lost / red_lost = 該路被摧毀的建築數。
static func lane_front(lane: String, blue_priority: float, blue_lost: int, red_lost: int) -> float:
	var t = 0.5 + blue_priority * 0.12 + (red_lost - blue_lost) * 0.07
	var blue_guard: float = TOWER_T[mini(blue_lost, 3)] + 0.04   # 紅方最多推到藍方下一座塔前
	var red_guard: float = 1.0 - TOWER_T[mini(red_lost, 3)] - 0.04
	if blue_lost >= 4:
		blue_guard = 0.06
	if red_lost >= 4:
		red_guard = 0.94
	return clampf(t, blue_guard, red_guard)


## 同一地點多名選手時的排列偏移（確定性，不使用亂數）。
static func spread(index: int, count: int, radius: float = 0.028) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var a = TAU * float(index) / float(count) + 0.6
	return Vector2(cos(a), sin(a)) * radius
