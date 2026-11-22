## News：媒體頭條與各俱樂部的外界評價。
class_name NewsScreen
extends UIScreen

var body: VBoxContainer


func build() -> void:
	add_child(UIKit.title("媒體"))
	body = UIKit.vbox(10)
	add_child(body)


func refresh() -> void:
	UIKit.clear(body)
	var ww = w()
	var c = session.club()
	var row := UIKit.hbox(12)
	body.add_child(row)
	var left := UIKit.vbox(4)
	left.add_child(UIKit.label("最新頭條", 17))
	var items = Media.latest(ww, 25)
	for n in items:
		var col = UIKit.GOOD if float(n["tone"]) > 0.3 else (UIKit.BAD if float(n["tone"]) < -0.3 else UIKit.TEXT)
		if n["ids"].has(c.id):
			col = UIKit.ACCENT
		var l = UIKit.label("第 %d 天　%s" % [int(n["day"]), n["text"]], 14, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(l)
	if items.is_empty():
		left.add_child(UIKit.muted("目前沒有新聞。"))
	var lp = UIKit.panel(left)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.5
	row.add_child(lp)
	var right := UIKit.vbox(4)
	right.add_child(UIKit.label("外界評價", 17))
	var hint = UIKit.muted("成績相對於預期的表現。評價差時選手壓力上升，評價好時周邊收入增加。")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(hint)
	var t := UIKit.table(["隊伍", "評價", ""], 420)
	var lg: League = ww.leagues[c.league_id]
	var ids: Array = lg.club_ids.duplicate()
	ids.sort_custom(func(a, b): return ww.clubs[a].opinion > ww.clubs[b].opinion)
	for cid in ids:
		var cl: Club = ww.clubs[cid]
		var it := UIKit.add_row(t, [UIKit.club_label(cl), "%+d" % int(cl.opinion), Media.label(cl.opinion)])
		it.set_custom_color(1, UIKit.GOOD if cl.opinion > 15 else (UIKit.BAD if cl.opinion < -15 else UIKit.TEXT))
		if cid == ww.human_club_id:
			it.set_custom_color(0, UIKit.ACCENT)
	right.add_child(t)
	var rp = UIKit.panel(right)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rp)
