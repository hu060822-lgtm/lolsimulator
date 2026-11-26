## 移動路線前後對比：同一場比賽中「舊路網最短路」與「避塔／回城的新走法」並排畫出。
## xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/path_compare.gd -- --out=/tmp/shots
extends SceneTree

var out := "user://shots"


class Panel2 extends Control:
	var trips: Array = []   # [[path, color, recall], ...]
	var towers: Array = []
	var title := ""

	func _draw() -> void:
		var s := size.x
		var bg = RiftMap.background()
		if bg:
			draw_texture_rect(bg, Rect2(Vector2.ZERO, Vector2(s, s)), false)
			draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), Color(0, 0, 0, 0.35))
		for tp in towers:
			draw_circle(tp * s, RiftGeometry.TOWER_RANGE * s, Color(1, 0.3, 0.3, 0.16))
			draw_arc(tp * s, RiftGeometry.TOWER_RANGE * s, 0, TAU, 32, Color(1, 0.4, 0.4, 0.7), 1.5)
		for tr in trips:
			var path: PackedVector2Array = tr[0]
			var pts := PackedVector2Array()
			for p in path:
				pts.append(p * s)
			draw_polyline(pts, Color(0, 0, 0, 0.6), 6.0, true)
			draw_polyline(pts, tr[1], 3.5, true)
			draw_circle(pts[-1], 6.0, tr[1])
			if tr[2]:
				draw_arc(pts[0], 12.0, 0, TAU, 24, Color(0.7, 0.85, 1.0), 3.0)
		var font = ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, s, 44), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(14, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1640, 820))
	root.size = Vector2i(1640, 820)
	var m = DataModule.load_from_dir("res://data/modules/lol_world")
	var w = WorldBuilder.build(m, 42, "")
	var ids: Array = w.clubs.keys()
	var a = TeamContext.from_club(w, w.clubs[ids[0]])
	var b = TeamContext.from_club(w, w.clubs[ids[1]])
	var old_trips: Array = []
	var new_trips: Array = []
	var shown_towers := {}
	var state := ""
	var palette := [Color("ffd166"), Color("06d6a0"), Color("4cc9f0"), Color("f72585"), Color("b388ff"), Color("ff9f1c")]
	for seed in range(1, 80):
		if old_trips.size() >= 6:
			break
		var s = SeriesSim.play(a, b, 1, w.champions, w.patch, SimRng.new(seed))
		var frames: Array = s["games"][0]["frames"]
		for i in range(2, frames.size() - 1):
			if old_trips.size() >= 6:
				break
			for k in 5:
				var p0: Array = frames[i]["pos"]["blue"][k]
				var p1: Array = frames[i + 1]["pos"]["blue"][k]
				if int(p0[2]) != 1 or int(p1[2]) != 1:
					continue
				var from := Vector2(p0[0], p0[1])
				var to := Vector2(p1[0], p1[1])
				var towers: Array = RiftGeometry.enemy_towers("blue", frames[i]["st"]).filter(func(tp): return tp.distance_to(to) >= RiftGeometry.TOWER_RANGE + 0.02 and tp.distance_to(from) >= RiftGeometry.TOWER_RANGE + 0.02)
				# 只收同一種塔況的移動，畫出來的塔圈才對得上每一條路線
				if not state.is_empty() and str(frames[i]["st"]) != state:
					continue
				var old_path = RiftGeometry.nav_path(from, to)
				var ex := 0.0
				for j in range(1, old_path.size()):
					ex += RiftGeometry._exposure(old_path[j - 1], old_path[j], towers)
				if ex < 0.02:
					continue
				var col: Color = palette[old_trips.size() % palette.size()]
				var plan = RiftGeometry.plan_move(from, to, "blue", frames[i]["st"])
				old_trips.append([old_path, col, false])
				var np: PackedVector2Array = plan["path"]
				if plan["recall"]:
					np = PackedVector2Array([from]) + np
				new_trips.append([np, col, plan["recall"]])
				state = str(frames[i]["st"])
				for tp in RiftGeometry.enemy_towers("blue", frames[i]["st"]):
					shown_towers[tp] = true
				break
	var left := Panel2.new()
	left.title = "之前：路網最短路（穿過敵塔範圍）"
	left.trips = old_trips
	left.towers = shown_towers.keys()
	left.position = Vector2(0, 0)
	left.size = Vector2(820, 820)
	var right := Panel2.new()
	right.title = "之後：避開敵塔、太遠就回城（藍圈）"
	right.trips = new_trips
	right.towers = shown_towers.keys()
	right.position = Vector2(820, 0)
	right.size = Vector2(820, 820)
	root.add_child(left)
	root.add_child(right)
	for _i in 5:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("path_compare.png"))
	print("saved path_compare with %d trips" % old_trips.size())
	quit()
