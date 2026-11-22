## 教練團：目前員工、能力加成、員工市場（聘用 / 解約）。
class_name StaffScreen
extends UIScreen

const STYLE_NAMES := {"aggressive": "積極進攻", "macro": "運營", "early_game": "前期", "scaling": "後期發育", "flexible": "彈性", "discipline": "紀律"}
const ATTRS := {"tactical": "戰術", "drafting": "禁選", "development": "培養", "man_management": "管理", "adaptability": "臨場調整", "scouting": "眼光", "fitness": "體能心理"}

var role_opt: OptionButton
var market: Tree
var detail: RichTextLabel
var salary_spin: SpinBox
var years_opt: OptionButton
var result: Label
var selected_id := ""


func build() -> void:
	add_child(UIKit.title("教練團"))
	add_child(UIKit.muted("主教練決定基礎能力；專職員工比主教練更強時，提供超出部分一半的加成。"))
	var cur := UIKit.table(["職位", "姓名", "年齡", "主要能力", "年薪", "合約至"], 236)
	var c = session.club()
	for role in Staff.ROLES:
		var s: Staff = session.staff_of(role)
		if s:
			UIKit.add_row(cur, [StaffSystem.ROLE_NAMES[role], s.name, s.age(w().year), int(s.key_rating()), UIKit.money(s.salary), s.contract_end], role)
		else:
			UIKit.add_row(cur, [StaffSystem.ROLE_NAMES[role], "（空缺）", "", "", "", ""], role)
	add_child(cur)
	var eff := []
	for k in ATTRS:
		eff.append("%s %d" % [ATTRS[k], int(StaffSystem.rating(w(), c, k))])
	add_child(UIKit.label("教練團綜合能力：" + "・".join(eff), 14, UIKit.MUTED))
	var fire_row := UIKit.hbox()
	var fire_opt := UIKit.option(Staff.ROLES.map(func(r): return StaffSystem.ROLE_NAMES[r]))
	fire_row.add_child(fire_opt)
	fire_row.add_child(UIKit.button("解約（支付剩餘合約一半）", func(): _dismiss(Staff.ROLES[fire_opt.selected])))
	add_child(fire_row)

	add_child(UIKit.label("員工市場", 17))
	var row := UIKit.hbox()
	role_opt = UIKit.option(Staff.ROLES.map(func(r): return StaffSystem.ROLE_NAMES[r]), 1)
	role_opt.item_selected.connect(func(_i): _fill_market())
	row.add_child(role_opt)
	add_child(row)
	var cols := UIKit.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)
	market = UIKit.table(["姓名", "年齡", "主要能力", "風格", "聲望", "要求年薪"], 220)
	market.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market.item_selected.connect(_on_select)
	cols.add_child(market)
	var right := UIKit.vbox()
	right.custom_minimum_size = Vector2(320, 0)
	cols.add_child(UIKit.panel(right))
	detail = UIKit.rich("[color=#8a90a0]選擇一名員工查看能力。[/color]")
	detail.custom_minimum_size = Vector2(0, 150)
	right.add_child(detail)
	var form := UIKit.hbox()
	form.add_child(UIKit.label("年薪"))
	salary_spin = SpinBox.new()
	salary_spin.max_value = 2000000
	salary_spin.step = 5000
	form.add_child(salary_spin)
	years_opt = UIKit.option(["1 年", "2 年", "3 年"], 1)
	form.add_child(years_opt)
	right.add_child(form)
	right.add_child(UIKit.primary("提出聘約", _hire))
	result = UIKit.label("", 14, UIKit.MUTED)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(result)
	_fill_market()


func _fill_market() -> void:
	UIKit.clear_table(market)
	var role: String = Staff.ROLES[role_opt.selected]
	for s in session.staff_market(role).slice(0, 30):
		UIKit.add_row(market, [s.name, s.age(w().year), int(s.key_rating()), STYLE_NAMES.get(s.style, s.style), int(s.reputation), UIKit.money(session.staff_demand(s.id))], s.id)


func _on_select() -> void:
	var it = market.get_selected()
	if it == null:
		return
	selected_id = it.get_metadata(0)
	var s: Staff = w().staff[selected_id]
	var lines := ["[b]%s[/b]　%s・%d 歲" % [s.name, StaffSystem.ROLE_NAMES[s.role], s.age(w().year)]]
	for k in ATTRS:
		lines.append("%s　%d" % [ATTRS[k], int(s.get(k))])
	detail.text = "\n".join(lines)
	salary_spin.value = session.staff_demand(selected_id)


func _hire() -> void:
	if selected_id == "":
		result.text = "請先選擇員工"
		return
	var r = session.hire_staff(selected_id, int(salary_spin.value), years_opt.selected + 1)
	toast(r["note"])
	if r["ok"]:
		UIKit.clear(self)
		selected_id = ""
		build()
	else:
		result.text = r["note"]


func _dismiss(role: String) -> void:
	var r = session.dismiss_staff(role)
	toast(r["note"])
	if r["ok"]:
		UIKit.clear(self)
		build()
