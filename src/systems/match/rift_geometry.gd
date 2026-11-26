## 召喚峽谷的簡化幾何：給比賽引擎記錄選手位置，也給 UI 畫地圖。
##
## 座標為 0..1 的正規化座標，(0,0) 為左上角，依 assets/maps/summoners_rift.jpg 標定。藍方主堡在左下、紅方主堡在右上。
## 兵線以「從藍方主堡到紅方主堡」的折線表示，t = 0 為藍方主堡、t = 1 為紅方主堡。
class_name RiftGeometry
extends RefCounted

const LANE_PATHS := {
	"top": [Vector2(0.098, 0.820), Vector2(0.093, 0.752), Vector2(0.098, 0.283), Vector2(0.107, 0.127), Vector2(0.166, 0.070), Vector2(0.322, 0.066), Vector2(0.552, 0.093), Vector2(0.718, 0.080), Vector2(0.840, 0.107)],
	"mid": [Vector2(0.146, 0.850), Vector2(0.261, 0.735), Vector2(0.391, 0.605), Vector2(0.500, 0.496), Vector2(0.615, 0.381), Vector2(0.762, 0.231), Vector2(0.854, 0.137)],
	"bot": [Vector2(0.137, 0.884), Vector2(0.240, 0.918), Vector2(0.299, 0.916), Vector2(0.483, 0.896), Vector2(0.734, 0.933), Vector2(0.884, 0.913), Vector2(0.939, 0.859), Vector2(0.959, 0.686), Vector2(0.926, 0.420), Vector2(0.924, 0.273), Vector2(0.884, 0.146)],
}
## 各方各路的建築位置（外塔、二塔、高地塔、兵營），依實際峽谷地圖標定。
const TOWERS := {"blue": {"top": [Vector2(0.098, 0.283), Vector2(0.122, 0.535), Vector2(0.095, 0.699), Vector2(0.090, 0.753)], "mid": [Vector2(0.410, 0.552), Vector2(0.358, 0.660), Vector2(0.261, 0.735), Vector2(0.227, 0.777)], "bot": [Vector2(0.734, 0.936), Vector2(0.483, 0.894), Vector2(0.299, 0.916), Vector2(0.240, 0.921)]}, "red": {"top": [Vector2(0.322, 0.063), Vector2(0.552, 0.098), Vector2(0.715, 0.078), Vector2(0.763, 0.080)], "mid": [Vector2(0.618, 0.405), Vector2(0.672, 0.303), Vector2(0.762, 0.231), Vector2(0.788, 0.205)], "bot": [Vector2(0.959, 0.686), Vector2(0.910, 0.420), Vector2(0.924, 0.273), Vector2(0.919, 0.231)]}}
## 舊版的平均塔位（t 值），僅供參考；實際判斷改用 tower_t()。
const TOWER_T := [0.36, 0.24, 0.13, 0.08]
const FOUNTAIN := {"blue": Vector2(0.055, 0.940), "red": Vector2(0.945, 0.055)}
const NEXUS := {"blue": Vector2(0.111, 0.887), "red": Vector2(0.891, 0.104)}
const NEXUS_TOWERS := {"blue": [Vector2(0.126, 0.841), Vector2(0.156, 0.875)], "red": [Vector2(0.852, 0.112), Vector2(0.882, 0.142)]}
## 藍方常見插眼點（由安全到深入）；紅方以地圖中心對稱。
const WARD_SPOTS := [Vector2(0.300, 0.520), Vector2(0.560, 0.790), Vector2(0.625, 0.655), Vector2(0.365, 0.335), Vector2(0.470, 0.470), Vector2(0.800, 0.860), Vector2(0.175, 0.200), Vector2(0.700, 0.560), Vector2(0.450, 0.230)]
const DRAGON_PIT := Vector2(0.674, 0.703)
const BARON_PIT := Vector2(0.322, 0.293)
const RIVER := [Vector2(0.186, 0.195), Vector2(0.322, 0.293), Vector2(0.500, 0.493), Vector2(0.674, 0.703), Vector2(0.820, 0.801)]
## 野區營地（藍方：左側與下方野區；紅方：右側與上方野區）
const CAMPS := {
	"blue": [Vector2(0.171, 0.449), Vector2(0.249, 0.469), Vector2(0.259, 0.571), Vector2(0.469, 0.630), Vector2(0.527, 0.737), Vector2(0.562, 0.840)],
	"red": [Vector2(0.829, 0.542), Vector2(0.751, 0.522), Vector2(0.741, 0.420), Vector2(0.531, 0.361), Vector2(0.473, 0.254), Vector2(0.438, 0.151)],
}

