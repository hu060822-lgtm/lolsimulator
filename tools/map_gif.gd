## 匯出即時地圖的連續畫格（之後用 PIL 合成 GIF），用來檢查棋子移動。
## xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/map_gif.gd -- --out=/tmp/frames --seed=5 --from=8 --to=16
extends SceneTree

func _initialize() -> void:
	var out := "user://frames"
	var seed := 5
	var from := 8
	var to := 16
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--from="):
			from = int(a.substr(7))
		elif a.begins_with("--to="):
			to = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	_run(out, seed, from, to)


func _run(out: String, seed: int, from: int, to: int) -> void:
	DisplayServer.window_set_size(Vector2i(640, 640))
	root.size = Vector2i(640, 640)
	var m = DataModule.load_from_dir("res://data/modules/lol_world")
	var w = WorldBuilder.build(m, 42, "")
	var ids: Array = w.clubs.keys()
	var a = TeamContext.from_club(w, w.clubs[ids[0]])
	var b = TeamContext.from_club(w, w.clubs[ids[1]])
	var s = SeriesSim.play(a, b, 1, w.champions, w.patch, SimRng.new(seed))
	var g: Dictionary = s["games"][0]
	var champs: Dictionary = g.get("champs", {})
	var map := RiftMap.new()
	map.size = Vector2(640, 640)
	root.add_child(map)
	map.set_game(g["frames"], champs, w.champions)
	var n := 0
	var steps := 12
	for f in range(from, to):
		for k in steps:
			map.head = f + float(k) / steps
			map.queue_redraw()
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(out.path_join("f%04d.png" % n))
			n += 1
	print("saved %d frames" % n)
	quit()
