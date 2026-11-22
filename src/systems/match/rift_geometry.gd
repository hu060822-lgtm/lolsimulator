## 召喚峽谷的簡化幾何：給比賽引擎記錄選手位置，也給 UI 畫地圖。
##
## 座標為 0..1 的正規化座標，(0,0) 為左上角，依 assets/maps/summoners_rift.jpg 標定。藍方主堡在左下、紅方主堡在右上。
## 兵線以「從藍方主堡到紅方主堡」的折線表示，t = 0 為藍方主堡、t = 1 為紅方主堡。
class_name RiftGeometry
extends RefCounted

const LANE_PATHS := {
	"top": [Vector2(0.098, 0.820), Vector2(0.093, 0.752), Vector2(0.098, 0.283), Vector2(0.107, 0.127), Vector2(0.166, 0.070), Vector2(0.322, 0.066), Vector2(0.552, 0.093), Vector2(0.718, 0.080), Vector2(0.840, 0.107)],
	"mid": [Vector2(0.146, 0.850), Vector2(0.261, 0.735), Vector2(0.358, 0.660), Vector2(0.410, 0.552), Vector2(0.618, 0.405), Vector2(0.672, 0.303), Vector2(0.762, 0.231), Vector2(0.854, 0.137)],
	"bot": [Vector2(0.137, 0.884), Vector2(0.240, 0.918), Vector2(0.299, 0.916), Vector2(0.483, 0.896), Vector2(0.734, 0.933), Vector2(0.884, 0.913), Vector2(0.939, 0.859), Vector2(0.959, 0.686), Vector2(0.926, 0.420), Vector2(0.924, 0.273), Vector2(0.884, 0.146)],
}
## 各方各路的建築位置（外塔、二塔、高地塔、兵營），依實際峽谷地圖標定。
const TOWERS := {"blue": {"top": [Vector2(0.098, 0.283), Vector2(0.122, 0.535), Vector2(0.095, 0.699), Vector2(0.090, 0.753)], "mid": [Vector2(0.410, 0.552), Vector2(0.358, 0.660), Vector2(0.261, 0.735), Vector2(0.227, 0.777)], "bot": [Vector2(0.734, 0.936), Vector2(0.483, 0.894), Vector2(0.299, 0.916), Vector2(0.240, 0.921)]}, "red": {"top": [Vector2(0.322, 0.063), Vector2(0.552, 0.098), Vector2(0.715, 0.078), Vector2(0.763, 0.080)], "mid": [Vector2(0.618, 0.405), Vector2(0.672, 0.303), Vector2(0.762, 0.231), Vector2(0.788, 0.205)], "bot": [Vector2(0.959, 0.686), Vector2(0.910, 0.420), Vector2(0.924, 0.273), Vector2(0.919, 0.231)]}}
## 舊版的平均塔位（t 值），僅供參考；實際判斷改用 tower_t()。
const TOWER_T := [0.36, 0.24, 0.13, 0.08]
const FOUNTAIN := {"blue": Vector2(0.055, 0.940), "red": Vector2(0.945, 0.055)}
const NEXUS := {"blue": Vector2(0.111, 0.887), "red": Vector2(0.891, 0.104)}
const NEXUS_TOWERS := {"blue": [Vector2(0.126, 0.841), Vector2(0.156, 0.875)], "red": [Vector2(0.852, 0.112), Vector2(0.882, 0.142)]}
const DRAGON_PIT := Vector2(0.674, 0.703)
const BARON_PIT := Vector2(0.322, 0.293)
const RIVER := [Vector2(0.186, 0.195), Vector2(0.322, 0.293), Vector2(0.500, 0.493), Vector2(0.674, 0.703), Vector2(0.820, 0.801)]
## 野區營地（藍方：左側與下方野區；紅方：右側與上方野區）
const CAMPS := {
	"blue": [Vector2(0.171, 0.449), Vector2(0.249, 0.469), Vector2(0.259, 0.571), Vector2(0.469, 0.630), Vector2(0.527, 0.737), Vector2(0.562, 0.840)],
	"red": [Vector2(0.829, 0.542), Vector2(0.751, 0.522), Vector2(0.741, 0.420), Vector2(0.531, 0.361), Vector2(0.473, 0.254), Vector2(0.438, 0.151)],
}

static var _tower_t_cache: Dictionary = {}


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
	return TOWERS[side][lane][clampi(index, 0, 3)]


## 建築在兵線上的位置（0 = 藍方主堡端，1 = 紅方主堡端）。
static func tower_t(side: String, lane: String, index: int) -> float:
	var key = "%s:%s:%d" % [side, lane, index]
	if not _tower_t_cache.has(key):
		_tower_t_cache[key] = project(lane, tower_point(side, lane, index))
	return _tower_t_cache[key]


## 把地圖上的點投影到兵線上，回傳最接近的 t。
static func project(lane: String, p: Vector2) -> float:
	var pts: Array = LANE_PATHS.get(lane, LANE_PATHS["mid"])
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] - pts[i - 1]).length()
	var best_d := INF
	var best_t := 0.0
	var acc := 0.0
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg = (b - a).length()
		var u = clampf((p - a).dot(b - a) / maxf(seg * seg, 0.000001), 0.0, 1.0)
		var d = p.distance_to(a.lerp(b, u))
		if d < best_d:
			best_d = d
			best_t = (acc + u * seg) / total
		acc += seg
	return best_t


## 兵線交戰點：依線權推進，但不會越過雙方仍存活的第一座塔。
## blue_lost / red_lost = 該路被摧毀的建築數。
static func lane_front(lane: String, blue_priority: float, blue_lost: int, red_lost: int) -> float:
	var center = (tower_t("blue", lane, 0) + tower_t("red", lane, 0)) / 2.0
	var t = center + blue_priority * 0.12 + (red_lost - blue_lost) * 0.07
	var blue_guard: float = tower_t("blue", lane, mini(blue_lost, 3)) + 0.04   # 紅方最多推到藍方下一座塔前
	var red_guard: float = tower_t("red", lane, mini(red_lost, 3)) - 0.04
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
