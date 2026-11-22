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
