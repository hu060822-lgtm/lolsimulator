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
			UIKit.add_row(t, [int(s["year"]), ww.leagues[lid].name if ww.leagues.has(lid) else lid, ww.clubs[L["champion"]].short_name if ww.clubs.has(L["champion"]) else "-", ww.players[L["mvp"]].handle if L["mvp"] != "" else "-", s["patch"]])
		var M: Dictionary = s.get("midseason", {})
		if not M.is_empty():
			UIKit.add_row(t, [int(s["year"]), M["name"], ww.clubs[M["champion"]].short_name, ww.players[M["mvp"]].handle if M["mvp"] != "" else "-", s["patch"]])
		var I: Dictionary = s.get("international", {})
		if not I.is_empty():
			var it := UIKit.add_row(t, [int(s["year"]), I["name"], ww.clubs[I["champion"]].short_name, ww.players[I["mvp"]].handle if I["mvp"] != "" else "-", s["patch"]])
			for col in 5:
				it.set_custom_color(col, UIKit.WARN)
		for mv in s.get("movements", []):
			UIKit.add_row(t, [int(s["year"]), "升降級", "↑ %s" % ww.clubs[mv["up"]].short_name, "↓ %s" % ww.clubs[mv["down"]].short_name, ""])
	add_child(t)
	if ww.history["seasons"].is_empty():
		add_child(UIKit.muted("完成第一個賽季後，歷史紀錄會出現在這裡。"))
	var c = session.club()
	add_child(UIKit.label("%s 歷年成績" % UIKit.club_label(c), 17))
	for h in c.history:
		var wr = {"champion": "　世界賽冠軍 🌍", "final": "　世界賽亞軍", "semis": "　世界賽四強", "groups": "　世界賽小組賽"}.get(h.get("worlds", ""), "")
		var lname = ww.leagues[h["league_id"]].name if ww.leagues.has(h.get("league_id", "")) else ""
		var mr = {"champion": "　MSI 冠軍", "final": "　MSI 亞軍", "semis": "　MSI 四強", "groups": "　MSI 小組賽"}.get(h.get("msi", ""), "")
		add_child(UIKit.label("%d　%s 第 %d 名%s%s%s" % [int(h["year"]), lname, int(h["position"]), "　🏆" if h.get("champion", false) else "", mr, wr], 14))
	add_child(UIKit.label("最近退役", 17))
	for r in ww.history["retirements"].slice(-10):
		add_child(UIKit.muted("%d　%s（%d 歲，冠軍 %d）" % [int(r["year"]), r["handle"], int(r["age"]), int(r["titles"])]))
