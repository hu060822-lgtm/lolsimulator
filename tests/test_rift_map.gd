extends TestCase
## 峽谷地圖標定：建築落在兵線上且順序正確；比賽紀錄的座標都在地圖範圍內。


func test_towers_sit_on_lanes_in_order() -> void:
	for lane in ["top", "mid", "bot"]:
		var prev_blue := 2.0
		var prev_red := -1.0
		for i in 4:
			for side in ["blue", "red"]:
				var p = RiftGeometry.tower_point(side, lane, i)
				var on_lane = RiftGeometry.lane_point(lane, RiftGeometry.tower_t(side, lane, i))
				check(p.distance_to(on_lane) < 0.03, "%s %s %d near lane (%.3f)" % [side, lane, i, p.distance_to(on_lane)])
			var bt = RiftGeometry.tower_t("blue", lane, i)
			var rt = RiftGeometry.tower_t("red", lane, i)
			check(bt < prev_blue, "blue %s towers ordered toward base" % lane)
			check(rt > prev_red, "red %s towers ordered toward base" % lane)
			check(bt < rt, "blue %s tower %d before red" % [lane, i])
			prev_blue = bt
			prev_red = rt
		var front = RiftGeometry.lane_front(lane, 0.0, 0, 0)
		check(front > RiftGeometry.tower_t("blue", lane, 0) and front < RiftGeometry.tower_t("red", lane, 0), "%s even front between outer towers" % lane)


func test_frame_positions_stay_on_map() -> void:
	var w = make_world()
	var a = TeamContext.from_club(w, w.clubs["crimson_tide_gaming"])
	var b = TeamContext.from_club(w, w.clubs["harbor_lights"])
	var s = SeriesSim.play(a, b, 1, w.champions, w.patch, SimRng.new(5))
	var g: Dictionary = s["games"][0]
	check(g.has("frames") and g["frames"].size() > 10, "frames recorded")
	for f in g.get("frames", []):
		for side in ["blue", "red"]:
			for q in f["pos"][side]:
				check(q[0] >= 0.0 and q[0] <= 1.0 and q[1] >= 0.0 and q[1] <= 1.0, "position on map: %s" % str(q))
	check(ResourceLoader.exists(RiftMap.MAP_IMAGE), "bundled map image imports")


func test_nav_graph_connected_and_paths_follow_routes() -> void:
	var n = RiftGeometry.NAV_NODES.size()
	for i in n:
		var route = RiftGeometry.node_route(0, i)
		check(route.size() >= 1 and route[0] == 0 and route[-1] == i, "node %d reachable" % i)
	# 藍方上路外塔 → 紅方下路外塔：不能直線穿過地圖中央的野區
	var a = RiftGeometry.tower_point("blue", "top", 0)
	var b = RiftGeometry.tower_point("red", "bot", 0)
	var path = RiftGeometry.nav_path(a, b)
	check(path.size() >= 4, "long trip uses several waypoints (%d)" % path.size())
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	check(length > a.distance_to(b) * 1.05, "route is longer than the straight line")
	check(RiftGeometry.along(path, 0.0).distance_to(a) < 0.001 and RiftGeometry.along(path, 1.0).distance_to(b) < 0.001, "path starts and ends at the frames")
	check(RiftGeometry.nav_path(a, a + Vector2(0.01, 0.0)).size() == 2, "short hop walks directly")