## 路網：兵線、河道、野區小路的節點（依峽谷底圖標定，產生器見 tools/rift_nav_graph.py）。
## 地圖上的棋子沿路網移動，而不是直線穿牆。
const NAV_NODES := [Vector2(0.098, 0.820), Vector2(0.093, 0.752), Vector2(0.098, 0.283), Vector2(0.107, 0.127), Vector2(0.166, 0.070), Vector2(0.322, 0.066), Vector2(0.552, 0.093), Vector2(0.718, 0.080), Vector2(0.840, 0.107), Vector2(0.146, 0.850), Vector2(0.261, 0.735), Vector2(0.391, 0.605), Vector2(0.439, 0.557), Vector2(0.562, 0.435), Vector2(0.615, 0.381), Vector2(0.762, 0.231), Vector2(0.854, 0.137), Vector2(0.137, 0.884), Vector2(0.240, 0.918), Vector2(0.299, 0.916), Vector2(0.483, 0.896), Vector2(0.734, 0.933), Vector2(0.884, 0.913), Vector2(0.939, 0.859), Vector2(0.959, 0.686), Vector2(0.926, 0.420), Vector2(0.924, 0.273), Vector2(0.884, 0.146), Vector2(0.096, 0.488), Vector2(0.439, 0.078), Vector2(0.500, 0.496), Vector2(0.605, 0.913), Vector2(0.942, 0.547), Vector2(0.111, 0.887), Vector2(0.054, 0.939), Vector2(0.891, 0.104), Vector2(0.945, 0.055), Vector2(0.146, 0.146), Vector2(0.249, 0.239), Vector2(0.381, 0.327), Vector2(0.444, 0.410), Vector2(0.557, 0.576), Vector2(0.625, 0.664), Vector2(0.752, 0.752), Vector2(0.850, 0.845), Vector2(0.322, 0.293), Vector2(0.674, 0.703), Vector2(0.171, 0.449), Vector2(0.829, 0.542), Vector2(0.249, 0.469), Vector2(0.751, 0.522), Vector2(0.259, 0.571), Vector2(0.741, 0.420), Vector2(0.205, 0.527), Vector2(0.795, 0.464), Vector2(0.322, 0.410), Vector2(0.678, 0.581), Vector2(0.469, 0.630), Vector2(0.531, 0.361), Vector2(0.527, 0.737), Vector2(0.473, 0.254), Vector2(0.562, 0.840), Vector2(0.438, 0.151), Vector2(0.459, 0.723), Vector2(0.541, 0.269), Vector2(0.586, 0.625), Vector2(0.414, 0.366)]
## 路網邊（節點索引兩兩一組）
const NAV_EDGES := [0, 1, 1, 2, 3, 4, 4, 5, 6, 7, 7, 8, 9, 10, 10, 11, 11, 12, 13, 14, 14, 15, 15, 16, 17, 18, 18, 19, 19, 20, 20, 21, 22, 23, 23, 24, 25, 26, 26, 27, 2, 28, 28, 3, 5, 29, 29, 6, 12, 30, 30, 13, 21, 31, 31, 22, 24, 32, 32, 25, 34, 33, 36, 35, 33, 0, 33, 9, 33, 17, 35, 8, 35, 16, 35, 27, 37, 38, 38, 39, 39, 40, 41, 42, 42, 43, 43, 44, 40, 30, 30, 41, 37, 3, 44, 23, 45, 38, 45, 39, 46, 42, 46, 43, 47, 49, 48, 50, 49, 53, 50, 54, 53, 51, 54, 52, 47, 28, 48, 32, 49, 55, 50, 56, 55, 39, 56, 42, 55, 40, 56, 41, 51, 11, 52, 14, 53, 1, 54, 25, 57, 12, 58, 13, 57, 65, 58, 66, 65, 41, 66, 40, 65, 42, 66, 39, 57, 63, 58, 64, 63, 59, 64, 60, 59, 61, 60, 62, 61, 31, 62, 29, 63, 10, 64, 15, 63, 20, 64, 7]

