## UI 工具：海克斯風格（深藍底、金色描邊、青色點綴）的主題與常用元件。
## 所有畫面都以程式碼建立，方便無頭測試。
class_name UIKit
extends RefCounted

const BG := Color("10132b")          ## 夜幕藍：全畫面底色
const BG_2 := Color("0b0e22")        ## 上方狀態列、側欄
const PANEL := Color("1a1f45")       ## 面板
const PANEL_2 := Color("222858")     ## 按鈕、表頭
const PANEL_3 := Color("2c3470")     ## 滑過
const BORDER := Color("2c3470")      ## 分隔線
const GOLD := Color("ffd23f")        ## 訊號黃：唯一的強調色（主要按鈕、選取、重點數字）
const GOLD_DIM := Color("8a7424")
const GOLD_LIGHT := Color("f4f5ff")  ## 標題白
const HEX := Color("19b8a6")
const TEXT := Color("e6e8fa")
const MUTED := Color("9aa0c8")
const ACCENT := Color("ffd23f")
const INK := Color("14163a")         ## 黃底上的深色字
const GOOD := Color("58e0a8")
const BAD := Color("ff4d5e")
const WARN := Color("ffb547")
const BLUE_SIDE := Color("3d9bff")
const RED_SIDE := Color("ff4d5e")
const SKEW := 0.22                   ## 斜切按鈕的傾斜量（轉播風格）

