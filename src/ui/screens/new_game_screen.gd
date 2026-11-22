## 開局：A. 接管模組中的俱樂部　C. 建立自訂俱樂部（取代聯賽中的一支隊伍）
class_name NewGameScreen
extends UIScreen

const MODULE := "res://data/modules/fictional_base"

var clubs: Array = []
var leagues: Array = []
var list: Tree
var seed_edit: LineEdit
var manual: CheckBox
var custom_name: LineEdit
var custom_short: LineEdit
var custom_league: OptionButton
var custom_cash: SpinBox
var info: RichTextLabel
var load_box: VBoxContainer


func build() -> void:
	clubs = GameSession.list_clubs(MODULE)
	leagues = GameSession.list_leagues(MODULE)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)
	var root := UIKit.vbox(14)
	margin.add_child(root)
	root.add_child(UIKit.label("ESPORT: LOL SIMULATOR", 30, UIKit.TEXT))
	root.add_child(UIKit.muted("打造傳奇，不只是一支隊伍。　｜　資料庫：虛構世界"))
	var cols := UIKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# 左：接管俱樂部
	var left := UIKit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	var lp = UIKit.panel(left)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.6
	cols.add_child(lp)
	left.add_child(UIKit.title("接管俱樂部"))
	list = UIKit.table(["俱樂部", "縮寫", "聯賽", "聲望", "資金", "薪資預算", "經營方向"], 360)
	for c in clubs:
		var lg_name := ""
		for l in leagues:
			if l["id"] == c["league_id"]:
				lg_name = l["name"]
		UIKit.add_row(list, [c["name"], c.get("short_name", ""), lg_name, int(c["reputation"]), UIKit.money(int(c["cash"])), UIKit.money(int(c["wage_budget"])), UIKit.philosophy_name(c["philosophy"])], c["id"])
	list.item_selected.connect(_on_select)
	left.add_child(list)
	info = UIKit.rich("[color=#8a90a0]選擇一支俱樂部。聲望越低，資源越少、挑戰越大。[/color]")
	left.add_child(info)

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
	manual.text = "親自進行禁選（關閉則由教練團代為禁選）"
	manual.button_pressed = true
	right.add_child(manual)
	right.add_child(UIKit.primary("接管所選俱樂部", _start_selected))
	right.add_child(HSeparator.new())
	right.add_child(UIKit.title("建立自訂俱樂部"))
	right.add_child(UIKit.muted("新俱樂部會取代所選聯賽中聲望最低的隊伍，陣容由系統生成。"))
	custom_name = LineEdit.new()
	custom_name.placeholder_text = "俱樂部名稱"
	custom_name.text = "Rising Phoenix"
	right.add_child(custom_name)
	custom_short = LineEdit.new()
	custom_short.text = "RPX"
	custom_short.max_length = 4
	right.add_child(custom_short)
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
	right.add_child(UIKit.title("讀取存檔"))
	load_box = UIKit.vbox(4)
	right.add_child(load_box)
	for slot in range(1, 4):
		var meta = GameSession.slot_info(slot)
		var txt = "存檔 %d：%s" % [slot, ("%s・%d 年・第 %d 天" % [meta["club"], int(meta["year"]), int(meta["day"])]) if not meta.is_empty() else "（空）"]
		var b := UIKit.button(txt, _load.bind(slot))
		b.disabled = meta.is_empty()
		load_box.add_child(b)


func _on_select() -> void:
	var it = list.get_selected()
	if it == null:
		return
	for c in clubs:
		if c["id"] == it.get_metadata(0):
			var diff = "高" if c["reputation"] < 50 else ("中" if c["reputation"] < 70 else "低")
			info.text = "[b]%s[/b]　聲望 %d　粉絲 %s　難度：%s" % [c["name"], int(c["reputation"]), str(int(c["fanbase"])), diff]


func _seed() -> int:
	return int(seed_edit.text) if seed_edit.text.is_valid_int() else 2027


func _start_selected() -> void:
	var it = list.get_selected()
	if it == null:
		info.text = "[color=#ff5c5c]請先選擇一支俱樂部。[/color]"
		return
	start_with(it.get_metadata(0), {})


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
	var errors = session.new_game(MODULE, _seed(), club_id, custom)
	if not errors.is_empty():
		info.text = "[color=#ff5c5c]%s[/color]" % "\n".join(errors)
		return
	session.manual_draft = manual.button_pressed
	shell.start_game()


func _load(slot: int) -> void:
	if session.load_slot(slot):
		shell.start_game()
