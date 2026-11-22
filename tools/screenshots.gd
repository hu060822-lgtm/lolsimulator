## UI 截圖工具：xvfb-run godot --path . -s tools/screenshots.gd -- --out=/tmp/shots
extends SceneTree

var out := "user://shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var app = load("res://src/ui/main.tscn").instantiate()
	root.add_child(app)
	await _frames(3)
	await _shot("01_new_game")
	app.session.new_game("res://data/modules/fictional_base", 2027, "harbor_lights")
	app.start_game()
	await _shot("02_dashboard")
	var sh: Shell = app.current
	# 先推進到第一場比賽前
	sh._on_continue()
	for id in ["roster", "tactics", "training", "transfers", "staff", "finance", "competition", "inbox"]:
		sh.open(id)
		if id == "roster":
			var t: Tree = sh.page.table
			t.get_root().get_child(0).select(0)
			sh.page._on_select()
		if id == "transfers":
			var t2: Tree = sh.page.table
			t2.get_root().get_child(2).select(0)
			sh.page._on_select()
		await _shot("03_" + id)
	sh.open_match()
	await _shot("04_draft")
	var d: DraftScreen = sh.page
	d._auto_draft()
	await _shot("05_draft_done")
	d._play()
	d._reveal_all()
	await _shot("06_match")
	quit()