const CLASS_NAMES := {"tank": "坦克", "fighter": "戰士", "assassin": "刺客", "mage": "法師", "marksman": "射手", "enchanter": "輔助"}
const TAG_NAMES := {"engage": "開戰", "disengage": "反開", "poke": "消耗", "pick": "抓單", "splitpush": "分推", "teamfight": "團戰", "peel": "保護", "frontline": "前排", "burst": "爆發", "dps": "持續輸出", "waveclear": "清線", "mobility": "機動", "siege": "攻城"}
const ROLE_SHORT := {"TOP": "TOP", "JUNGLE": "JG", "MID": "MID", "ADC": "ADC", "SUPPORT": "SUP"}
const ROLE_NAMES := {"TOP": "上路", "JUNGLE": "打野", "MID": "中路", "ADC": "下路", "SUPPORT": "輔助"}
const PLAN_NAMES := {"flexible": "彈性（依陣容）", "early_aggression": "前期進攻", "late_scaling": "後期發育", "split_push": "分推", "teamfight": "團戰", "pick": "抓單", "poke_siege": "消耗圍塔", "protect": "保護後排"}
const PHASE_NAMES := {"preseason": "季前賽", "regular": "例行賽", "playoffs": "季後賽", "international": "世界賽", "offseason": "休賽季（轉會期）"}
const TRAINING_NAMES := {"solo_queue": "Solo Queue", "champion_practice": "英雄練習", "scrims": "Scrims 練習賽", "tactical_review": "戰術檢討", "vod_review": "VOD 分析", "draft_practice": "BP 演練", "team_building": "團隊建立", "mental_coaching": "心理輔導", "physical": "體能訓練", "rest": "休息"}
const SKILL_NAMES := {"mechanics": "操作", "laning": "對線", "map_awareness": "地圖意識", "positioning": "站位", "teamfighting": "團戰", "decision_making": "決策", "adaptability": "適應力", "consistency": "穩定性", "clutch": "關鍵表現", "wave_management": "兵線理解", "resource_trading": "資源交換", "vision": "視野控制", "shotcalling": "指揮", "draft_iq": "BP 理解"}
const TRAIT_NAMES := {"ambition": "野心", "loyalty": "忠誠", "professionalism": "職業態度", "composure": "抗壓性", "teamwork": "團隊合作", "communication": "溝通", "discipline": "紀律", "temperament": "情緒穩定"}
const GOAL_NAMES := {"WIN_TITLES": "爭奪冠軍", "PLAYING_TIME": "上場時間", "DEVELOP": "個人成長", "MONEY": "高薪", "RETIRE_AT_CLUB": "在母隊退役", "GO_ABROAD": "海外發展", "STABILITY": "穩定"}
const RESPONSE_NAMES := {"promise_playing_time": "承諾給予上場時間", "explain_situation": "解釋球隊狀況", "demand_patience": "要求他保持耐心", "transfer_list": "放上轉會名單", "dismiss": "不予理會", "accept_offer": "接受報價", "reject_offer": "拒絕報價", "acknowledge": "知道了", "mediate": "出面調解", "back_first": "支持先開口的一方", "ignore": "不介入", "accept_raise": "同意加薪", "refuse_raise": "拒絕加薪"}


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.default_font = body_font()
	var panel = _card(PANEL, 0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	# 按鈕：深色底、細描邊，滑過時金色描邊，按下時金色底
	var states := {
		"normal": [PANEL_2, Color(0, 0, 0, 0)],
		"hover": [PANEL_3, GOLD],
		"pressed": [GOLD, GOLD],
		"hover_pressed": [GOLD, GOLD],
		"focus": [PANEL_2, GOLD],
		"disabled": [Color("151935"), Color(0, 0, 0, 0)],
	}
	for state in states:
		var sb = _box(states[state][0], states[state][1], 0)
		sb.set_border_width_all(0)
		sb.border_width_bottom = 2
		sb.skew = Vector2(SKEW, 0)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		if state == "focus":
			sb.draw_center = false
		t.set_stylebox(state, "Button", sb)
		t.set_stylebox(state, "OptionButton", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD_LIGHT)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_font("font", "Button", head_font())
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_color("font_color", "OptionButton", TEXT)
	var le = _box(Color("12163a"), BORDER, 6)
	le.content_margin_left = 12
	t.set_stylebox("normal", "LineEdit", le)
	var lef = _box(Color("12163a"), GOLD, 6)
	lef.content_margin_left = 12
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED.darkened(0.2))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_stylebox("normal", "SpinBox", le)
	# 表格
	t.set_stylebox("panel", "Tree", _box(PANEL, PANEL, 0))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", GOLD_LIGHT)
	t.set_color("title_button_color", "Tree", MUTED)
	t.set_font("title_button_font", "Tree", head_font())
	var th = _box(BG_2, BORDER, 0)
	th.set_border_width_all(0)
	th.border_width_bottom = 2
	th.content_margin_top = 8
	th.content_margin_bottom = 8
	t.set_stylebox("title_button_normal", "Tree", th)
	t.set_stylebox("title_button_hover", "Tree", th)
	t.set_stylebox("title_button_pressed", "Tree", th)
	var sel = _box(Color(GOLD, 0.14), Color(0, 0, 0, 0), 0)
	sel.set_border_width_all(0)
	sel.border_width_left = 4
	sel.border_color = GOLD
	t.set_stylebox("selected", "Tree", sel)
	t.set_stylebox("selected_focus", "Tree", sel)
	t.set_stylebox("hovered", "Tree", _box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 4))
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.04))
	t.set_constant("v_separation", "Tree", 8)
	t.set_constant("h_separation", "Tree", 10)
	t.set_stylebox("panel", "ItemList", _box(Color("12163a"), BORDER, 6))
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	# 卷軸：細、圓角、金色
	for sb_name in ["VScrollBar", "HScrollBar"]:
		var track = StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.03)
		track.set_corner_radius_all(4)
		track.content_margin_left = 3
		track.content_margin_right = 3
		var grab = StyleBoxFlat.new()
		grab.bg_color = Color(GOLD, 0.35)
		grab.set_corner_radius_all(4)
		var grab_h = grab.duplicate()
		grab_h.bg_color = Color(GOLD, 0.6)
		t.set_stylebox("scroll", sb_name, track)
		t.set_stylebox("grabber", sb_name, grab)
		t.set_stylebox("grabber_highlight", sb_name, grab_h)
		t.set_stylebox("grabber_pressed", sb_name, grab_h)
	# 下拉選單與提示
	var pop = _box(Color("12163a"), GOLD_DIM, 6)
	pop.shadow_color = Color(0, 0, 0, 0.5)
	pop.shadow_size = 10
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", _box(Color(GOLD, 0.18), Color(0, 0, 0, 0), 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD_LIGHT)
	var tip = _box(Color("12163a"), GOLD_DIM, 6)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("separator", "HSeparator", _line(Color(GOLD, 0.25)))
	t.set_constant("separation", "HSeparator", 12)
	# 勾選框
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", GOLD_LIGHT)
	t.set_color("font_pressed_color", "CheckBox", GOLD_LIGHT)
	t.set_color("font_hover_pressed_color", "CheckBox", GOLD_LIGHT)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var cb = _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6)
		cb.draw_center = false
		t.set_stylebox(st, "CheckBox", cb)
	t.set_icon("unchecked", "CheckBox", _check_icon(false))
	t.set_icon("checked", "CheckBox", _check_icon(true))
	t.set_icon("unchecked_disabled", "CheckBox", _check_icon(false))
	t.set_icon("checked_disabled", "CheckBox", _check_icon(true))
	return t


