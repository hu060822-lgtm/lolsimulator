## Match Center：逐局手動 BP → 比賽文字直播（可調速度）→ 數據 → 下一局。
class_name DraftScreen
extends UIScreen

const ORDERS := ["none", "press", "stall", "control", "split", "pick", "siege"]
const ORDER_NAMES := ["交給選手判斷", "主動進攻", "拖後期", "物件控制", "分推", "抓單", "消耗圍塔"]

var series: SeriesState
var ds: DraftSession
var hs: String = "blue"
var header: Label
var blue_col: VBoxContainer
var red_col: VBoxContainer
var center: VBoxContainer
var role_filter: String = ""
var pick_role: OptionButton
var order_opt: OptionButton
var feed: RichTextLabel
var timer: Timer
var game: Dictionary = {}
var shown_events: int = 0
var speed: float = 0.35


func build() -> void:
	series = session.begin_match()
	if series == null:
		add_child(UIKit.label("今天沒有比賽。"))
		return
	header = UIKit.label("", 20)
	add_child(header)
	_new_game()


func _new_game() -> void:
	for c in get_children().slice(1):
		remove_child(c)
		c.queue_free()
	ds = series.new_draft()
	hs = session.human_side(series)
	var row := UIKit.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	blue_col = UIKit.vbox(4)
	blue_col.custom_minimum_size = Vector2(190, 0)
	red_col = UIKit.vbox(4)
	red_col.custom_minimum_size = Vector2(190, 0)
	center = UIKit.vbox(8)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(UIKit.panel(blue_col))
	row.add_child(UIKit.panel(center))
	row.add_child(UIKit.panel(red_col))
	_advance_ai()
	refresh()


## AI 一方自動行動，直到輪到玩家或 BP 結束。
func _advance_ai() -> void:
	while not ds.is_done() and ds.current_side() != hs:
		ds.ai_step()


