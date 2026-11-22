## Tactical Board：戰術方向、侵略性、先發陣容。
class_name TacticsScreen
extends UIScreen

var plan_opt: OptionButton
var aggr: HSlider
var aggr_label: Label
var lineup_box: VBoxContainer
var plans: Array = UIKit.PLAN_NAMES.keys()


func build() -> void:
	add_child(UIKit.title("戰術與陣容"))
	var v := UIKit.vbox(8)
	add_child(UIKit.panel(v))
	v.add_child(UIKit.label("戰術方向", 17))
	v.add_child(UIKit.muted("影響禁選偏好、比賽初始打法、打野路線。「彈性」會依實際陣容決定打法。"))
	var c = session.club()
	plan_opt = UIKit.option(plans.map(func(p): return UIKit.PLAN_NAMES[p]), plans.find(c.tactics.get("plan", "flexible")))
	plan_opt.item_selected.connect(func(_i): _save())
	v.add_child(plan_opt)
	var ar := UIKit.hbox()
	ar.add_child(UIKit.label("侵略性"))
	aggr = HSlider.new()
	aggr.min_value = 0
	aggr.max_value = 1
	aggr.step = 0.05
	aggr.value = float(c.tactics.get("aggression", 0.5))
	aggr.custom_minimum_size = Vector2(260, 0)
	aggr.value_changed.connect(func(_v): _save())
	ar.add_child(aggr)
	aggr_label = UIKit.label("")
	ar.add_child(aggr_label)
	v.add_child(ar)
	v.add_child(UIKit.muted("侵略性高：對線擊殺、抓人、爭奪物件更積極，但也更容易被反打。"))
	var l := UIKit.vbox(6)
	add_child(UIKit.panel(l))
	l.add_child(UIKit.label("先發陣容", 17))
	lineup_box = UIKit.vbox(6)
	l.add_child(lineup_box)
	l.add_child(UIKit.button("由教練團自動安排", _auto))


func refresh() -> void:
	aggr_label.text = "%d%%" % int(aggr.value * 100)
	UIKit.clear(lineup_box)
	var ww = w()
	var c = session.club()
	var players: Array = c.roster.map(func(pid): return ww.players[pid])
	for role in Attr.ROLES:
		var row := UIKit.hbox()
		row.add_child(UIKit.label(UIKit.ROLE_NAMES[role], 15))
		var names: Array = []
		var sel := 0
		for i in players.size():
			var p: Player = players[i]
			names.append("%s（%s・能力 %d・疲勞 %d）" % [p.handle, UIKit.ROLE_NAMES[p.primary_role], int(p.current_ability(role)), int(p.fatigue)])
			if c.lineup.get(role, "") == p.id:
				sel = i
		var o := UIKit.option(names, sel)
		o.item_selected.connect(func(i): session.set_lineup(role, players[i].id); refresh())
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(o)
		lineup_box.add_child(row)


func _save() -> void:
	session.set_tactics(plans[plan_opt.selected], aggr.value)
	aggr_label.text = "%d%%" % int(aggr.value * 100)


func _auto() -> void:
	LineupSelector.pick(w(), session.club())
	refresh()