## 勾選框圖示：金色細框方塊；勾選時金底深色勾。
static func _check_icon(on: bool) -> ImageTexture:
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var edge := x <= 1 or y <= 1 or x >= n - 2 or y >= n - 2
			if on:
				img.set_pixel(x, y, GOLD if edge else GOLD.darkened(0.1))
			elif edge:
				img.set_pixel(x, y, GOLD_DIM.lightened(0.2))
			else:
				img.set_pixel(x, y, Color(PANEL_2, 0.9))
	if on:
		# 勾：兩段粗線
		var pts := [Vector2(4, 9), Vector2(7, 12), Vector2(13, 5)]
		for seg in 2:
			var a: Vector2 = pts[seg]
			var b: Vector2 = pts[seg + 1]
			for i in 24:
				var q := a.lerp(b, i / 23.0)
				for dx in [0, 1]:
					for dy in [0, 1]:
						img.set_pixel(clampi(int(q.x) + dx, 0, n - 1), clampi(int(q.y) + dy, 0, n - 1), BG)
	return ImageTexture.create_from_image(img)


## 字型：內建 Noto Sans TC（400／700／900）與 Barlow Condensed，缺字時退回系統繁中字型。
static var _body_font: Font = null
static var _head_font: Font = null


## 全畫面背景：上方偏藍、往下與四周變暗的漸層。
static func backdrop() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color("1a1f4a"))
	g.set_color(1, BG)
	g.add_point(0.55, Color("12153a"))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.62, 0.0)
	t.fill_to = Vector2(0.1, 1.15)
	t.width = 512
	t.height = 512
	var r := TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func body_font() -> Font:
	if _body_font == null:
		_body_font = _bundled("NotoSansTC-400.ttf")
	return _body_font


## 粗體（標題、按鈕、名稱）。
static func head_font() -> Font:
	if _head_font == null:
		_head_font = _bundled("NotoSansTC-700.ttf")
	return _head_font


## 特粗（大標題、對戰橫幅）。
static var _display_font: Font = null
static func display_font() -> Font:
	if _display_font == null:
		_display_font = _bundled("NotoSansTC-900.ttf")
	return _display_font


## 數字與英文代號：窄體粗斜（能力值、比分、隊伍縮寫）。中文字會落到 Noto Sans TC 特粗。
static var _num_font: Font = null
static func num_font() -> Font:
	if _num_font == null:
		_num_font = _bundled("BarlowCondensed-800i.ttf", display_font())
	return _num_font


## 窄體（位置代號、小標籤裡的英文）。
static var _cond_font: Font = null
static func cond_font() -> Font:
	if _cond_font == null:
		_cond_font = _bundled("BarlowCondensed-600.ttf", head_font())
	return _cond_font


## 載入內建字型（assets/fonts，SIL OFL）。缺字時依序退回指定字型與系統繁中字型。
static func _bundled(file: String, fallback: Font = null) -> Font:
	var path := "res://assets/fonts/" + file
	var f: FontFile = load(path) if ResourceLoader.exists(path) else null
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "PingFang TC", "Noto Sans CJK TC", "Noto Sans TC", "Source Han Sans TC", "Noto Sans CJK JP", "sans-serif"])
	if f == null:
		return sys
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	var fb: Array[Font] = []
	if fallback:
		fb.append(fallback)
	fb.append(sys)
	f.fallbacks = fb
	return f


