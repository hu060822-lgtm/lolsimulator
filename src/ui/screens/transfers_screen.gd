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
	if p.club_id != "" and p.club_id != ww.human_club_id and not Loans.is_loaned(p):
		detail.add_child(UIKit.button("租借到本季結束（租借費 %s，薪資雙方各付一半）" % UIKit.money(Loans.loan_fee(ww, p)), _loan_in))
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
		_show_counter(r)


## 回價：賣方開出轉會費、或選手（經紀人）開出能接受的年薪與出場承諾，一鍵帶入後重新報價。
func _show_counter(r: Dictionary) -> void:
	var box = UIKit.hbox(8)
	box.name = "Counter"
	var old = detail.get_node_or_null("Counter")
	if old:
		old.queue_free()
	if r.has("counter_fee"):
		box.add_child(UIKit.label("賣方回價：轉會費 %s" % UIKit.money(int(r["counter_fee"])), 14, UIKit.GOLD_LIGHT))
		box.add_child(UIKit.button("接受回價並重新報價", func(): fee.value = int(r["counter_fee"]); _offer()))
	elif r.has("counter"):
		var c: Dictionary = r["counter"]
		if c.get("refuse", false):
			box.add_child(UIKit.label("經紀人：「現在的條件我們不考慮。」（球隊競爭力或地區不符他的期待）", 14, UIKit.BAD))
		else:
			var role_i = PROMISES.find(c["role_promise"])
			box.add_child(UIKit.label("經紀人回價：年薪 %s・%s" % [UIKit.money(int(c["salary"])), PROMISE_NAMES[role_i]], 14, UIKit.GOLD_LIGHT))
			box.add_child(UIKit.button("接受回價", func(): salary.value = int(c["salary"]); promise.select(role_i); _offer()))
	if box.get_child_count() > 0:
		detail.add_child(box)


func _loan_in() -> void:
	var p: Player = w().players[selected_id]
	var r = session.loan_in(p.id, 0.5)
	if r.get("accepted", false):
		result.text = "成功！%s 租借加入到本季結束。" % p.handle
		result.add_theme_color_override("font_color", UIKit.GOOD)
		selected_id = ""
		refresh()
		shell.refresh_status()
	else:
		result.text = "租借失敗：%s" % r.get("reason", "")


func _scout() -> void:
	var r = session.scout_player(selected_id)
	if not r["ok"]:
		result.text = r["note"]
		return
	_show_detail()
	shell.refresh_status()
	result.text = r["note"]
