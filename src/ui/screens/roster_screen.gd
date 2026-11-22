## Roster：一線隊、替補、青訓；點選選手看詳細資料並進行管理操作。
class_name RosterScreen
extends UIScreen

var table: Tree
var detail: VBoxContainer
var selected_id: String = ""


func build() -> void:
	add_child(UIKit.title("名單"))
	table = UIKit.table(["選手", "位置", "年齡", "身份", "能力", "潛力評估", "士氣", "疲勞", "滿意度", "年薪", "合約到期"], 300)
	table.item_selected.connect(_on_select)
	add_child(table)
	detail = UIKit.vbox(8)
	add_child(UIKit.panel(detail))


func refresh() -> void:
	UIKit.clear_table(table)
	var ww = w()
	var c = session.club()
	var players: Array = c.roster.map(func(pid): return ww.players[pid])
	players.sort_custom(func(a, b): return Attr.ROLES.find(a.primary_role) * 1000 - a.current_ability() < Attr.ROLES.find(b.primary_role) * 1000 - b.current_ability())
	for p in players:
		var status: String = "先發" if c.lineup.values().has(p.id) else {"prospect": "新秀", "backup": "替補", "rotation": "輪替"}.get(p.squad_status, p.squad_status)
		var pot = _potential_word(p)
		var it := UIKit.add_row(table, [p.handle, UIKit.ROLE_NAMES[p.primary_role], p.age(ww.year), status, int(p.current_ability()), pot,
			int(p.morale), int(p.fatigue), "%+.2f" % p.happiness, UIKit.money(p.contract.salary if p.contract else 0), p.contract.end_year if p.contract else "-"], p.id)
		it.set_custom_color(4, UIKit.skill_color(p.current_ability()))
		if p.transfer_requested:
			it.set_custom_color(0, UIKit.BAD)
		if p.contract and p.contract.end_year <= ww.year:
			it.set_custom_color(10, UIKit.WARN)
	_show_detail()


## 教練團對潛力的評估（不是真實潛力值）
func _potential_word(p: Player) -> String:
	var gap = p.potential - p.current_ability()
	var a = p.age(w().year)
	if a >= 25:
		return "已成熟"
	if gap > 25:
		return "★★★★★"
	if gap > 15:
		return "★★★★"
	if gap > 8:
		return "★★★"
	return "★★"


func _on_select() -> void:
	var it = table.get_selected()
	if it:
		selected_id = it.get_metadata(0)
		_show_detail()


func _show_detail() -> void:
	UIKit.clear(detail)
	if selected_id == "" or not w().players.has(selected_id) or not (selected_id in session.club().roster):
		detail.add_child(UIKit.muted("點選選手查看詳細資料。"))
		return
	var p: Player = w().players[selected_id]
	detail.add_child(PlayerCard.build(session, p))
	var actions := UIKit.hbox()
	detail.add_child(actions)
	for role in Attr.ROLES:
		actions.add_child(UIKit.button("設為%s先發" % UIKit.ROLE_NAMES[role], _set_starter.bind(role)))
	var row2 := UIKit.hbox()
	detail.add_child(row2)
	row2.add_child(UIKit.button("與選手談話", _talk))
	row2.add_child(UIKit.button("提出續約（市價）", _renew))
	row2.add_child(UIKit.button("解約", _release))
	var msg := UIKit.label("", 14, UIKit.WARN)
	msg.name = "Msg"
	detail.add_child(msg)


func _msg(t: String) -> void:
	var m = detail.get_node_or_null("Msg")
	if m:
		m.text = t


func _set_starter(role: String) -> void:
	session.set_lineup(role, selected_id)
	refresh()
	_msg("已設定為%s先發" % UIKit.ROLE_NAMES[role])


func _talk() -> void:
	var r = session.respond_to_player(selected_id, "explain_situation")
	refresh()
	_msg("談話結果：%s（滿意度 %+.2f）" % [r["note"], r["effect"]])


func _renew() -> void:
	var p: Player = w().players[selected_id]
	var demand = TransferMarket.wage_demand(w(), p)
	var r = session.offer_contract(selected_id, demand, 2, "starter" if session.club().lineup.values().has(p.id) else "rotation")
	refresh()
	_msg("續約 %s：%s" % [UIKit.money(demand), "接受" if r["accepted"] else "拒絕（%s）" % r["reason"]])


func _release() -> void:
	session.release_player(selected_id)
	selected_id = ""
	refresh()
	toast("已解約")
