## History：歷屆冠軍、MVP、俱樂部歷史、退役名人。
class_name HistoryScreen
extends UIScreen


func build() -> void:
	add_child(UIKit.title("歷史"))


func refresh() -> void:
	for c in get_children().slice(1):
		remove_child(c)
		c.queue_free()
	var ww = w()
	var t := UIKit.table(["年份", "聯賽", "冠軍", "MVP", "版本"], 260)
	for s in ww.history["seasons"]:
		for lid in s["leagues"]:
			var L: Dictionary = s["leagues"][lid]
			UIKit.add_row(t, [int(s["year"]), ww.leagues[lid].name, UIKit.club_label(ww.clubs[L["champion"]]) if ww.clubs.has(L["champion"]) else "-", ww.players[L["mvp"]].handle if L["mvp"] != "" else "-", s["patch"]])
	add_child(t)
	if ww.history["seasons"].is_empty():
		add_child(UIKit.muted("完成第一個賽季後，歷史紀錄會出現在這裡。"))
	var c = session.club()
	add_child(UIKit.label("%s 歷年成績" % UIKit.club_label(c), 17))
	for h in c.history:
		add_child(UIKit.label("%d　第 %d 名%s" % [int(h["year"]), int(h["position"]), "　🏆" if h.get("champion", false) else ""], 14))
	add_child(UIKit.label("最近退役", 17))
	for r in ww.history["retirements"].slice(-10):
		add_child(UIKit.muted("%d　%s（%d 歲，冠軍 %d）" % [int(r["year"]), r["handle"], int(r["age"]), int(r["titles"])]))
