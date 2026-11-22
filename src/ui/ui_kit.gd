## UI 工具：深色電競管理風格的主題與常用元件。所有畫面都以程式碼建立，方便無頭測試。
class_name UIKit
extends RefCounted

const BG := Color("0f1115")
const PANEL := Color("171a21")
const PANEL_2 := Color("1e222b")
const BORDER := Color("2a2f3a")
const TEXT := Color("e6e8ec")
const MUTED := Color("8a90a0")
const ACCENT := Color("4f8cff")
const GOOD := Color("3ecf8e")
const BAD := Color("ff5c5c")
const WARN := Color("f5b83d")
const BLUE_SIDE := Color("4f8cff")
const RED_SIDE := Color("ff6b6b")

const ROLE_NAMES := {"TOP": "上路", "JUNGLE": "打野", "MID": "中路", "ADC": "下路", "SUPPORT": "輔助"}
const PLAN_NAMES := {"flexible": "彈性（依陣容）", "early_aggression": "前期進攻", "late_scaling": "後期發育", "split_push": "分推", "teamfight": "團戰", "pick": "抓單", "poke_siege": "消耗圍塔", "protect": "保護後排"}
const PHASE_NAMES := {"preseason": "季前賽", "regular": "例行賽", "playoffs": "季後賽", "offseason": "休賽季（轉會期）"}
const TRAINING_NAMES := {"solo_queue": "Solo Queue", "champion_practice": "英雄練習", "scrims": "Scrims 練習賽", "tactical_review": "戰術檢討", "vod_review": "VOD 分析", "draft_practice": "BP 演練", "team_building": "團隊建立", "mental_coaching": "心理輔導", "physical": "體能訓練", "rest": "休息"}
const SKILL_NAMES := {"mechanics": "操作", "laning": "對線", "map_awareness": "地圖意識", "positioning": "站位", "teamfighting": "團戰", "decision_making": "決策", "adaptability": "適應力", "consistency": "穩定性", "clutch": "關鍵表現", "wave_management": "兵線理解", "resource_trading": "資源交換", "vision": "視野控制", "shotcalling": "指揮", "draft_iq": "BP 理解"}
const TRAIT_NAMES := {"ambition": "野心", "loyalty": "忠誠", "professionalism": "職業態度", "composure": "抗壓性", "teamwork": "團隊合作", "communication": "溝通", "discipline": "紀律", "temperament": "情緒穩定"}
const GOAL_NAMES := {"WIN_TITLES": "爭奪冠軍", "PLAYING_TIME": "上場時間", "DEVELOP": "個人成長", "MONEY": "高薪", "RETIRE_AT_CLUB": "在母隊退役", "GO_ABROAD": "海外發展", "STABILITY": "穩定"}
const RESPONSE_NAMES := {"promise_playing_time": "承諾給予上場時間", "explain_situation": "解釋球隊狀況", "demand_patience": "要求他保持耐心", "transfer_list": "放上轉會名單", "dismiss": "不予理會", "accept_offer": "接受報價", "reject_offer": "拒絕報價", "acknowledge": "知道了"}


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	var panel = _box(PANEL, BORDER, 6)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var c = PANEL_2
		if state == "hover":
			c = Color("262b36")
		elif state == "pressed":
			c = ACCENT.darkened(0.3)
		elif state == "disabled":
			c = Color("15171c")
		var sb = _box(c, BORDER if state != "focus" else ACCENT, 5)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		t.set_stylebox(state, "Button", sb)
		t.set_stylebox(state, "OptionButton", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_stylebox("normal", "LineEdit", _box(Color("12151a"), BORDER, 5))
	t.set_stylebox("focus", "LineEdit", _box(Color("12151a"), ACCENT, 5))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "Tree", _box(Color("12151a"), BORDER, 5))
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("title_button_color", "Tree", MUTED)
	t.set_stylebox("title_button_normal", "Tree", _box(PANEL_2, BORDER, 0))
	t.set_stylebox("selected", "Tree", _box(ACCENT.darkened(0.45), ACCENT, 3))
	t.set_stylebox("selected_focus", "Tree", _box(ACCENT.darkened(0.45), ACCENT, 3))
	t.set_constant("v_separation", "Tree", 6)
	t.set_stylebox("panel", "ItemList", _box(Color("12151a"), BORDER, 5))
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	return t


static func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func label(text: String, size: int = 15, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String) -> Label:
	return label(text, 22, TEXT)


static func muted(text: String) -> Label:
	return label(text, 13, MUTED)


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


static func primary(text: String, cb: Callable) -> Button:
	var b = button(text, cb)
	var sb = _box(ACCENT.darkened(0.15), ACCENT, 5)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", _box(ACCENT, ACCENT, 5))
	return b


static func panel(child: Control = null) -> PanelContainer:
	var p := PanelContainer.new()
	if child:
		p.add_child(child)
	return p


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func rich(text: String = "") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


static func table(columns: Array, min_height: int = 300) -> Tree:
	var t := Tree.new()
	t.columns = columns.size()
	t.column_titles_visible = true
	t.hide_root = true
	t.select_mode = Tree.SELECT_ROW
	t.custom_minimum_size = Vector2(0, min_height)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in columns.size():
		t.set_column_title(i, columns[i])
		t.set_column_expand(i, i == 0 or i == 1)
		if i > 1:
			t.set_column_custom_minimum_width(i, 70)
	t.create_item()
	return t


static func clear_table(t: Tree) -> void:
	t.clear()
	t.create_item()


static func add_row(t: Tree, values: Array, meta: Variant = null) -> TreeItem:
	var it = t.create_item(t.get_root())
	for i in values.size():
		it.set_text(i, str(values[i]))
	if meta != null:
		it.set_metadata(0, meta)
	return it


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func option(items: Array, selected: int = 0) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(str(items[i]), i)
	if items.size() > 0:
		o.select(clampi(selected, 0, items.size() - 1))
	return o


static func money(v: int) -> String:
	var neg = v < 0
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + "$" + s + out


## 能力值顏色：協助快速判讀
static func skill_color(v: float) -> Color:
	if v >= 80:
		return GOOD
	if v >= 65:
		return Color("9ad66b")
	if v >= 50:
		return WARN
	return BAD


static func bar_text(v: float, width: int = 10) -> String:
	var n = clampi(int(round(v / 100.0 * width)), 0, width)
	return "█".repeat(n) + "░".repeat(width - n)


static func philosophy_name(p: String) -> String:
	return {"win_now": "立即爭冠", "develop": "培養新人", "balanced": "平衡", "moneyball": "性價比"}.get(p, p)
