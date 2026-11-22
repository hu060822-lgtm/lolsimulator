## 管理介面外框：左側導覽、上方狀態列（日期／資金／繼續）、中央畫面。
class_name Shell
extends VBoxContainer

const PAGES := [
	["dashboard", "總覽"], ["roster", "名單"], ["tactics", "戰術與陣容"], ["training", "訓練"],
	["transfers", "轉會中心"], ["staff", "教練團"], ["finance", "財務"], ["competition", "賽事"], ["news", "媒體"], ["inbox", "收件匣"], ["history", "歷史"], ["saves", "存檔"],
]
## 側欄分組：[標題, [頁面 id…]]
const GROUPS := [
	["俱樂部", ["dashboard", "roster", "tactics", "training"]],
	["營運", ["transfers", "staff", "finance"]],
	["賽事與媒體", ["competition", "news", "inbox", "history"]],
	["系統", ["saves"]],
]

var session: GameSession
var app: Node
var content: MarginContainer
var status: Label
var date_pill: Label
var phase_pill: Label
var cash_label: Label
var club_name: Label
var crest_box: Control
var continue_btn: Button
var nav: Dictionary = {}
var page: UIScreen
var page_id: String = ""
var toast_label: Label


func setup(s: GameSession, a: Node) -> Shell:
	session = s
	app = a
	add_theme_constant_override("separation", 0)
	# 上方狀態列
	var top := PanelContainer.new()
	var tsb := UIKit._box(Color(UIKit.BG_2, 0.92), UIKit.GOLD_DIM, 0)
	tsb.border_width_left = 0
	tsb.border_width_right = 0
	tsb.border_width_top = 0
	tsb.border_width_bottom = 1
	tsb.content_margin_left = 18
	tsb.content_margin_right = 14
	tsb.content_margin_top = 8
	tsb.content_margin_bottom = 8
	top.add_theme_stylebox_override("panel", tsb)
	var bar := UIKit.hbox(12)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_child(bar)
	add_child(top)
	var logo := UIKit.vbox(0)
	var l1 := UIKit.label("ESPORT", 11, UIKit.GOLD)
	l1.add_theme_font_override("font", UIKit.head_font())
	logo.add_child(l1)
	var l2 := UIKit.label("LOL SIMULATOR", 15, UIKit.GOLD_LIGHT)
	l2.add_theme_font_override("font", UIKit.head_font())
	logo.add_child(l2)
	bar.add_child(logo)
	bar.add_child(_vsep())
	date_pill = _stat_chip(bar, "日期")
	phase_pill = _stat_chip(bar, "階段")
	cash_label = _stat_chip(bar, "資金")
	cash_label.add_theme_color_override("font_color", UIKit.GOOD)
	# status：保留一個純文字摘要（截圖、無障礙），但不顯示
	status = UIKit.label("", 13, UIKit.MUTED)
	status.visible = false
	bar.add_child(status)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	toast_label = UIKit.label("", 14, UIKit.WARN)
	toast_label.clip_text = true
	bar.add_child(toast_label)
	var wk := UIKit.button("推進一週", _on_week)
	wk.custom_minimum_size = Vector2(0, 40)
	bar.add_child(wk)
	continue_btn = UIKit.primary("繼續 ▶", _on_continue)
	continue_btn.custom_minimum_size = Vector2(150, 40)
	bar.add_child(continue_btn)
	# 主體
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var side := PanelContainer.new()
	var ssb := UIKit._box(Color(UIKit.PANEL, 0.94), UIKit.BORDER, 0)
	ssb.border_width_left = 0
	ssb.border_width_top = 0
	ssb.border_width_bottom = 0
	ssb.content_margin_left = 10
	ssb.content_margin_right = 10
	ssb.content_margin_top = 14
	side.add_theme_stylebox_override("panel", ssb)
	side.custom_minimum_size = Vector2(196, 0)
	var nv := UIKit.vbox(2)
	side.add_child(nv)
	body.add_child(side)
	# 俱樂部名片
	var card := UIKit.hbox(10)
	crest_box = CenterContainer.new()
	card.add_child(crest_box)
	club_name = UIKit.label("", 14, UIKit.GOLD_LIGHT)
	club_name.add_theme_font_override("font", UIKit.head_font())
	club_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	club_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	club_name.custom_minimum_size = Vector2(110, 0)
	card.add_child(club_name)
	nv.add_child(card)
	var gap0 := Control.new()
	gap0.custom_minimum_size = Vector2(0, 8)
	nv.add_child(gap0)
	var names := {}
	for p in PAGES:
		names[p[0]] = p[1]
	for g in GROUPS:
		var gh := UIKit.hbox(6)
		var gl := UIKit.label(g[0], 11, UIKit.GOLD_DIM.lightened(0.25))
		gh.add_child(gl)
		var ln := HSeparator.new()
		ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ln.modulate = Color(1, 1, 1, 0.45)
		gh.add_child(ln)
		nv.add_child(gh)
		for id in g[1]:
			var b := UIKit.button(names[id], open.bind(id))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.toggle_mode = true
			_style_nav(b)
			nv.add_child(b)
			nav[id] = b
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		nv.add_child(gap)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	content = MarginContainer.new()
	for m in ["left", "right"]:
		content.add_theme_constant_override("margin_" + m, 24)
	for m in ["top", "bottom"]:
		content.add_theme_constant_override("margin_" + m, 20)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	open("dashboard")
	return self


