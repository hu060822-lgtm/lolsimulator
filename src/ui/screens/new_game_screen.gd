## 開局：A. 接管模組中的俱樂部　C. 建立自訂俱樂部（取代聯賽中的一支隊伍）
class_name NewGameScreen
extends UIScreen

const MODULES := [
	["res://data/modules/lol_world", "REAL", "真實電競（致敬版）", "LCK／LPL／LEC／LTA／LCP"],
	["res://data/modules/fictional_base", "FICTION", "虛構世界", "原創俱樂部與賽區"],
]

var module_dir: String = MODULES[0][0]
var selected_club: String = ""
var league_chips: Dictionary = {}
var card_grid: HFlowContainer
var cards: Array = []
var clubs: Array = []
var leagues: Array = []
var seed_edit: LineEdit
var manual: CheckBox
var custom_name: LineEdit
var custom_short: LineEdit
var custom_league: OptionButton
var custom_cash: SpinBox
var info: RichTextLabel
var load_box: VBoxContainer


func build() -> void:
	clubs = GameSession.list_clubs(module_dir)
	leagues = GameSession.list_leagues(module_dir)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)
	var root := UIKit.vbox(12)
	margin.add_child(root)
	var title_row := UIKit.hbox(16)
	var tv := UIKit.vbox(0)
	var t1 := UIKit.label("ESPORT", 14, UIKit.GOLD)
	t1.add_theme_font_override("font", UIKit.head_font())
	tv.add_child(t1)
	var t2 := UIKit.label("LOL SIMULATOR", 36, UIKit.GOLD_LIGHT)
	t2.add_theme_font_override("font", UIKit.head_font())
	t2.add_theme_color_override("font_shadow_color", Color(UIKit.GOLD, 0.35))
	t2.add_theme_constant_override("shadow_offset_y", 2)
	tv.add_child(t2)
	title_row.add_child(tv)
	var tag := UIKit.label("Build a Legacy. Not Just a Team.", 15, UIKit.MUTED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(tag)
	root.add_child(title_row)
	# 資料庫選擇
	var mods := UIKit.hbox(8)
	for m in MODULES:
		var b := UIKit.tile(m[1], m[2], m[3], _switch_module.bind(m[0]), UIKit.WARN if m[0] == MODULES[0][0] else UIKit.ACCENT, 230)
		b.toggle_mode = true
		b.button_pressed = m[0] == module_dir
		mods.add_child(b)
	root.add_child(mods)
	var cols := UIKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# 左：接管俱樂部（聯賽分頁 + 隊徽卡片）
	var left := UIKit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lp = UIKit.panel(left)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.7
	cols.add_child(lp)
	left.add_child(UIKit.title("接管俱樂部"))
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	league_chips = {}
	for l in leagues:
		var b := UIKit.chip(str(l.get("short_name", "")) if str(l.get("short_name", "")) != "" else str(l["name"]), _filter_league.bind(str(l["id"])))
		b.tooltip_text = str(l["name"])
		league_chips[str(l["id"])] = b
		tabs.add_child(b)
	left.add_child(tabs)
	card_grid = HFlowContainer.new()
	card_grid.add_theme_constant_override("h_separation", 8)
	card_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(card_grid)
	info = UIKit.rich("[color=#8c95a4]選擇一支俱樂部。聲望越低，資源越少、挑戰越大。[/color]")
	left.add_child(info)
	_filter_league(str(leagues[0]["id"]) if not leagues.is_empty() else "")

	# 右：設定 + 自訂俱樂部 + 讀檔
	var right := UIKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rp = UIKit.panel(right)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(rp)
	right.add_child(UIKit.title("世界設定"))
	var seed_row := UIKit.hbox()
	seed_row.add_child(UIKit.label("世界種子"))
	seed_edit = LineEdit.new()
	seed_edit.text = str(randi() % 100000)
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(seed_edit)
	right.add_child(seed_row)
	manual = CheckBox.new()
	manual.text = "親自進行 BP"
	manual.button_pressed = true
	right.add_child(manual)
	if FileAccess.file_exists(DataModule.OVERLAY_DIR.path_join(module_dir.get_file() + ".json")):
		right.add_child(UIKit.pill("已套用真名名單", UIKit.GOOD))
	right.add_child(UIKit.primary("接管所選俱樂部  ▶", _start_selected))
	right.add_child(HSeparator.new())
	right.add_child(UIKit.label("建立自訂俱樂部", 17))
	right.add_child(UIKit.muted("取代所選聯賽中聲望最低的隊伍。"))
	var nm := UIKit.hbox(6)
	custom_name = LineEdit.new()
	custom_name.placeholder_text = "俱樂部名稱"
	custom_name.text = "Rising Phoenix"
	custom_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_child(custom_name)
	custom_short = LineEdit.new()
	custom_short.text = "RPX"
	custom_short.max_length = 4
	custom_short.custom_minimum_size = Vector2(70, 0)
	nm.add_child(custom_short)
	right.add_child(nm)
	custom_league = UIKit.option(leagues.map(func(l): return l["name"]))
	right.add_child(custom_league)
	var cash_row := UIKit.hbox()
	cash_row.add_child(UIKit.label("初始資金"))
	custom_cash = SpinBox.new()
	custom_cash.min_value = 200000
	custom_cash.max_value = 5000000
	custom_cash.step = 100000
	custom_cash.value = 800000
	custom_cash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cash_row.add_child(custom_cash)
	right.add_child(cash_row)
	right.add_child(UIKit.button("以自訂俱樂部開始", _start_custom))
	right.add_child(HSeparator.new())
	right.add_child(UIKit.label("讀取存檔", 17))
	load_box = UIKit.vbox(4)
	right.add_child(load_box)
	for slot in range(1, 4):
		var meta = GameSession.slot_info(slot)
		var txt = "存檔 %d：%s" % [slot, ("%s・%d 年・第 %d 天" % [meta["club"], int(meta["year"]), int(meta["day"])]) if not meta.is_empty() else "（空）"]
		var b := UIKit.button(txt, _load.bind(slot))
		b.disabled = meta.is_empty()
		load_box.add_child(b)


func _switch_module(dir: String) -> void:
	module_dir = dir
	selected_club = ""
	UIKit.clear(self)
	build()


func _filter_league(league_id: String) -> void:
	for k in league_chips:
		league_chips[k].button_pressed = k == league_id
	UIKit.clear(card_grid)
	cards = []
	for c in clubs:
		if c["league_id"] != league_id:
			continue
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 118)
		b.button_pressed = c["id"] == selected_club
		b.pressed.connect(_select_club.bind(c["id"]))
		var v := UIKit.vbox(2)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge := Badge.make(str(c.get("short_name", "")), Badge.club_color(str(c["id"])), 52)
		badge.shield = true
		badge.font_scale = 0.3
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(badge)
		var rep := int(c["reputation"])
		for l in [UIKit.label(str(c["name"]), 13), UIKit.label("聲望 %d・%s" % [rep, "難度 高" if rep < 50 else ("難度 中" if rep < 70 else "難度 低")], 11, UIKit.MUTED)]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.clip_text = true
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(l)
		b.add_child(v)
		b.set_meta("club_id", c["id"])
		cards.append(b)
		card_grid.add_child(b)


