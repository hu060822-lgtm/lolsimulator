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
var search_text: String = ""
var champ_grid: HFlowContainer
var grid_act: String = ""
var pick_role: OptionButton
var pre_order: int = 0
var order_btns: Array = []
var game: Dictionary = {}


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
	if session.can_team_talk():
		var talk := UIKit.hbox(6)
		talk.name = "TeamTalk"
		talk.add_child(UIKit.label("賽前談話" if series.games.is_empty() else "局間談話", 15, UIKit.ACCENT))
		for k in Dialogue.TEAM_TALKS:
			talk.add_child(UIKit.button(Dialogue.TEAM_TALKS[k], _team_talk.bind(k)))
		add_child(talk)
	var row := UIKit.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	blue_col = UIKit.vbox(4)
	blue_col.custom_minimum_size = Vector2(210, 0)
	red_col = UIKit.vbox(4)
	red_col.custom_minimum_size = Vector2(210, 0)
	center = UIKit.vbox(8)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(UIKit.panel(blue_col))
	var cp = UIKit.panel(center)
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cp)
	row.add_child(UIKit.panel(red_col))
	_advance_ai()
	refresh()


func _team_talk(kind: String) -> void:
	var r = session.team_talk(kind)
	var box = get_node_or_null("TeamTalk")
	if box == null or not r.get("ok", false):
		return
	UIKit.clear(box)
	var parts: Array = r["reactions"].map(func(x): return "%s %s" % [x["player"], x["text"]])
	var l = UIKit.label("談話後：" + "；".join(parts), 13, UIKit.GOOD if r["avg"] > 0.2 else (UIKit.BAD if r["avg"] < -0.1 else UIKit.TEXT))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(l)


## AI 一方自動行動，直到輪到玩家或 BP 結束。
func _advance_ai() -> void:
	while not ds.is_done() and ds.current_side() != hs:
		ds.ai_step()


