## Transfer Center：搜尋全球選手、查看球探估計、提出報價或合約。
class_name TransfersScreen
extends UIScreen

var role_opt: OptionButton
var free_only: CheckBox
var young_only: CheckBox
var table: Tree
var detail: VBoxContainer
var selected_id: String = ""
var fee: SpinBox
var salary: SpinBox
var years: SpinBox
var promise: OptionButton
var result: Label
const PROMISES := ["starter", "rotation", "backup", "prospect"]
const PROMISE_NAMES := ["先發", "輪替", "替補", "新秀培養"]


func build() -> void:
	add_child(UIKit.title("轉會中心"))
	var open = session.transfer_window_open()
	add_child(UIKit.label("轉會窗口：%s" % ("開放中" if open else "關閉（休賽季與季前賽開放）"), 15, UIKit.GOOD if open else UIKit.WARN))
	var f := UIKit.hbox()
	add_child(f)
	role_opt = UIKit.option(["全部位置"] + Attr.ROLES.map(func(r): return UIKit.ROLE_NAMES[r]))
	role_opt.item_selected.connect(func(_i): refresh())
	f.add_child(role_opt)
	free_only = CheckBox.new()
	free_only.text = "只看自由球員"
	free_only.toggled.connect(func(_b): refresh())
	f.add_child(free_only)
	young_only = CheckBox.new()
	young_only.text = "21 歲以下"
	young_only.toggled.connect(func(_b): refresh())
	f.add_child(young_only)
	table = UIKit.table(["選手", "所屬", "位置", "年齡", "能力估計", "了解程度", "市場價值", "薪資要求"], 280)
	table.item_selected.connect(_on_select)
	add_child(table)
	detail = UIKit.vbox(8)
	add_child(UIKit.panel(detail))


func refresh() -> void:
	UIKit.clear_table(table)
	var ww = w()
	var role = "" if role_opt.selected == 0 else Attr.ROLES[role_opt.selected - 1]
	var list = session.search_players(role, free_only.button_pressed, 21 if young_only.button_pressed else 99)
	for p in list.slice(0, 120):
		var k = Scouting.knowledge(ww, p)
		var est = _ca_range(p)
		var it := UIKit.add_row(table, [p.handle, ww.clubs[p.club_id].short_name if p.club_id != "" else "自由", UIKit.ROLE_NAMES[p.primary_role], p.age(ww.year),
			"%d–%d" % est, "%d%%" % int(k * 100), UIKit.money(TransferMarket.market_value(ww, p)), UIKit.money(TransferMarket.wage_demand(ww, p))], p.id)
		it.set_custom_color(4, UIKit.skill_color((est[0] + est[1]) / 2.0))
		if p.transfer_requested:
			it.set_custom_color(0, UIKit.WARN)
	_show_detail()


func _ca_range(p: Player) -> Array:
	var k = Scouting.knowledge(w(), p)
	var ca = p.current_ability()
	var bias = (float(hash(p.id + "ca") % 1000) / 1000.0 - 0.5) * 2.0
	var c = ca + bias * (1.0 - k) * 7.0
	var half = (1.0 - k) * 10.0
	return [int(c - half), int(c + half)]


func _on_select() -> void:
	var it = table.get_selected()
	if it:
		selected_id = it.get_metadata(0)
		_show_detail()


func _show_detail() -> void:
	UIKit.clear(detail)
	if selected_id == "" or not w().players.has(selected_id):
		detail.add_child(UIKit.muted("選擇選手查看球探報告與報價。能力為估計區間：了解程度越高，區間越準。"))
		return
	var ww = w()
	var p: Player = ww.players[selected_id]
	detail.add_child(PlayerCard.build(session, p))
	var seller_txt := "自由球員：只需選手同意合約"
	if p.club_id != "":
		seller_txt = "賣方要價約 %s%s" % [UIKit.money(TransferMarket.asking_price(ww, ww.clubs[p.club_id], p)), "（選手已要求離隊）" if p.transfer_requested else ""]
	detail.add_child(UIKit.label(seller_txt, 14, UIKit.MUTED))
	var form := UIKit.hbox()
	detail.add_child(form)
	form.add_child(UIKit.label("轉會費"))
	fee = _spin(0, 20000000, 10000, TransferMarket.asking_price(ww, ww.clubs[p.club_id], p) if p.club_id != "" else 0)
	fee.editable = p.club_id != ""
	form.add_child(fee)
	form.add_child(UIKit.label("年薪"))
	salary = _spin(10000, 3000000, 5000, TransferMarket.wage_demand(ww, p))
	form.add_child(salary)
	form.add_child(UIKit.label("年限"))
	years = _spin(1, 4, 1, 2)
	form.add_child(years)
	promise = UIKit.option(PROMISE_NAMES, 0)
	form.add_child(promise)
	detail.add_child(UIKit.primary("提出報價" if p.club_id != "" else "提出合約", _offer))
	result = UIKit.label("", 15, UIKit.WARN)
	detail.add_child(result)
	detail.add_child(UIKit.button("指派球探深入觀察（了解程度 +25%）", _scout))


func _spin(lo: float, hi: float, step: float, val: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(130, 0)
	return s


func _offer() -> void:
	var p: Player = w().players[selected_id]
	var r: Dictionary
	if p.club_id == "":
		r = session.offer_contract(p.id, int(salary.value), int(years.value), PROMISES[promise.selected])
	else:
		r = session.bid(p.id, int(fee.value), int(salary.value), int(years.value), PROMISES[promise.selected])
	if r.get("accepted", false):
		result.text = "成功！%s 加入俱樂部。" % p.handle
		result.add_theme_color_override("font_color", UIKit.GOOD)
		selected_id = ""
		refresh()
		shell.refresh_status()
	else:
		result.text = "失敗：%s" % r.get("reason", "")


func _scout() -> void:
	var r = session.scout_player(selected_id)
	if not r["ok"]:
		result.text = r["note"]
		return
	_show_detail()
	shell.refresh_status()
	result.text = r["note"]
