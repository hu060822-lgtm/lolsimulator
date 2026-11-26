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
	var dsc: ScrollContainer = sh.content.get_parent()
	await _frames(2)
	dsc.scroll_vertical = int(dsc.get_v_scroll_bar().max_value)
	await _shot("02_dashboard_goals")
	dsc.scroll_vertical = 0
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
	# 關鍵抉擇：找到第一張抉擇卡，拍下卡片與做完決定後的畫面
	var shot_decision := false
	var g := 0
	while not d.live_snap.is_empty() and g < 8:
		g += 1
		var decs: Array = d.live_snap.get("decisions", [])
		if not decs.is_empty() and not shot_decision:
			await _shot("06_live_decision")
			d._decide(decs[0]["id"], decs[0]["options"][0]["id"])
			d.mc.skip_to_end()
			await _shot("06_live_decision_result")
			shot_decision = true
			break
		d._live_order("control")
		d.mc.skip_to_end()
	await _shot("06_live_map")
	if not d.live_snap.is_empty():
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
	# 搶人大戰：讓一名自由球員變強，強制觸發競標
	var ww: WorldState = app.session.world
	if not ww.free_agents.is_empty():
		var fa: Player = ww.players[ww.free_agents[0]]
		for sk in Attr.SKILLS:
			fa.skills[sk] = 80.0
		fa.home_region = app.session.club().region
		for c in ww.clubs.values():
			c.wage_budget += 5000000
		BiddingWar.maybe_start(ww, app.session.club(), fa, 0, TransferMarket.wage_demand(ww, fa), 2, "rotation", true)
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
	# 經理生涯：休賽季的執教邀請（成績不夠亮眼時，示範用直接產生一封）
	if not w.inbox.any(func(m): return m.get("kind") in ["job_offer", "fired"] and not m.get("resolved", false)):
		ManagerCareer.data(w)["reputation"] = 75.0
		ManagerCareer._offers(w, w.human_club())
	sh.open("inbox")
	await _shot("13_job_offer")
	sh.open("finance")
	await _shot("11_finance_brand")
	quit()