## 不在推塔／越塔的移動，不該無故走進敵方存活防禦塔的攻擊範圍；路程太遠會回城。
func test_moves_respect_enemy_towers() -> void:
	var w = make_world()
	var a = TeamContext.from_club(w, w.clubs["crimson_tide_gaming"])
	var b = TeamContext.from_club(w, w.clubs["harbor_lights"])
	var old_exposed := 0.0
	var new_exposed := 0.0
	var trips := 0
	var recalls := 0
	for seed in [5, 11, 23]:
		var s = SeriesSim.play(a, b, 1, w.champions, w.patch, SimRng.new(seed))
		var frames: Array = s["games"][0]["frames"]
		for i in range(frames.size() - 1):
			for side in ["blue", "red"]:
				for k in 5:
					var p0: Array = frames[i]["pos"][side][k]
					var p1: Array = frames[i + 1]["pos"][side][k]
					if int(p0[2]) != 1 or int(p1[2]) != 1:
						continue
					var from := Vector2(p0[0], p0[1])
					var to := Vector2(p1[0], p1[1])
					var towers: Array = RiftGeometry.enemy_towers(side, frames[i]["st"]).filter(func(tp): return tp.distance_to(to) >= RiftGeometry.TOWER_RANGE + 0.02 and tp.distance_to(from) >= RiftGeometry.TOWER_RANGE + 0.02)
					var plan = RiftGeometry.plan_move(from, to, side, frames[i]["st"])
					old_exposed += _exposed(RiftGeometry.nav_path(from, to), towers)
					new_exposed += _exposed(plan["path"], towers)
					trips += 1
					if plan["recall"]:
						recalls += 1
						check((plan["path"][0] as Vector2).distance_to(RiftGeometry.FOUNTAIN[side]) < 0.001, "recall walks out of own fountain")
	print("  trips=%d recalls=%d tower exposure old=%.3f new=%.3f" % [trips, recalls, old_exposed, new_exposed])
	check(new_exposed < old_exposed * 0.25, "far less walking under enemy towers (%.3f vs %.3f)" % [new_exposed, old_exposed])
	# 目的地就在敵塔下（推塔）時，照樣直接走過去
	var st := {"blue": {"top": 0, "mid": 0, "bot": 0, "nexus_towers": 0}, "red": {"top": 0, "mid": 0, "bot": 0, "nexus_towers": 0}}
	var siege: Vector2 = RiftGeometry.tower_point("red", "mid", 0) + Vector2(-0.03, 0.03)
	var plan2 = RiftGeometry.plan_move(RiftGeometry.lane_point("mid", 0.45), siege, "blue", st)
	check(not plan2["recall"] and (plan2["path"][-1] as Vector2).distance_to(siege) < 0.001, "sieging still walks to the tower")


func _exposed(path: PackedVector2Array, towers: Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += RiftGeometry._exposure(path[i - 1], path[i], towers)
	return total


## 陣亡的棋子倒下後回泉水，不會留在倒下的地點。
func test_dead_tokens_go_back_to_fountain() -> void:
	var st := {"blue": {"top": 0, "mid": 0, "bot": 0, "nexus_towers": 0}, "red": {"top": 0, "mid": 0, "bot": 0, "nexus_towers": 0}}
	var alive := [0.5, 0.5, 1]
	var spot := [0.45, 0.55, 1]
	var died := [0.47, 0.52, 0]
	var dead := [0.055, 0.94, 0]
	var mk = func(m: int, b0: Array) -> Dictionary:
		var red: Array = []
		for _i in 5:
			red.append([0.8, 0.2, 1])
		var blue: Array = [b0]
		for _i in 4:
			blue.append([0.2, 0.8, 1])
		return {"m": m, "pos": {"blue": blue, "red": red}, "marks": [], "st": st}
	var map := RiftMap.new()
	map.set_game([mk.call(5, alive), mk.call(6, died), mk.call(7, dead), mk.call(8, spot)], {}, {})
	var fountain: Vector2 = RiftGeometry.FOUNTAIN["blue"]
	map.head = 0.3
	check(map.token_positions()["blue0"][1], "still alive while walking into the fight")
	map.head = 0.65
	var e: Array = map.token_positions()["blue0"]
	check(not e[1] and e[0].distance_to(Vector2(0.47, 0.52)) < 0.01, "falls where they died")
	map.head = 0.9
	e = map.token_positions()["blue0"]
	check(not e[1] and e[0].distance_to(fountain) < 0.03, "then goes back to the fountain (%s)" % str(e[0]))
	map.head = 1.2
	e = map.token_positions()["blue0"]
	check(not e[1] and e[0].distance_to(fountain) < 0.03, "stays in the fountain while dead")
	map.head = 2.05
	e = map.token_positions()["blue0"]
	check(e[1] and e[0].distance_to(fountain) < 0.08, "respawns from the fountain")
	map.free()
