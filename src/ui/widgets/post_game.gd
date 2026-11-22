## 賽後數據：MVP 卡片、經濟曲線、傷害佔比。比賽結束畫面與賽事回顧共用。
class_name PostGame
extends VBoxContainer

var session: GameSession
var game: Dictionary


static func make(s: GameSession, g: Dictionary) -> PostGame:
	var p := PostGame.new()
	p.session = s
	p.game = g
	p._build()
	return p


func _build() -> void:
	add_theme_constant_override("separation", 10)
	var ww = session.world
	var top := UIKit.hbox(10)
	add_child(top)
	var mvp_id: String = game.get("mvp", "")
	if game["players"].has(mvp_id):
		top.add_child(_mvp_card(mvp_id))
	var chart_box := UIKit.vbox(4)
	chart_box.add_child(UIKit.label("經濟差曲線", 14, UIKit.GOLD))
	var chart := GoldChart.new()
	chart.curve = game.get("gold_curve", [])
	chart.ours_blue = game.get("blue_club", "") == ww.human_club_id
	chart.custom_minimum_size = Vector2(320, 150)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_box.add_child(chart)
	var cp := UIKit.panel(chart_box)
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp.size_flags_stretch_ratio = 1.6
	top.add_child(cp)
	var dmg := UIKit.hbox(10)
	for side in ["blue", "red"]:
		dmg.add_child(_damage_panel(side))
	add_child(dmg)


func _club_of(side: String) -> Club:
	return session.world.clubs.get(game.get("blue_club" if side == "blue" else "red_club", ""))


func _side_color(side: String) -> Color:
	var c := _club_of(side)
	return UIKit.BLUE_SIDE if c and c.id == session.world.human_club_id else UIKit.RED_SIDE


func _mvp_card(pid: String) -> PanelContainer:
	var ww = session.world
	var s: Dictionary = game["players"][pid]
	var pl: Player = ww.players.get(pid)
	var ch: Champion = ww.champions.get(s["champion"])
	var v := UIKit.vbox(4)
	var tag := UIKit.label("MVP", 13, UIKit.GOLD)
	tag.add_theme_font_override("font", UIKit.head_font())
	v.add_child(tag)
	var row := UIKit.hbox(12)
	row.add_child(ChampToken.make(ch, UIKit.GOLD, 64))
	var info := UIKit.vbox(0)
	var nm := UIKit.label(pl.handle if pl else pid, 24, UIKit.GOLD_LIGHT)
	nm.add_theme_font_override("font", UIKit.head_font())
	info.add_child(nm)
	info.add_child(UIKit.label("%s・%s" % [UIKit.ROLE_SHORT.get(s["role"], s["role"]), ch.name if ch else s["champion"]], 14, UIKit.MUTED))
	row.add_child(info)
	v.add_child(row)
	var nums := UIKit.hbox(16)
	for pair in [["K/D/A", "%d/%d/%d" % [int(s["kills"]), int(s["deaths"]), int(s["assists"])]], ["評分", "%.1f" % float(s["rating"])], ["經濟", "%.1fk" % (int(s["gold"]) / 1000.0)]]:
		var c := UIKit.vbox(0)
		c.add_child(UIKit.label(pair[0], 11, UIKit.MUTED))
		var val := UIKit.label(pair[1], 18, UIKit.TEXT)
		val.add_theme_font_override("font", UIKit.head_font())
		c.add_child(val)
		nums.add_child(c)
	v.add_child(nums)
	var p := UIKit.accent_panel(v, UIKit.GOLD)
	p.custom_minimum_size = Vector2(280, 0)
	return p


func _damage_panel(side: String) -> PanelContainer:
	var ww = session.world
	var col := _side_color(side)
	var v := UIKit.vbox(4)
	var c := _club_of(side)
	v.add_child(UIKit.label("%s　傷害佔比" % (c.short_name if c else side), 14, col))
	var rows: Array = []
	var total := 0.0
	for pid in game["players"]:
		var s: Dictionary = game["players"][pid]
		if s["side"] != side:
			continue
		var d := float(s.get("damage", int(s["gold"]) + int(s["kills"]) * 900))
		total += d
		rows.append([Attr.ROLES.find(s["role"]), pid, s, d])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	for r in rows:
		var s: Dictionary = r[2]
		var pl: Player = ww.players.get(r[1])
		var ch: Champion = ww.champions.get(s["champion"])
		var pct: float = r[3] / maxf(total, 1.0) * 100.0
		var name := "%s %s" % [UIKit.ROLE_SHORT.get(s["role"], ""), pl.handle if pl else ""]
		var bar := UIKit.stat_bar(name, pct, 40.0, 150, col, 120, "%d%%  %s" % [int(round(pct)), ch.name if ch else ""])
		v.add_child(bar)
	var p := UIKit.panel(v)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p
