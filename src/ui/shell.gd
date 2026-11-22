## 管理介面外框：左側導覽、上方狀態列（日期／資金／繼續）、中央畫面。
class_name Shell
extends VBoxContainer

const PAGES := [
	["dashboard", "總覽"], ["roster", "名單"], ["tactics", "戰術與陣容"], ["training", "訓練"],
	["transfers", "轉會中心"], ["staff", "教練團"], ["finance", "財務"], ["competition", "賽事"], ["inbox", "收件匣"], ["history", "歷史"], ["saves", "存檔"],
]

var session: GameSession
var app: Node
var content: MarginContainer
var status: Label
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
	top.add_theme_stylebox_override("panel", UIKit._box(UIKit.PANEL, UIKit.BORDER, 0))
	var bar := UIKit.hbox(14)
	top.add_child(bar)
	add_child(top)
	bar.add_child(UIKit.label("ESPORT: LOL SIMULATOR", 16, UIKit.ACCENT))
	status = UIKit.label("", 15)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	status.custom_minimum_size = Vector2(200, 0)
	bar.add_child(status)
	toast_label = UIKit.label("", 14, UIKit.WARN)
	bar.add_child(toast_label)
	bar.add_child(UIKit.button("推進一週", _on_week))
	continue_btn = UIKit.primary("繼續 ▶", _on_continue)
	bar.add_child(continue_btn)
	# 主體
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", UIKit._box(UIKit.PANEL, UIKit.BORDER, 0))
	side.custom_minimum_size = Vector2(170, 0)
	var nv := UIKit.vbox(4)
	side.add_child(nv)
	body.add_child(side)
	for p in PAGES:
		var b := UIKit.button(p[1], open.bind(p[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		nv.add_child(b)
		nav[p[0]] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	content = MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + m, 18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	open("dashboard")
	return self


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
	status.text = "%s　｜　%d 年　第 %d 天　%s　｜　資金 %s　｜　收件匣 %d" % [c.short_name if c else "", w.year, w.day, UIKit.PHASE_NAMES.get(w.phase, w.phase), UIKit.money(c.cash) if c else "", unread]
	nav["inbox"].text = "收件匣 (%d)" % unread if unread > 0 else "收件匣"
	continue_btn.text = "比賽日：進入 BP ▶" if session.has_match_ready() else "繼續 ▶"


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