func _select_club(club_id: String) -> void:
	selected_club = club_id
	for b in cards:
		b.button_pressed = b.get_meta("club_id") == club_id
	for c in clubs:
		if c["id"] == club_id:
			var diff = "高" if c["reputation"] < 50 else ("中" if c["reputation"] < 70 else "低")
			info.text = "[b]%s（%s）[/b]　聲望 %d　粉絲 %s　資金 %s　經營方向 %s　難度：%s" % [c["name"], c.get("short_name", ""), int(c["reputation"]), str(int(c["fanbase"])),
				UIKit.money(int(c["cash"])), UIKit.philosophy_name(c["philosophy"]), diff]


func _seed() -> int:
	return int(seed_edit.text) if seed_edit.text.is_valid_int() else 2026


func _start_selected() -> void:
	if selected_club == "":
		info.text = "[color=#ff5a6a]請先選擇一支俱樂部。[/color]"
		return
	start_with(selected_club, {})


func _start_custom() -> void:
	var lg: Dictionary = leagues[custom_league.selected]
	var weakest := ""
	var low := 999.0
	for c in clubs:
		if c["league_id"] == lg["id"] and float(c["reputation"]) < low:
			low = float(c["reputation"])
			weakest = c["id"]
	var name = custom_name.text.strip_edges()
	if name == "":
		name = "Custom Club"
	var custom = {"id": "custom_" + name.to_lower().replace(" ", "_"), "name": name, "short_name": custom_short.text.strip_edges().to_upper().substr(0, 4),
		"league_id": lg["id"], "region": lg["region"], "reputation": 35, "cash": int(custom_cash.value),
		"wage_budget": 600000, "fanbase": 20000, "philosophy": "balanced", "replace": weakest}
	start_with("", custom)


func start_with(club_id: String, custom: Dictionary) -> void:
	var errors = session.new_game(module_dir, _seed(), club_id, custom)
	if not errors.is_empty():
		info.text = "[color=#ff5a6a]%s[/color]" % "\n".join(errors)
		return
	session.manual_draft = manual.button_pressed
	shell.start_game()


func _load(slot: int) -> void:
	if session.load_slot(slot):
		shell.start_game()
