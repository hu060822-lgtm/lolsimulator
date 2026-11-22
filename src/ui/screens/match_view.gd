## 比賽呈現工具：陣容摘要、事件時間軸（文字直播）、數據表。
class_name MatchView
extends RefCounted

const ARCH := {"engage": "開戰", "pick": "抓單", "poke": "消耗", "protect": "保護後排", "split": "分推", "teamfight": "團戰"}
const FLAWS := {"no_frontline": "缺乏前排", "one_damage_type": "傷害類型單一", "no_engage_or_disengage": "沒有開戰也沒有反開", "no_waveclear": "清線不足"}


static func comp_text(comp: Dictionary) -> String:
	var share: Dictionary = comp["share"]
	var parts: Array = []
	var keys: Array = share.keys()
	keys.sort_custom(func(a, b): return share[a] > share[b])
	for k in keys.slice(0, 3):
		parts.append("%s %d%%" % [ARCH[k], int(share[k] * 100)])
	var t = "主軸：%s（%s）　時間曲線 前 %.1f / 中 %.1f / 後 %.1f" % [ARCH[comp["primary"]], "、".join(parts), comp["early"], comp["mid"], comp["late"]]
	if comp["flaws"].size() > 0:
		t += "\n[color=#ff5c5c]缺陷：%s[/color]" % "、".join(comp["flaws"].map(func(f): return FLAWS.get(f, f)))
	return t


static func event_line(session: GameSession, g: Dictionary, e: Dictionary) -> String:
	var ww = session.world
	var side_color := "#8a90a0"
	if e["sides"].size() > 0:
		var club_id: String = g["blue_club"] if e["sides"][0] == "blue" else g["red_club"]
		side_color = "#4f8cff" if club_id == ww.human_club_id else "#ff6b6b"
	var gd := int(e.get("gold_diff", 0))
	var human_blue: bool = g["blue_club"] == ww.human_club_id
	var ours = gd if human_blue else -gd
	var big = e["type"] in ["teamfight", "baron", "elder", "end", "steal", "adapt", "order"]
	var txt = "[color=#8a90a0][%02d'][/color] [color=%s]%s%s%s[/color]" % [int(e["minute"]), side_color, "[b]" if big else "", e["text"], "[/b]" if big else ""]
	if e["causes"].size() > 0:
		txt += "  [color=#6b7280]← %s[/color]" % "、".join(e["causes"])
	txt += "  [color=#555b66](經濟 %+.1fk)[/color]" % (ours / 1000.0)
	return txt


static func stats_table(session: GameSession, g: Dictionary) -> Tree:
	var ww = session.world
	var t := UIKit.table(["選手", "隊伍", "英雄", "K/D/A", "經濟", "失誤", "評分"], 260)
	var ids: Array = g["players"].keys()
	ids.sort_custom(func(a, b): return (g["players"][a]["side"] + str(Attr.ROLES.find(g["players"][a]["role"]))) < (g["players"][b]["side"] + str(Attr.ROLES.find(g["players"][b]["role"]))))
	for pid in ids:
		var s: Dictionary = g["players"][pid]
		var club_id: String = g["blue_club"] if s["side"] == "blue" else g["red_club"]
		var ch: Champion = ww.champions.get(s["champion"])
		var it := UIKit.add_row(t, [ww.players[pid].handle + (" ★MVP" if pid == g["mvp"] else ""), ww.clubs[club_id].short_name, ch.name if ch else s["champion"],
			"%d/%d/%d" % [int(s["kills"]), int(s["deaths"]), int(s["assists"])], "%.1fk" % (int(s["gold"]) / 1000.0), int(s["mistakes"]), "%.1f" % float(s["rating"])])
		it.set_custom_color(1, UIKit.BLUE_SIDE if club_id == ww.human_club_id else UIKit.RED_SIDE)
	return t


static func series_summary(session: GameSession, games: Array) -> VBoxContainer:
	var v := UIKit.vbox(6)
	var ww = session.world
	for i in games.size():
		var g: Dictionary = games[i]
		v.add_child(UIKit.label("第 %d 局：%s 勝（%d 分鐘・擊殺 %d-%d）" % [i + 1, ww.clubs[g["winner_club"]].name, int(g["duration"]), int(g["kills"]["blue"]), int(g["kills"]["red"])], 16))
		var r := UIKit.rich()
		var lines: Array = []
		for e in g["events"]:
			if e["type"] in ["teamfight", "baron", "elder", "end", "steal", "adapt", "order", "dragon", "solo_kill", "gank"]:
				lines.append(event_line(session, g, e))
		r.text = "\n".join(lines)
		v.add_child(r)
	return v