## 卡片：深色底、細描邊、柔和陰影。
static func _card(bg: Color, radius: int) -> StyleBoxFlat:
	var sb = _box(bg, Color(0, 0, 0, 0), radius)
	sb.set_border_width_all(0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


static func _line(c: Color) -> StyleBoxLine:
	var l := StyleBoxLine.new()
	l.color = c
	l.thickness = 1
	return l


static func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(mini(radius, 2))
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.anti_aliasing = true
	return sb


static func label(text: String, size: int = 15, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String) -> Label:
	var l = label(text, 28, GOLD_LIGHT)
	l.add_theme_font_override("font", display_font())
	return l


## 區塊標題：金色小字 + 細線。
static func section(text: String) -> VBoxContainer:
	var v := vbox(6)
	var l = label(text, 18, GOLD_LIGHT)
	l.add_theme_font_override("font", display_font())
	v.add_child(l)
	var line := ColorRect.new()
	line.color = BORDER
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	return v


static func muted(text: String) -> Label:
	return label(text, 13, MUTED)


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


## 主要動作按鈕：訊號黃實心、斜切、深色粗字。整個畫面通常只有一個。
static func primary(text: String, cb: Callable) -> Button:
	var b = button(text, cb)
	var sb = _box(GOLD, GOLD, 0)
	sb.set_border_width_all(0)
	sb.skew = Vector2(SKEW, 0)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	var hv = sb.duplicate()
	hv.bg_color = GOLD.lightened(0.25)
	var dis = sb.duplicate()
	dis.bg_color = Color(GOLD, 0.3)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("hover_pressed", hv)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.6))
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", 17)
	return b


static func panel(child: Control = null) -> PanelContainer:
	var p := PanelContainer.new()
	if child:
		p.add_child(child)
	return p


## 帶左側色條的卡片（待處理事項、提醒）。
static func accent_panel(child: Control, color: Color = GOLD) -> PanelContainer:
	var p := panel(child)
	var sb = _card(PANEL, 0)
	sb.border_width_left = 4
	sb.border_color = color
	p.add_theme_stylebox_override("panel", sb)
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


## expand：哪些欄位分配剩餘寬度（預設第 0、1 欄）；其他欄依標題長度給固定最小寬度。
static func table(columns: Array, min_height: int = 300, expand: Array = [0, 1]) -> Tree:
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
		var title_len: int = str(columns[i]).length()
		var grow: bool = i in expand and title_len > 1
		t.set_column_expand(i, grow)
		if grow:
			t.set_column_expand_ratio(i, 3 if i == expand[0] else 2)
		else:
			t.set_column_custom_minimum_width(i, 48 if title_len <= 1 else maxi(84, title_len * 17 + 30))
	t.create_item()
	return t


static func clear_table(t: Tree) -> void:
	t.clear()
	t.create_item()


static func add_row(t: Tree, values: Array, meta: Variant = null) -> TreeItem:
	var it = t.create_item(t.get_root())
	var zebra = t.get_root().get_child_count() % 2 == 0
	for i in values.size():
		it.set_text(i, str(values[i]))
		if zebra:
			it.set_custom_bg_color(i, Color(1, 1, 1, 0.025))
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


## 系列賽賽制
static func bo_text(n: int) -> String:
	return "Bo%d" % n


## 俱樂部顯示：全名（縮寫）
static func club_label(c) -> String:
	if c == null:
		return "?"
	return "%s（%s）" % [c.name, c.short_name] if c.short_name != "" else c.name


## 英雄說明（tooltip 用）
static func champion_info(c: Champion) -> String:
	var tags: Array = c.tags.keys()
	tags.sort_custom(func(a, b): return c.tags[a] > c.tags[b])
	var parts = tags.map(func(t): return "%s %s" % [TAG_NAMES.get(t, t), "★".repeat(int(c.tags[t]))])
	return "%s %s・%s・%s\n位置：%s\n強勢期：前 %d／中 %d／後 %d　對線 %d　難度 %d\n特性：%s" % [c.name, c.name_en, CLASS_NAMES.get(c.class_type, c.class_type), "物理" if c.damage == "AD" else "魔法",
		"、".join(c.roles.map(func(r): return ROLE_NAMES.get(r, r))), int(c.early), int(c.mid), int(c.late), int(c.lane), int(c.difficulty), "、".join(parts)]