func refresh() -> void:
	if series == null or ds == null:
		return
	var ww = w()
	header.text = "第 %d 局　%s %d - %d %s　（Bo%d）" % [series.games.size() + 1, series.a.name, int(series.wins[series.a.club_id]), int(series.wins[series.b.club_id]), series.b.name, series.best_of]
	_team_col(blue_col, "blue")
	_team_col(red_col, "red")
	UIKit.clear(center)
	if ds.is_done():
		_draft_summary()
		return
	var act = ds.current_action()
	center.add_child(UIKit.label("輪到你%s（%s方）" % ["禁用" if act == "ban" else "選角", "藍" if hs == "blue" else "紅"], 18, UIKit.ACCENT))
	# 分析師建議（帶誤差）
	var sug = ds.suggestions(hs, 5)
	var sv := UIKit.vbox(2)
	sv.add_child(UIKit.muted("分析師建議（BP 品質 %d%%，建議不一定正確）" % int(ds.teams[hs].draft_quality() * 100)))
	for s in sug:
		var ch: Champion = ds.champions[s["champion"]]
		var b := UIKit.button("%s%s　— %s" % [ch.name, ("（%s）" % UIKit.ROLE_NAMES[s["role"]]) if s["role"] != "" else "", s["reason"]], _choose.bind(s["champion"], s["role"]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sv.add_child(b)
	center.add_child(sv)
	# 位置篩選 + 選角位置
	var fr := UIKit.hbox()
	fr.add_child(UIKit.label("篩選"))
	for r in [""] + Attr.ROLES:
		var b := UIKit.button(UIKit.ROLE_NAMES.get(r, "全部"), _filter.bind(r))
		b.toggle_mode = true
		b.button_pressed = role_filter == r
		fr.add_child(b)
	center.add_child(fr)
	if act == "pick":
		var open = ds.open_roles(hs)
		var pr := UIKit.hbox()
		pr.add_child(UIKit.label("這個英雄給"))
		pick_role = UIKit.option(open.map(func(r): return "%s（%s）" % [UIKit.ROLE_NAMES[r], ds.teams[hs].players[r].handle if ds.teams[hs].players.has(r) else "?"]), maxi(open.find(role_filter), 0))
		pr.add_child(pick_role)
		center.add_child(pr)
	# 英雄格
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var champs: Array = ds.champions.values().filter(func(c): return role_filter == "" or role_filter in c.roles)
	champs.sort_custom(func(a, b): return a.name < b.name)
	for c in champs:
		var info = _champ_info(c, act)
		var b := UIKit.button(info, _choose.bind(c.id, ""))
		b.disabled = ds.unavailable.has(c.id)
		b.custom_minimum_size = Vector2(128, 44)
		b.add_theme_font_size_override("font_size", 13)
		grid.add_child(b)
	center.add_child(grid)
	center.add_child(UIKit.button("交給教練團完成剩下的 BP", _auto_draft))


func _champ_info(c: Champion, act: String) -> String:
	var meta = w().patch.meta(c.id)
	var arrow = " ▲" if meta >= 1 else (" ▼" if meta <= -1 else "")
	var best := 0.0
	var team: TeamContext = ds.teams[hs] if act == "pick" else ds.teams[ds.other(hs)]
	for r in c.roles:
		var p: Player = team.players.get(r)
		if p:
			best = maxf(best, p.mastery(c.id))
	return "%s%s\n%s %d" % [c.name, arrow, "我方熟練" if act == "pick" else "對手熟練", int(best)]


func _team_col(col: VBoxContainer, side: String) -> void:
	UIKit.clear(col)
	var t: TeamContext = ds.teams[side]
	col.add_child(UIKit.label(("藍方　" if side == "blue" else "紅方　") + t.name, 16, UIKit.BLUE_SIDE if side == "blue" else UIKit.RED_SIDE))
	col.add_child(UIKit.muted("禁用：" + "、".join(ds.bans[side].map(func(c): return ds.champions[c].name))))
	for r in Attr.ROLES:
		var p: Player = t.players.get(r)
		var cid: String = ds.picks[side].get(r, "")
		col.add_child(UIKit.label("%s %s" % [UIKit.ROLE_NAMES[r], p.handle if p else "?"], 14))
		col.add_child(UIKit.label("　" + (ds.champions[cid].name + "（熟練 %d）" % int(p.mastery(cid)) if cid != "" and p else "—"), 14, UIKit.TEXT if cid != "" else UIKit.MUTED))
	col.add_child(HSeparator.new())
	col.add_child(UIKit.muted("BP 紀錄"))
	for e in ds.log:
		if e["side"] == side:
			col.add_child(UIKit.label("%s %s：%s" % ["禁" if e["action"] == "ban" else "選", ds.champions[e["champion"]].name, e["reason"]], 12, UIKit.MUTED))


func _filter(r: String) -> void:
	role_filter = r
	refresh()


func _choose(champ_id: String, role: String) -> void:
	if ds.is_done() or ds.current_side() != hs:
		return
	if ds.current_action() == "pick" and role == "":
		var open = ds.open_roles(hs)
		role = open[pick_role.selected] if pick_role and pick_role.selected < open.size() else ""
		if not (role in ds.champions[champ_id].roles):
			for r in open:
				if r in ds.champions[champ_id].roles:
					role = r
					break
	if not ds.can_apply(champ_id, role):
		toast("無法選擇：英雄不可用或位置不符")
		return
	ds.apply(champ_id, role, "玩家決定")
	_advance_ai()
	refresh()


func _auto_draft() -> void:
	ds.run_all()
	refresh()


func _draft_summary() -> void:
	var r = ds.result()
	center.add_child(UIKit.label("BP 完成", 18, UIKit.ACCENT))
	for side in ["blue", "red"]:
		center.add_child(UIKit.label("%s（%s）" % [ds.teams[side].name, UIKit.PLAN_NAMES.get(r["plan"][side], r["plan"][side])], 15, UIKit.BLUE_SIDE if side == "blue" else UIKit.RED_SIDE))
		center.add_child(UIKit.rich(MatchView.comp_text(r["comp"][side])))
	var cs = CompAnalyzer.counter_score(r["comp"][hs], r["comp"][ds.other(hs)])
	center.add_child(UIKit.label("陣容剋制評估：%s（%+.2f）" % ["我方有利" if cs > 0.02 else ("對方有利" if cs < -0.02 else "大致均勢"), cs], 15, UIKit.GOOD if cs > 0.02 else (UIKit.BAD if cs < -0.02 else UIKit.TEXT)))
	var orow := UIKit.hbox()
	orow.add_child(UIKit.label("臨場戰術指示"))
	order_opt = UIKit.option(ORDER_NAMES, 0)
	orow.add_child(order_opt)
	center.add_child(orow)
	center.add_child(UIKit.muted("指示會在 14、20、26… 分鐘的戰術調整時覆蓋選手的判斷。"))
	center.add_child(UIKit.primary("開始比賽 ▶", _play))


func _play() -> void:
	var t: TeamContext = ds.teams[hs]
	t.orders = {}
	if order_opt and order_opt.selected > 0:
		for m in [14, 20, 26, 32, 38, 44, 50, 56]:
			t.orders[str(m)] = ORDERS[order_opt.selected]
	game = session.play_game(ds)
	t.orders = {}
	_show_game()


func _show_game() -> void:
	for c in get_children().slice(1):
		remove_child(c)
		c.queue_free()
	header.text = "第 %d 局　%s %d - %d %s" % [series.games.size(), series.a.name, int(series.wins[series.a.club_id]), int(series.wins[series.b.club_id]), series.b.name]
	var ctrl := UIKit.hbox()
	add_child(ctrl)
	ctrl.add_child(UIKit.button("1x", func(): speed = 0.6; _restart_timer()))
	ctrl.add_child(UIKit.button("4x", func(): speed = 0.15; _restart_timer()))
	ctrl.add_child(UIKit.button("跳到結果", _reveal_all))
	feed = UIKit.rich()
	feed.fit_content = true
	add_child(UIKit.panel(feed))
	shown_events = 0
	timer = Timer.new()
	timer.wait_time = speed
	timer.timeout.connect(_tick)
	add_child(timer)
	if is_inside_tree():
		timer.start()
	else:
		_reveal_all()


func _restart_timer() -> void:
	if timer:
		timer.wait_time = speed


func _tick() -> void:
	if shown_events >= game["events"].size():
		timer.stop()
		_end_of_game()
		return
	shown_events += 1
	_render_feed()


func _reveal_all() -> void:
	if timer:
		timer.stop()
	shown_events = game["events"].size()
	_render_feed()
	_end_of_game()


func _render_feed() -> void:
	var lines: Array = []
	for e in game["events"].slice(0, shown_events):
		lines.append(MatchView.event_line(session, game, e))
	feed.text = "\n".join(lines)


func _end_of_game() -> void:
	if has_node("EndBox"):
		return
	var v := UIKit.vbox(6)
	v.name = "EndBox"
	var ww = w()
	var won: bool = game["winner_club"] == ww.human_club_id
	v.add_child(UIKit.label("%s　%s 獲勝（%d 分鐘）" % ["勝利！" if won else "落敗", ww.clubs[game["winner_club"]].name, int(game["duration"])], 20, UIKit.GOOD if won else UIKit.BAD))
	v.add_child(MatchView.stats_table(session, game))
	if series.is_done():
		v.add_child(UIKit.primary("完成系列賽", _finish))
	else:
		v.add_child(UIKit.primary("下一局 BP ▶", _new_game))
	add_child(v)


func _finish() -> void:
	session.finish_match()
	shell.refresh_status()
	shell.after_match()
