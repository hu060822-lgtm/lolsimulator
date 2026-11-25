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
	app.session.new_game("res://data/modules/lol_world", 2026, "ctbc_flying_oystar")
	app.start_game()
	await _shot("02_dashboard")
	var sh: Shell = app.current
	# 先推進到第一場比賽前
	sh._on_continue()
	for id in ["roster", "tactics", "training", "transfers", "staff", "finance", "competition", "news", "inbox"]:
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
		if id == "transfers" and sh.page.fee and sh.page.fee.editable:
			sh.page.fee.value = 10000
			sh.page._offer()
			var tsc: ScrollContainer = sh.content.get_parent()
			await _frames(2)
			tsc.scroll_vertical = int(tsc.get_v_scroll_bar().max_value)
			await _shot("03_transfers_counter")
			tsc.scroll_vertical = 0
	# 賽前情報（對手打法、勝率因素、克制建議）
	sh.open_prep()
	await _shot("04_prep")
	var prep: MatchPrepScreen = sh.page
	var b = app.session.match_briefing()
	if b.get("recommended", "") != "":
		prep._set_plan(b["recommended"])
		await _shot("04_prep_countered")
	sh.open_match()
	await _shot("04_draft")
	var d: DraftScreen = sh.page
	d._team_talk("fire_up")
	await _shot("04_team_talk")
	d._auto_draft()
	await _shot("05_draft_done")
	d._play_live()
	d.mc.skip_to_end()
	await _shot("06_live_tactics")
	d._live_order("control")
	d.mc.skip_to_end()
	await _shot("06_live_map")
	d._live_skip()
	d.mc.skip_to_end()
	await _shot("06_match")
	var sc: ScrollContainer = sh.content.get_parent()
	await _frames(2)
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await _shot("06_post_game")
	# 下一場：快速模擬
	sh.after_match()
	app.session.advance_to_next_match()
	if app.session.has_match_ready():
		sh.open_prep()
		var prep2: MatchPrepScreen = sh.page
		prep2._quick_sim()
		sc.scroll_vertical = 0
		await _shot("06_quick_sim")
	# 收件匣（需決策／例行、交給助理）
	sh.open("inbox")
	await _shot("12_inbox")
	# 推進到世界賽與賽季結束
	app.session.manual_draft = false
	var w: WorldState = app.session.world
	var guard := 0
	while w.phase != WorldState.PHASE_INTERNATIONAL and guard < 300:
		WorldSimulator.advance_day(w)
		guard += 1
	WorldSimulator.advance_days(w, 9)
	sh.open("competition")
	var cs: CompetitionScreen = sh.page
	cs.league_opt.select(cs.ids.find("worlds"))
	cs._sync_chips()
	cs.refresh()
	await _shot("07_worlds")
	sh.open("news")
	await _shot("08_news")
	while w.phase != WorldState.PHASE_OFFSEASON and guard < 400:
		WorldSimulator.advance_day(w)
		guard += 1
	sh.open("history")
	await _shot("09_history")
	sh.open("dashboard")
	await _shot("10_dashboard_offseason")
	sh.open("finance")
	await _shot("11_finance_brand")
	quit()