## 切換式小按鈕（篩選、速度、分頁）：斜切，選取時黃底深字。
static func chip(text: String, cb: Callable) -> Button:
	var b := button(text, cb)
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 13)
	var off = _box(PANEL_2, Color(0, 0, 0, 0), 0)
	var hv = _box(PANEL_3, Color(0, 0, 0, 0), 0)
	var on = _box(GOLD, Color(0, 0, 0, 0), 0)
	for sb in [on, off, hv]:
		sb.set_border_width_all(0)
		sb.skew = Vector2(SKEW, 0)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)
	return b


## 圓角標籤（狀態、分類、提示）。
static func pill(text: String, color: Color = ACCENT) -> PanelContainer:
	var p := PanelContainer.new()
	var sb = _box(Color(color, 0.16), Color(0, 0, 0, 0), 0)
	sb.set_border_width_all(0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, 13, color.lightened(0.25)))
	return p


## 大型選項按鈕：上方代號、中間名稱、下方一行說明。
static func tile(code: String, name: String, desc: String, cb: Callable, color: Color = ACCENT, width: int = 150) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(width, 78)
	b.pressed.connect(cb)
	b.tooltip_text = desc
	var n = _box(PANEL_2, color, 0)
	n.set_border_width_all(0)
	n.border_width_top = 3
	var h = n.duplicate()
	h.bg_color = PANEL_3
	var pr = h.duplicate()
	pr.bg_color = Color(color, 0.22)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var code_l = label(code, 13, color)
	code_l.add_theme_font_override("font", num_font())
	var name_l = label(name, 16, GOLD_LIGHT)
	name_l.add_theme_font_override("font", head_font())
	for l in [code_l, name_l, label(desc, 12, MUTED)]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		v.add_child(l)
	b.add_child(v)
	return b


## 數值條：名稱 + 條 + 數字，取代「█░」文字條。
static func stat_bar(name: String, v: float, max_v: float = 100.0, width: int = 120, color: Color = Color(0, 0, 0, 0), label_w: int = 72, value_text: String = "") -> HBoxContainer:
	var h := hbox(6)
	var l := label(name, 13, MUTED)
	l.custom_minimum_size = Vector2(label_w, 0)
	h.add_child(l)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = max_v
	pb.value = v
	pb.custom_minimum_size = Vector2(width, 7)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c = color if color.a > 0 else skill_color(v / max_v * 100.0)
	var bg = _box(Color("262d63"), Color(0, 0, 0, 0), 0)
	var fill = _box(c, c, 0)
	bg.set_border_width_all(0)
	fill.set_border_width_all(0)
	for sb in [bg, fill]:
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		sb.content_margin_left = 0
		sb.content_margin_right = 0
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)
	h.add_child(pb)
	h.add_child(label(value_text if value_text != "" else str(int(round(v))), 13, c))
	return h


## 資訊卡：小標題 + 大數字（窄體粗斜）+ 一行補充。上方色條代表類別。
static func stat_card(title_text: String, big: String, small: String = "", color: Color = TEXT) -> PanelContainer:
	var v := vbox(0)
	v.add_child(label(title_text, 13, MUTED))
	var bl = label(big, 32, color if color != TEXT else GOLD_LIGHT)
	bl.add_theme_font_override("font", num_font())
	v.add_child(bl)
	if small != "":
		v.add_child(label(small, 13, MUTED))
	var p := panel(v)
	var sb = _card(PANEL, 0)
	sb.border_width_top = 3
	sb.border_color = color if color != TEXT else GOLD
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


## 大數字標籤（能力值、比分）。
static func big_num(text: String, size: int = 40, color: Color = GOLD) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", num_font())
	return l


## 粗體標籤。
static func bold(text: String, size: int = 15, color: Color = GOLD_LIGHT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", head_font())
	return l


## 大型按鈕（卡片式選項）不斜切：平面底色，滑過變亮、選取時下方黃線。
static func flat(b: Button) -> Button:
	var states := {"normal": [PANEL_2, Color(0, 0, 0, 0)], "hover": [PANEL_3, Color(0, 0, 0, 0)], "pressed": [PANEL_3, GOLD], "hover_pressed": [PANEL_3, GOLD], "disabled": [Color("151935"), Color(0, 0, 0, 0)]}
	for st in states:
		var sb = _box(states[st][0], states[st][1], 0)
		sb.set_border_width_all(0)
		sb.border_width_bottom = 3
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, GOLD_LIGHT)
	return b