## 狀態列上的小資訊塊：上方灰色小標、下方數值。回傳數值 Label。
func _stat_chip(parent: Control, cap: String) -> Label:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(cap, 10, UIKit.MUTED))
	var val := UIKit.label("", 14, UIKit.TEXT)
	v.add_child(val)
	parent.add_child(v)
	return val


func _vsep() -> Control:
	var s := VSeparator.new()
	s.modulate = Color(1, 1, 1, 0.5)
	return s


func open(id: String) -> void:
	for k in nav:
		nav[k].button_pressed = k == id
	var scr: UIScreen
	match id:
		"dashboard": scr = DashboardScreen.new()
		"roster": scr = RosterScreen.new()
		"tactics": scr = TacticsScreen.new()
		"training": scr = TrainingScreen.new()
		"transfers": scr = TransfersScreen.new()
		"competition": scr = CompetitionScreen.new()
		"staff": scr = StaffScreen.new()
		"finance": scr = FinanceScreen.new()
		"inbox": scr = InboxScreen.new()
		"news": scr = NewsScreen.new()
		"history": scr = HistoryScreen.new()
		"saves": scr = SavesScreen.new()
		_: scr = DashboardScreen.new()
	_show(scr.setup(session, self), id)


func open_screen(scr: UIScreen, id: String) -> void:
	for k in nav:
		nav[k].button_pressed = false
	_show(scr.setup(session, self), id)


func _show(scr: UIScreen, id: String) -> void:
	UIKit.clear(content)
	page = scr
	page_id = id
	content.add_child(scr)
	scr.refresh()
	refresh_status()


func refresh_status() -> void:
	var w = session.world
	var c = session.club()
	var unread = session.open_messages().size()
	var phase: String = UIKit.PHASE_NAMES.get(w.phase, w.phase)
	status.text = "%s　｜　%d 年　第 %d 天　%s　｜　資金 %s　｜　收件匣 %d" % [c.short_name if c else "", w.year, w.day, phase, UIKit.money(c.cash) if c else "", unread]
	date_pill.text = "%d 年 · 第 %d 天" % [w.year, w.day]
	phase_pill.text = phase
	cash_label.text = UIKit.money(c.cash) if c else "-"
	cash_label.add_theme_color_override("font_color", UIKit.GOOD if c == null or c.cash >= 0 else UIKit.BAD)
	if c and club_name.text != c.name:
		club_name.text = c.name
		UIKit.clear(crest_box)
		crest_box.add_child(Badge.club(c, 44))
	nav["inbox"].text = "收件匣　%d" % unread if unread > 0 else "收件匣"
	continue_btn.text = "進入 BP ▶" if session.has_match_ready() else "繼續 ▶"


func toast(text: String) -> void:
	toast_label.text = text


func _on_continue() -> void:
	toast("")
	if session.has_match_ready():
		open_match()
		return
	session.advance_to_next_match()
	if session.has_match_ready():
		toast("明天有比賽，準備 BP")
	if page:
		page.refresh()
	refresh_status()


func _on_week() -> void:
	toast("")
	var n = session.advance_days(7)
	if n < 7 and session.has_match_ready():
		toast("比賽日到了，請先完成比賽")
	if page:
		page.refresh()
	refresh_status()


func open_match() -> void:
	open_screen(DraftScreen.new(), "draft")


func after_match() -> void:
	open("competition")


## 側欄按鈕：未選取時透明，滑過時淡底，選取時左側金色亮條 + 金色漸層底。
func _style_nav(b: Button) -> void:
	var off := StyleBoxFlat.new()
	off.bg_color = Color(0, 0, 0, 0)
	off.content_margin_left = 14
	off.content_margin_top = 8
	off.content_margin_bottom = 8
	off.set_corner_radius_all(4)
	var hover = off.duplicate()
	hover.bg_color = Color(UIKit.PANEL_3, 0.8)
	var on := StyleBoxFlat.new()
	on.bg_color = Color(UIKit.GOLD, 0.14)
	on.border_color = UIKit.GOLD
	on.border_width_left = 3
	on.set_corner_radius_all(4)
	on.corner_radius_top_left = 0
	on.corner_radius_bottom_left = 0
	on.content_margin_left = 11
	on.content_margin_top = 8
	on.content_margin_bottom = 8
	on.shadow_color = Color(UIKit.GOLD, 0.12)
	on.shadow_size = 6
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_pressed_color", UIKit.GOLD_LIGHT)
	b.add_theme_color_override("font_hover_pressed_color", UIKit.GOLD_LIGHT)
	b.add_theme_color_override("font_hover_color", UIKit.TEXT)
	b.add_theme_color_override("font_color", UIKit.TEXT.darkened(0.25))
	b.add_theme_font_size_override("font_size", 15)
