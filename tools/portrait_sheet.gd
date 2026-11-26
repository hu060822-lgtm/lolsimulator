## 面譜預覽：xvfb-run godot --path . -s tools/portrait_sheet.gd -- --out=/tmp/faces.png
## 用預設世界的前 40 位選手畫一張 8×5 的面譜表，方便檢查部件搭配。
extends SceneTree

var out := "user://faces.png"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 840)
	var s := GameSession.new()
	s.new_game("res://data/modules/lol_world", 2026, "ctbc_flying_oystar")
	var view := Control.new()
	view.set_script(load("res://tools/portrait_sheet_view.gd"))
	view.size = Vector2(1280, 840)
	view.players = s.world.players.values().slice(0, 40)
	view.world = s.world
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.size = view.size
	root.add_child(bg)
	root.add_child(view)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