static var _tower_t_cache: Dictionary = {}
static var _nav_adj: Array = []
static var _nav_cache: Dictionary = {}


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


## side 方在視野值 v（0..1）下放出的守衛位置。
static func ward_points(side: String, v: float, minute: int) -> Array:
	var n := clampi(2 + int(round(v * 5.0)), 2, WARD_SPOTS.size())
	var out := []
	var shift := (minute / 3) % 2  # 每 3 分鐘換一批插眼點，看起來有在更新視野
	for i in n:
		var p: Vector2 = WARD_SPOTS[mini(i + (shift if i >= 2 else 0), WARD_SPOTS.size() - 1)]
		out.append(p if side == "blue" else Vector2(1, 1) - p)
	return out


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


# ---------------------------------------------------------------- 路網尋路

static func _build_nav() -> void:
	_nav_adj = []
	for i in NAV_NODES.size():
		_nav_adj.append([])
	for k in range(0, NAV_EDGES.size(), 2):
		var a: int = NAV_EDGES[k]
		var b: int = NAV_EDGES[k + 1]
		_nav_adj[a].append(b)
		_nav_adj[b].append(a)


static func nearest_node(p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in NAV_NODES.size():
		var d = p.distance_squared_to(NAV_NODES[i])
		if d < best_d:
			best_d = d
			best = i
	return best


## 兩個路網節點之間的最短路徑（節點索引，含頭尾），Dijkstra，結果快取。
static func node_route(from: int, to: int) -> Array:
	var key = from * 1000 + to
	if _nav_cache.has(key):
		return _nav_cache[key]
	if _nav_adj.is_empty():
		_build_nav()
	var n = NAV_NODES.size()
	var dist: Array = []
	var prev: Array = []
	var done: Array = []
	dist.resize(n)
	prev.resize(n)
	done.resize(n)
	dist.fill(INF)
	prev.fill(-1)
	done.fill(false)
	dist[from] = 0.0
	for _step in n:
		var u := -1
		var ud := INF
		for i in n:
			if not done[i] and dist[i] < ud:
				ud = dist[i]
				u = i
		if u == -1 or u == to:
			break
		done[u] = true
		for v in _nav_adj[u]:
			var nd = ud + (NAV_NODES[u] as Vector2).distance_to(NAV_NODES[v])
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	var route: Array = []
	var cur := to
	while cur != -1:
		route.push_front(cur)
		if cur == from:
			break
		cur = prev[cur]
	if route.is_empty() or route[0] != from:
		route = [from, to]
	_nav_cache[key] = route
	return route


## 從 a 走到 b 的折線路徑（沿路網）。距離很近時直接走。
static func nav_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	if a.distance_to(b) < 0.06:
		out.append(b)
		return out
	var route = node_route(nearest_node(a), nearest_node(b))
	var pts: Array = route.map(func(i): return NAV_NODES[i])
	# 起點已經比第一個節點更接近第二個節點時，不必先繞回去
	if pts.size() >= 2 and a.distance_to(pts[1]) < (pts[0] as Vector2).distance_to(pts[1]):
		pts.pop_front()
	if pts.size() >= 2 and b.distance_to(pts[-2]) < (pts[-1] as Vector2).distance_to(pts[-2]):
		pts.pop_back()
	for q in pts:
		out.append(q)
	out.append(b)
	return out


## 折線上依比例 u（0..1）取點。
static func along(path: PackedVector2Array, u: float) -> Vector2:
	if path.size() == 1:
		return path[0]
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var d = clampf(u, 0.0, 1.0) * total
	for i in range(1, path.size()):
		var seg = path[i - 1].distance_to(path[i])
		if d <= seg:
			return path[i - 1].lerp(path[i], d / maxf(seg, 0.000001))
		d -= seg
	return path[-1]


# ---------------------------------------------------------------- 有戰術意識的移動

## 防禦塔攻擊範圍（地圖寬度比例，約 775 單位 / 14870）。
const TOWER_RANGE := 0.052
## 走進敵方存活防禦塔範圍時，這段路的代價倍率：不是不能走，而是沒有理由就不會走。
const TOWER_PENALTY := 7.0
## 回城（讀秒 + 出門）的代價，換算成「走了多遠的路」。走路比回城再出門還遠時就回城。
const RECALL_COST := 0.30

static var _edge_cost_cache: Dictionary = {}
static var _plan_cache: Dictionary = {}


## side 方眼中仍存活的敵方防禦塔（外塔／二塔／高地塔與主堡雙塔；兵營不會攻擊）。
## st = 比賽紀錄每格的 "st"：{"blue": {"top": 被拆數, ..., "nexus_towers": n}, "red": {...}}
static func enemy_towers(side: String, st: Dictionary) -> Array:
	var enemy := "red" if side == "blue" else "blue"
	var es: Dictionary = st.get(enemy, {})
	var out: Array = []
	for lane in ["top", "mid", "bot"]:
		var lost := int(es.get(lane, 0))
		for i in range(lost, 3):
			out.append(tower_point(enemy, lane, i))
	var nt := int(es.get("nexus_towers", 0))
	for i in range(nt, 2):
		out.append(NEXUS_TOWERS[enemy][i])
	return out


## 一段路落在塔的攻擊範圍內的長度（取樣估算）。
static func _exposure(a: Vector2, b: Vector2, towers: Array) -> float:
	if towers.is_empty():
		return 0.0
	var seg := a.distance_to(b)
	var n := maxi(2, int(ceil(seg / 0.01)))
	var inside := 0
	for s in range(n):
		var p := a.lerp(b, (s + 0.5) / float(n))
		for tp in towers:
			if p.distance_to(tp) < TOWER_RANGE:
				inside += 1
				break
	return seg * float(inside) / float(n)


## 某一路段的危險成本：完整長度 + 在塔下的那段再乘上倍率。
static func _seg_cost(a: Vector2, b: Vector2, towers: Array) -> float:
	return a.distance_to(b) + _exposure(a, b, towers) * (TOWER_PENALTY - 1.0)


## 依塔的狀態算出每條路網邊的代價（同一種塔況只算一次）。
static func _edge_costs(towers: Array) -> Dictionary:
	var key := str(towers)
	if _edge_cost_cache.has(key):
		return _edge_cost_cache[key]
	if _nav_adj.is_empty():
		_build_nav()
	var costs := {}
	for k in range(0, NAV_EDGES.size(), 2):
		var a: int = NAV_EDGES[k]
		var b: int = NAV_EDGES[k + 1]
		var c := _seg_cost(NAV_NODES[a], NAV_NODES[b], towers)
		costs[a * 1000 + b] = c
		costs[b * 1000 + a] = c
	if _edge_cost_cache.size() > 256:
		_edge_cost_cache.clear()
	_edge_cost_cache[key] = costs
	return costs


## 多起點／多終點的 Dijkstra：起點候選帶著「走到該節點的代價」，終點候選同理。
## 回傳 {"nodes": [索引...], "cost": float}。
static func _route(starts: Dictionary, goals: Dictionary, costs: Dictionary) -> Dictionary:
	var n = NAV_NODES.size()
	var dist: Array = []
	var prev: Array = []
	var done: Array = []
	dist.resize(n)
	prev.resize(n)
	done.resize(n)
	dist.fill(INF)
	prev.fill(-1)
	done.fill(false)
	for s in starts:
		dist[s] = starts[s]
	var best := INF
	var best_goal := -1
	for _step in n:
		var u := -1
		var ud := INF
		for i in n:
			if not done[i] and dist[i] < ud:
				ud = dist[i]
				u = i
		if u == -1 or ud >= best:
			break
		done[u] = true
		if goals.has(u) and ud + goals[u] < best:
			best = ud + goals[u]
			best_goal = u
		for v in _nav_adj[u]:
			var nd = ud + costs[u * 1000 + v]
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	var nodes: Array = []
	var cur := best_goal
	while cur != -1:
		nodes.push_front(cur)
		cur = prev[cur]
	return {"nodes": nodes, "cost": best}


## 離 p 最近的幾個路網節點（附上走過去的危險成本），讓起點可以選「往目的地方向」的那個節點，
## 不必先倒退回最近的節點。
static func _entry_nodes(p: Vector2, towers: Array, count: int = 3) -> Dictionary:
	var order: Array = []
	for i in NAV_NODES.size():
		order.append([p.distance_squared_to(NAV_NODES[i]), i])
	order.sort_custom(func(x, y): return x[0] < y[0])
	var out := {}
	for j in mini(count, order.size()):
		var i: int = order[j][1]
		# 太遠的候選（例如隔著牆的另一條路）不算
		if j > 0 and sqrt(order[j][0]) > sqrt(order[0][0]) * 2.2 + 0.03:
			continue
		out[i] = _seg_cost(p, NAV_NODES[i], towers)
	return out


## 實際的走法：{"path": 折線, "recall": 是否先回城, "cost": 危險加權後的長度}。
## side = 移動的一方；st = 當下的建築狀態。目的地本身在敵塔下（推塔、越塔）時，那座塔不算懲罰——
## 有目的才走進塔下，沒目的就繞路。路太遠時改成回城再從泉水出門。
static func plan_move(a: Vector2, b: Vector2, side: String, st: Dictionary, allow_recall: bool = true) -> Dictionary:
	var key := "%s|%s|%s|%s|%s" % [side, str(a), str(b), str(st), str(allow_recall)]
	if _plan_cache.has(key):
		return _plan_cache[key]
	if _nav_adj.is_empty():
		_build_nav()
	var towers: Array = []
	for tp in enemy_towers(side, st):
		# 起點或終點就在這座塔下：是在推塔／越塔／撤退中，不避開它
		if (tp as Vector2).distance_to(b) < TOWER_RANGE + 0.02 or (tp as Vector2).distance_to(a) < TOWER_RANGE + 0.02:
			continue
		towers.append(tp)
	var walk := _walk(a, b, towers)
	var plan := {"path": walk["path"], "recall": false, "cost": walk["cost"]}
	if allow_recall and side in FOUNTAIN and a.distance_to(FOUNTAIN[side]) > 0.25:
		var home: Vector2 = FOUNTAIN[side]
		var out := _walk(home, b, towers)
		if out["cost"] + RECALL_COST < walk["cost"] * 0.92:
			plan = {"path": out["path"], "recall": true, "cost": out["cost"] + RECALL_COST}
	if _plan_cache.size() > 4096:
		_plan_cache.clear()
	_plan_cache[key] = plan
	return plan


static func _walk(a: Vector2, b: Vector2, towers: Array) -> Dictionary:
	var direct := _seg_cost(a, b, towers)
	if a.distance_to(b) < 0.06:
		return {"path": PackedVector2Array([a, b]), "cost": direct}
	var costs := _edge_costs(towers)
	var r := _route(_entry_nodes(a, towers), _entry_nodes(b, towers), costs)
	var out := PackedVector2Array([a])
	for i in r["nodes"]:
		out.append(NAV_NODES[i])
	out.append(b)
	return {"path": out, "cost": r["cost"]}
