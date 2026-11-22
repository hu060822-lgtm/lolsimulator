## Player Profile：選手詳細資訊。對自家選手顯示真實能力；
## 其他隊伍的選手則顯示球探估計區間（Phase 2 的球探系統會讓區間隨觀察縮小）。
class_name PlayerCard
extends VBoxContainer


static func build(session: GameSession, p: Player) -> VBoxContainer:
	var ww = session.world
	var own = p.club_id == ww.human_club_id
	var v := UIKit.vbox(8)
	var club_name: String = UIKit.club_label(ww.clubs[p.club_id]) if p.club_id != "" else "自由球員"
	v.add_child(UIKit.title("%s　%s" % [p.handle, "（已退役）" if p.retired else ""]))
	v.add_child(UIKit.muted("%s・%s・%d 歲・%s・%s%s" % [p.real_name, p.nationality, p.age(ww.year), UIKit.ROLE_NAMES.get(p.primary_role, p.primary_role),
		club_name, ("・副位置 " + "、".join(p.secondary_roles.map(func(r): return UIKit.ROLE_NAMES[r]))) if p.secondary_roles.size() > 0 else ""]))
	var cols := UIKit.hbox(16)
	v.add_child(cols)
	var skills := UIKit.vbox(2)
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills.add_child(UIKit.label("能力" + ("" if own else "（球探估計）"), 16))
	var knowledge = Scouting.knowledge(ww, p)
	for s in Attr.SKILLS:
		var val = p.skill(s)
		var txt := ""
		if own:
			txt = "%-6s %s %d" % [UIKit.SKILL_NAMES[s], UIKit.bar_text(val), int(val)]
		else:
			var rg = Scouting.range_of(ww, p, s)
			txt = "%-6s %s %d–%d" % [UIKit.SKILL_NAMES[s], UIKit.bar_text((rg[0] + rg[1]) / 2.0), rg[0], rg[1]]
		skills.add_child(UIKit.label(txt, 14, UIKit.skill_color(val if own else (Scouting.range_of(ww, p, s)[0] + Scouting.range_of(ww, p, s)[1]) / 2.0)))
	cols.add_child(skills)
	var mid := UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UIKit.label("個性", 16))
	for t in Attr.PERSONALITY:
		var tv = p.trait_value(t)
		var word = "很高" if tv >= 80 else ("高" if tv >= 60 else ("普通" if tv >= 40 else ("低" if tv >= 20 else "很低")))
		mid.add_child(UIKit.label("%-6s %s" % [UIKit.TRAIT_NAMES[t], word if (own or knowledge > 0.5) else "？"], 14))
	mid.add_child(UIKit.label("職業目標", 16))
	mid.add_child(UIKit.label("、".join(p.goals.map(func(g): return UIKit.GOAL_NAMES.get(g, g))) if (own or knowledge > 0.3) else "？", 14, UIKit.ACCENT))
	if own:
		mid.add_child(UIKit.label("狀態", 16))
		mid.add_child(UIKit.label("士氣 %d　自信 %d　壓力 %d　疲勞 %d" % [int(p.morale), int(p.confidence), int(p.stress), int(p.fatigue)], 14))
		mid.add_child(UIKit.label("滿意度 %+.2f　對管理層信任 %d" % [p.happiness, int(p.trust_in_management)], 14))
		if p.transfer_requested:
			mid.add_child(UIKit.label("已要求離隊", 14, UIKit.BAD))
	cols.add_child(mid)
	var right := UIKit.vbox(2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.label("英雄池", 16))
	for cid in p.top_champions(8):
		var ch: Champion = ww.champions.get(cid)
		var m = p.mastery(cid)
		var meta = ww.patch.meta(cid)
		right.add_child(UIKit.label("%-12s %d %s" % [ch.name if ch else cid, int(m) if (own or knowledge > 0.4) else int(round(m / 10.0) * 10), "▲" if meta >= 1 else ("▼" if meta <= -1 else "")], 14, UIKit.skill_color(m)))
	right.add_child(UIKit.label("合約與生涯", 16))
	if p.contract:
		right.add_child(UIKit.label("年薪 %s・到 %d 年・%s" % [UIKit.money(p.contract.salary), p.contract.end_year, p.contract.role_promise], 14))
	right.add_child(UIKit.label("市場價值 %s" % UIKit.money(TransferMarket.market_value(ww, p)), 14))
	var g: int = p.career.get("games", 0)
	right.add_child(UIKit.label("生涯 %d 場・勝率 %d%%・冠軍 %d・最佳選手 %d" % [g, int(100.0 * p.career.get("wins", 0) / maxf(g, 1)), int(p.career.get("titles", 0)), int(p.career.get("mvps", 0))], 14))
	var sg: int = p.season_stats.get("games", 0)
	right.add_child(UIKit.label("本季 %d 場・K/D/A %d/%d/%d・評分 %.2f" % [sg, int(p.season_stats.get("kills", 0)), int(p.season_stats.get("deaths", 0)), int(p.season_stats.get("assists", 0)), p.avg_season_rating()], 14))
	cols.add_child(right)
	return v