func refresh() -> void:
	if series == null or ds == null:
		return
	header.text = "第 %d 局　%s %d - %d %s　（%s）" % [series.games.size() + 1, UIKit.club_label(series.a), int(series.wins[series.a.club_id]), int(series.wins[series.b.club_id]), UIKit.club_label(series.b), UIKit.bo_text(series.best_of)]
	_team_col(blue_col, "blue")
	_team_col(red_col, "red")
	UIKit.clear(center)
	if ds.is_done():
		_draft_summary()
		return
	var act = ds.current_action()
	var top := UIKit.hbox(10)
	top.add_child(UIKit.label("輪到你%s" % ("禁用" if act == "ban" else "選角"), 20, UIKit.BAD if act == "ban" else UIKit.ACCENT))
	top.add_child(UIKit.pill("BP 第 %d / %d 步" % [ds.step + 1, DraftSession.SEQUENCE.size()], UIKit.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UIKit.button("教練團代勞", _auto_draft))
	center.add_child(top)
	# 分析師建議（帶誤差）：頭像小卡，原因放在滑鼠提示
	var sug = ds.suggestions(hs, 5)
	var sv := HFlowContainer.new()
	sv.add_theme_constant_override("h_separation", 6)
	sv.add_child(UIKit.label("分析師建議", 13, UIKit.MUTED))
	for s in sug:
		var ch: Champion = ds.champions[s["champion"]]
		var b := Button.new()
		b.pressed.connect(_choose.bind(s["champion"], s["role"]))
		b.tooltip_text = "%s\n%s" % [s["reason"], "（BP 品質 %d%%，建議不一定正確）" % int(ds.teams[hs].draft_quality() * 100)]
		var h := UIKit.hbox(6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
		var tok := ChampToken.make(ch, UIKit.WARN, 26)
		tok.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tok)
		var l := UIKit.label(ch.name + ((" " + UIKit.ROLE_SHORT[s["role"]]) if s["role"] != "" else ""), 13)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
		b.custom_minimum_size = Vector2(l.get_minimum_size().x + 46, 34)
		b.add_child(h)
		sv.add_child(b)
	center.add_child(sv)
	# 位置篩選 + 選角位置
	var fr := HFlowContainer.new()
	fr.add_theme_constant_override("h_separation", 6)
	for r in [""] + Attr.ROLES:
		var b := UIKit.chip(UIKit.ROLE_SHORT.get(r, "ALL"), _filter.bind(r))
		b.button_pressed = role_filter == r
		fr.add_child(b)
	if act == "pick":
		var open = ds.open_roles(hs)
		fr.add_child(UIKit.label("　給", 13, UIKit.MUTED))
		pick_role = UIKit.option(open.map(func(r): return "%s %s" % [UIKit.ROLE_SHORT[r], ds.teams[hs].players[r].handle if ds.teams[hs].players.has(r) else "?"]), maxi(open.find(role_filter), 0))
		fr.add_child(pick_role)
	# 搜尋：中文名、英文名或縮寫皆可
	var search := LineEdit.new()
	search.placeholder_text = "搜尋英雄（中文／英文）"
	search.text = search_text
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(200, 0)
	search.text_changed.connect(func(t): search_text = t; _fill_grid())
	fr.add_child(search)
	center.add_child(fr)
	# 英雄格（頭像），依英文名排序，與頭像縮寫一致
	champ_grid = HFlowContainer.new()
	champ_grid.add_theme_constant_override("h_separation", 6)
	champ_grid.add_theme_constant_override("v_separation", 6)
	grid_act = act
	center.add_child(champ_grid)
	_fill_grid()


static func champ_matches(c: Champion, q: String) -> bool:
	q = q.strip_edges().to_lower()
	if q == "":
		return true
	return c.name.to_lower().contains(q) or c.name_en.to_lower().contains(q) or c.id.to_lower().contains(q)


func _fill_grid() -> void:
	if champ_grid == null:
		return
	UIKit.clear(champ_grid)
	var champs: Array = ds.champions.values().filter(func(c): return (role_filter == "" or role_filter in c.roles) and champ_matches(c, search_text))
	champs.sort_custom(func(a, b): return (a.name_en if a.name_en != "" else a.name) < (b.name_en if b.name_en != "" else b.name))
	for c in champs:
		var meta = w().patch.meta(c.id)
		var ring = UIKit.GOOD if meta >= 1 else (UIKit.BAD if meta <= -1 else UIKit.BORDER.lightened(0.3))
		champ_grid.add_child(ChampToken.card(c, _champ_info(c, grid_act), ring, _choose.bind(c.id, ""), ds.unavailable.has(c.id)))
	if champs.is_empty():
		champ_grid.add_child(UIKit.muted("找不到符合的英雄"))


## 英雄卡下方的一行：熟練度（選角看我方、禁用看對手）＋版本強弱。
func _champ_info(c: Champion, act: String) -> String:
	var meta = w().patch.meta(c.id)
	var arrow = "▲" if meta >= 1 else ("▼" if meta <= -1 else "")
	var best := 0.0
	var team: TeamContext = ds.teams[hs] if act == "pick" else ds.teams[ds.other(hs)]
	for r in c.roles:
		var p: Player = team.players.get(r)
		if p:
			best = maxf(best, p.mastery(c.id))
	return "%s %d %s" % ["熟" if act == "pick" else "敵", int(best), arrow]


func _team_col(col: VBoxContainer, side: String) -> void:
	UIKit.clear(col)
	var t: TeamContext = ds.teams[side]
	var col_c = UIKit.BLUE_SIDE if side == "blue" else UIKit.RED_SIDE
	var head := UIKit.hbox(6)
	head.add_child(UIKit.label(t.short_name, 20, col_c))
	head.add_child(UIKit.pill("藍方" if side == "blue" else "紅方", col_c))
	col.add_child(head)
	# 禁用列
	var bans := UIKit.hbox(4)
	for i in 5:
		var cid: String = ds.bans[side][i] if i < ds.bans[side].size() else ""
		var tok := ChampToken.make(ds.champions.get(cid), UIKit.BAD.darkened(0.3), 30)
		tok.alive = false
		if cid == "":
			tok.modulate = Color(1, 1, 1, 0.35)
		bans.add_child(tok)
	col.add_child(bans)
	# 五個位置
	var reasons := {}
	for e in ds.log:
		if e["side"] == side and e["action"] == "pick":
			reasons[e["champion"]] = e["reason"]
	for r in Attr.ROLES:
		var p: Player = t.players.get(r)
		var cid: String = ds.picks[side].get(r, "")
		var c: Champion = ds.champions.get(cid)
		var slot := UIKit.hbox(8)
		var tok := ChampToken.make(c, col_c if c else UIKit.BORDER, 46)
		if c:
			tok.tooltip_text = UIKit.champion_info(c) + ("\n\n選擇原因：" + reasons[cid] if reasons.has(cid) else "")
		slot.add_child(tok)
		var info := UIKit.vbox(0)
		info.add_child(UIKit.label(UIKit.ROLE_SHORT[r], 11, col_c))
		info.add_child(UIKit.label(p.handle if p else "?", 15))
		info.add_child(UIKit.label((c.name + "　熟練 %d" % int(p.mastery(cid))) if c and p else "—", 12, UIKit.MUTED))
		slot.add_child(info)
		var sp = UIKit.panel(slot)
		sp.add_theme_stylebox_override("panel", UIKit._box(UIKit.PANEL_2, col_c.darkened(0.5) if c else UIKit.BORDER, 6))
		col.add_child(sp)


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
	search_text = ""
	_advance_ai()
	refresh()


func _auto_draft() -> void:
	ds.run_all()
	refresh()


func _draft_summary() -> void:
	var r = ds.result()
	var cs = CompAnalyzer.counter_score(r["comp"][hs], r["comp"][ds.other(hs)])
	var top := UIKit.hbox(10)
	top.add_child(UIKit.label("BP 完成", 20, UIKit.ACCENT))
	top.add_child(UIKit.pill("陣容剋制：" + ("我方有利" if cs > 0.02 else ("對方有利" if cs < -0.02 else "大致均勢")), UIKit.GOOD if cs > 0.02 else (UIKit.BAD if cs < -0.02 else UIKit.MUTED)))
	center.add_child(top)
	var cards := UIKit.hbox(8)
	for side in ["blue", "red"]:
		cards.add_child(_comp_card(side, r["comp"][side], r["plan"][side]))
	center.add_child(cards)
	center.add_child(UIKit.label("臨場戰術指示", 15))
	var orow := HFlowContainer.new()
	orow.add_theme_constant_override("h_separation", 6)
	order_btns = []
	for k in ORDERS.size():
		var b := UIKit.chip(ORDER_NAMES[k], _pick_order.bind(k))
		b.button_pressed = k == pre_order
		order_btns.append(b)
		orow.add_child(b)
	center.add_child(orow)
	center.add_child(UIKit.muted("指示會在 14、20、26… 分鐘的戰術調整時覆蓋選手的判斷。"))
	var brow := UIKit.hbox(8)
	brow.add_child(UIKit.tile("WATCH", "觀戰", "看完整場比賽", _play, UIKit.ACCENT, 170))
	brow.add_child(UIKit.tile("LIVE", "即時指揮", "每個戰術調整點暫停", _play_live, UIKit.WARN, 170))
	center.add_child(brow)


func _pick_order(k: int) -> void:
	pre_order = k
	for i in order_btns.size():
		order_btns[i].button_pressed = i == k


func _comp_card(side: String, comp: Dictionary, plan: String) -> PanelContainer:
	var col = UIKit.BLUE_SIDE if side == "blue" else UIKit.RED_SIDE
	var v := UIKit.vbox(4)
	var h := UIKit.hbox(6)
	h.add_child(UIKit.label(ds.teams[side].short_name, 17, col))
	h.add_child(UIKit.pill(MatchView.ARCH[comp["primary"]], col))
	h.add_child(UIKit.pill(UIKit.PLAN_NAMES.get(plan, plan), UIKit.MUTED))
	v.add_child(h)
	var share: Dictionary = comp["share"]
	var keys: Array = share.keys()
	keys.sort_custom(func(a, b): return share[a] > share[b])
	for k in keys.slice(0, 3):
		v.add_child(UIKit.stat_bar(MatchView.ARCH[k], share[k] * 100.0, 100.0, 90, col, 60))
	for pair in [["前期", comp["early"]], ["中期", comp["mid"]], ["後期", comp["late"]]]:
		v.add_child(UIKit.stat_bar(pair[0], float(pair[1]) * 10.0, 100.0, 90, UIKit.WARN, 60))
	if comp["flaws"].size() > 0:
		var fl := HFlowContainer.new()
		for f in comp["flaws"]:
			fl.add_child(UIKit.pill(MatchView.FLAWS.get(f, f), UIKit.BAD))
		v.add_child(fl)
	var p = UIKit.panel(v)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _play() -> void:
	var t: TeamContext = ds.teams[hs]
	t.orders = {}
	if pre_order > 0:
		for m in [14, 20, 26, 32, 38, 44, 50, 56]:
			t.orders[str(m)] = ORDERS[pre_order]
	game = session.play_game(ds)
	t.orders = {}
	live_snap = {}
	_open_center()
	mc.load(game)
	var skip := UIKit.button("跳到結果  »", func(): mc.skip_to_end())
	bottom.add_child(skip)
	if is_inside_tree():
		mc.play_to_end()
	else:
		mc.skip_to_end()


# ---------------------------------------------------------------- 比賽轉播與即時指揮

const ORDER_INFO := {
	"none": ["AUTO", "交給選手判斷"], "press": ["FIGHT", "主動進攻"], "stall": ["SCALE", "拖後期"], "control": ["OBJ", "物件控制"],
	"split": ["SPLIT", "分推"], "pick": ["PICK", "抓單"], "siege": ["SIEGE", "消耗圍塔"],
}
const ORDER_DESC := {
	"none": "依指揮自行判斷", "press": "找團戰擴大優勢", "stall": "避戰、等後期", "control": "圍繞小龍與巴龍",
	"split": "邊路牽制、拉扯", "pick": "視野抓落單", "siege": "消耗後推塔",
}

var mc: MatchCenter
var bottom: VBoxContainer
var live_snap: Dictionary = {}


func _open_center() -> void:
	for c in get_children().slice(1):
		remove_child(c)
		c.queue_free()
	header.text = "第 %d 局　%s %d - %d %s" % [series.games.size() + (0 if live_snap.is_empty() else 1), UIKit.club_label(series.a), int(series.wins[series.a.club_id]), int(series.wins[series.b.club_id]), UIKit.club_label(series.b)]
	mc = MatchCenter.new().setup(session, hs)
	mc.custom_minimum_size = Vector2(0, 560)
	mc.reached_end.connect(_on_center_end)
	add_child(mc)
	bottom = UIKit.vbox(8)
	add_child(bottom)


func _on_center_end() -> void:
	if live_snap.is_empty():
		_end_of_game()
	else:
		_show_orders()


func _play_live() -> void:
	live_snap = {"pending": true}
	_open_center()
	header.text += "　・即時指揮"
	_apply_live(session.start_live_game(ds))


func _live_order(order: String) -> void:
	_apply_live(session.live_continue(order))


func _live_skip() -> void:
	_apply_live(session.live_finish())


func _apply_live(snap: Dictionary) -> void:
	UIKit.clear(bottom)
	UIKit.clear(mc.action)
	if snap.get("done", false):
		game = snap["game"]
		live_snap = {}
		mc.load(game)
		bottom.add_child(UIKit.button("跳到結果  »", func(): mc.skip_to_end()))
		if is_inside_tree():
			mc.play_to_end()
		else:
			mc.skip_to_end()
		return
	live_snap = snap
	mc.load(snap)
	bottom.add_child(UIKit.muted("比賽進行中……第 %d 分鐘會暫停讓你調整戰術" % int(snap["next_call"])))
	if is_inside_tree():
		mc.play_to_end()
	else:
		mc.skip_to_end()


func _show_orders() -> void:
	UIKit.clear(bottom)
	var box: VBoxContainer = mc.action
	UIKit.clear(box)
	var snap = live_snap
	var side: String = snap["side"]
	var opp = "red" if side == "blue" else "blue"
	var gd = int(snap["gold"][side]) - int(snap["gold"][opp])
	var late_edge = float(snap["comp_late"][side]) - float(snap["comp_late"][opp])
	box.add_child(UIKit.label("第 %d 分鐘戰術調整" % int(snap["next_call"]), 17, UIKit.WARN))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_child(UIKit.pill("目前：" + ORDER_INFO.get(snap["stances"][side], ["", snap["stances"][side]])[1], UIKit.ACCENT))
	tags.add_child(UIKit.pill("分析師：" + _advice(gd, late_edge), UIKit.GOOD))
	box.add_child(tags)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for o in ORDERS:
		var info: Array = ORDER_INFO[o]
		var b := UIKit.tile(info[0], info[1], ORDER_DESC[o], _live_order.bind("" if o == "none" else o), UIKit.ACCENT, 104)
		b.custom_minimum_size.y = 62
		b.name = "Order_" + o
		grid.add_child(b)
	var fin := UIKit.tile("SKIP", "直接打完", "不再介入", _live_skip, UIKit.MUTED, 104)
	fin.custom_minimum_size.y = 62
	grid.add_child(fin)
	box.add_child(grid)


static func _advice(gd: int, late_edge: float) -> String:
	if gd > 3000:
		return "經濟領先，主動進攻擴大優勢"
	if gd > 1000:
		return "小幅領先，物件控制穩住節奏" if late_edge < 0.5 else "陣容後期也強，穩穩物件控制"
	if gd < -3000:
		return "大幅落後，拖後期等對手失誤" if late_edge > -0.5 else "落後且後期不佔優，考慮抓單找機會"
	if gd < -1000:
		return "小幅落後，避戰拖後期" if late_edge > 0.0 else "分推牽制，避免正面團戰"
	return "均勢，依陣容特性選擇：%s" % ("拖後期" if late_edge > 0.5 else ("主動進攻" if late_edge < -0.5 else "物件控制"))


func _end_of_game() -> void:
	if bottom == null or bottom.has_node("EndBox"):
		return
	UIKit.clear(bottom)
	var v := UIKit.vbox(8)
	v.name = "EndBox"
	var ww = w()
	var won: bool = game["winner_club"] == ww.human_club_id
	var banner := UIKit.hbox(12)
	banner.add_child(UIKit.label("勝利！" if won else "落敗", 26, UIKit.GOOD if won else UIKit.BAD))
	banner.add_child(UIKit.label("%s 獲勝　%d 分鐘" % [UIKit.club_label(ww.clubs[game["winner_club"]]), int(game["duration"])], 17))
	var mvp: Player = ww.players.get(game.get("mvp", ""))
	if mvp:
		banner.add_child(UIKit.pill("MVP　" + mvp.handle, UIKit.WARN))
	v.add_child(banner)
	v.add_child(MatchView.stats_table(session, game))
	if series.is_done():
		v.add_child(UIKit.primary("完成系列賽", _finish))
	else:
		v.add_child(UIKit.primary("下一局 BP ▶", _new_game))
	bottom.add_child(v)


func _finish() -> void:
	session.finish_match()
	shell.refresh_status()
	shell.after_match()
