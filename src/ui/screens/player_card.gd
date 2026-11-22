## Player Profile：選手詳細資訊。對自家選手顯示真實能力；
## 其他隊伍的選手則顯示球探估計區間（Phase 2 的球探系統會讓區間隨觀察縮小）。
class_name PlayerCard
extends VBoxContainer


static func build(session: GameSession, p: Player) -> VBoxContainer:
	var ww = session.world
	var own = p.club_id == ww.human_club_id
	var knowledge = Scouting.knowledge(ww, p)
	var v := UIKit.vbox(10)
	var club: Club = ww.clubs.get(p.club_id)
	# 標題：能力徽章 + 名稱 + 標籤
	var head := UIKit.hbox(12)
	var ca = p.current_ability()
	var ovr := Badge.make(str(int(ca)) if own else "?", UIKit.skill_color(ca) if own else UIKit.MUTED, 60)
	ovr.tooltip_text = "目前能力" if own else "能力需要球探評估"
	head.add_child(ovr)
	var hv := UIKit.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.title(p.handle + ("（已退役）" if p.retired else "")))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_child(UIKit.pill(UIKit.ROLE_SHORT.get(p.primary_role, p.primary_role) + "".join(p.secondary_roles.map(func(r): return " / " + UIKit.ROLE_SHORT[r])), UIKit.ACCENT))
	tags.add_child(UIKit.pill("%d 歲" % p.age(ww.year), UIKit.MUTED))
	tags.add_child(UIKit.pill(p.nationality, UIKit.MUTED))
	tags.add_child(UIKit.pill(club.short_name if club else "自由球員", Badge.club_color(club.id) if club else UIKit.MUTED))
	if p.transfer_requested:
		tags.add_child(UIKit.pill("要求離隊", UIKit.BAD))
	hv.add_child(tags)
	hv.add_child(UIKit.label(p.real_name, 12, UIKit.MUTED))
	head.add_child(hv)
	v.add_child(head)
	var cols := UIKit.hbox(18)
	v.add_child(cols)
	# 能力
	var skills := UIKit.vbox(3)
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills.add_child(UIKit.label("能力" + ("" if own else "（球探估計）"), 15))
	for s in Attr.SKILLS:
		if own:
			skills.add_child(UIKit.stat_bar(UIKit.SKILL_NAMES[s], p.skill(s), 100.0, 110, Color(0, 0, 0, 0), 70))
		else:
			var rg = Scouting.range_of(ww, p, s)
			skills.add_child(UIKit.stat_bar(UIKit.SKILL_NAMES[s], (rg[0] + rg[1]) / 2.0, 100.0, 110, Color(0, 0, 0, 0), 70, "%d–%d" % [rg[0], rg[1]]))
	cols.add_child(skills)
	# 個性、狀態、關係、談話
	var mid := UIKit.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UIKit.label("個性", 15))
	var traits := HFlowContainer.new()
	traits.add_theme_constant_override("h_separation", 6)
	traits.add_theme_constant_override("v_separation", 6)
	for t in Attr.PERSONALITY:
		var tv = p.trait_value(t)
		var word = "很高" if tv >= 80 else ("高" if tv >= 60 else ("普通" if tv >= 40 else ("低" if tv >= 20 else "很低")))
		var known = own or knowledge > 0.5
		traits.add_child(UIKit.pill("%s %s" % [UIKit.TRAIT_NAMES[t], word if known else "？"], (UIKit.GOOD if tv >= 60 else (UIKit.BAD if tv < 40 else UIKit.MUTED)) if known else UIKit.MUTED))
	mid.add_child(traits)
	mid.add_child(UIKit.label("職業目標", 15))
	var goals := HFlowContainer.new()
	goals.add_theme_constant_override("h_separation", 6)
	if own or knowledge > 0.3:
		for g in p.goals:
			goals.add_child(UIKit.pill(UIKit.GOAL_NAMES.get(g, g), UIKit.ACCENT))
	else:
		goals.add_child(UIKit.pill("？", UIKit.MUTED))
	mid.add_child(goals)
	if own:
		mid.add_child(UIKit.label("狀態", 15))
		mid.add_child(UIKit.stat_bar("士氣", p.morale, 100.0, 110, Color(0, 0, 0, 0), 70))
		mid.add_child(UIKit.stat_bar("自信", p.confidence, 100.0, 110, Color(0, 0, 0, 0), 70))
		mid.add_child(UIKit.stat_bar("求勝慾", p.motivation, 100.0, 110, Color(0, 0, 0, 0), 70))
		mid.add_child(UIKit.stat_bar("信任", p.trust_in_management, 100.0, 110, Color(0, 0, 0, 0), 70))
		mid.add_child(UIKit.stat_bar("壓力", p.stress, 100.0, 110, UIKit.BAD if p.stress > 60 else UIKit.MUTED, 70))
		mid.add_child(UIKit.stat_bar("疲勞", p.fatigue, 100.0, 110, UIKit.BAD if p.fatigue > 70 else UIKit.MUTED, 70))
		var mood := UIKit.hbox(6)
		mood.add_child(UIKit.pill("滿意度 %+.2f" % p.happiness, UIKit.GOOD if p.happiness > 0.1 else (UIKit.BAD if p.happiness < -0.2 else UIKit.WARN)))
		mood.add_child(UIKit.pill("大賽 %d 場" % int(p.career.get("big_games", 0)), UIKit.MUTED))
		mid.add_child(mood)
		if p.club_id != "":
			var rel = Relationships.summary(ww, p)
			mid.add_child(UIKit.label("人際關係", 15))
			var rl := HFlowContainer.new()
			rl.add_theme_constant_override("h_separation", 6)
			rl.add_theme_constant_override("v_separation", 6)
			rl.add_child(UIKit.pill("隊友 %+d" % int(rel["avg"]), UIKit.GOOD if rel["avg"] > 10 else (UIKit.BAD if rel["avg"] < -10 else UIKit.MUTED)))
			rl.add_child(UIKit.pill("教練 %+d" % int(rel["coach"]), UIKit.GOOD if rel["coach"] > 10 else (UIKit.BAD if rel["coach"] < -10 else UIKit.MUTED)))
			if rel["best"] != "":
				rl.add_child(UIKit.pill("好友 " + ww.players[rel["best"]].handle, UIKit.GOOD if rel["best_v"] >= Relationships.FRIEND else UIKit.MUTED))
				rl.add_child(UIKit.pill("不合 " + ww.players[rel["worst"]].handle, UIKit.BAD if rel["worst_v"] <= Relationships.RIVAL else UIKit.MUTED))
			mid.add_child(rl)
			# 對話：主動找選手談話（每 7 天一次）
			mid.add_child(UIKit.label("談話", 15))
			var reply := UIKit.label("" if Dialogue.can_talk(ww, p) else "最近已經談過，過幾天再談。", 13, UIKit.MUTED)
			reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reply.custom_minimum_size = Vector2(240, 0)
			var topics := HFlowContainer.new()
			topics.add_theme_constant_override("h_separation", 6)
			topics.add_theme_constant_override("v_separation", 6)
			for topic in Dialogue.TOPICS:
				var b := UIKit.chip(Dialogue.TOPICS[topic], func():
					var r = session.talk_to_player(p.id, topic)
					reply.text = r.get("reply", "")
					reply.add_theme_color_override("font_color", UIKit.GOOD if r.get("tone", 0.0) > 0.3 else (UIKit.BAD if r.get("tone", 0.0) < -0.3 else UIKit.TEXT)))
				b.toggle_mode = false
				topics.add_child(b)
			mid.add_child(topics)
			mid.add_child(reply)
	cols.add_child(mid)
	# 英雄池、合約、生涯
	var right := UIKit.vbox(4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.label("英雄池", 15))
	for cid in p.top_champions(8):
		var ch: Champion = ww.champions.get(cid)
		var m = p.mastery(cid)
		var meta = ww.patch.meta(cid)
		var row := UIKit.hbox(6)
		row.add_child(ChampToken.make(ch, UIKit.GOOD if meta >= 1 else (UIKit.BAD if meta <= -1 else UIKit.BORDER.lightened(0.3)), 28))
		var shown_m = m if (own or knowledge > 0.4) else round(m / 10.0) * 10
		row.add_child(UIKit.stat_bar(ch.name if ch else cid, shown_m, 100.0, 70, Color(0, 0, 0, 0), 76))
		right.add_child(row)
	right.add_child(UIKit.label("合約與生涯", 15))
	var cg := GridContainer.new()
	cg.columns = 2
	cg.add_theme_constant_override("h_separation", 8)
	cg.add_theme_constant_override("v_separation", 8)
	if p.contract:
		cg.add_child(UIKit.stat_card("年薪", UIKit.money(p.contract.salary), "到 %d 年" % p.contract.end_year))
	cg.add_child(UIKit.stat_card("市場價值", UIKit.money(TransferMarket.market_value(ww, p))))
	var g: int = p.career.get("games", 0)
	cg.add_child(UIKit.stat_card("生涯", "%d 場" % g, "勝率 %d%%・冠軍 %d・MVP %d" % [int(100.0 * p.career.get("wins", 0) / maxf(g, 1)), int(p.career.get("titles", 0)), int(p.career.get("mvps", 0))]))
	var sg: int = p.season_stats.get("games", 0)
	cg.add_child(UIKit.stat_card("本季評分", "%.2f" % p.avg_season_rating() if sg > 0 else "—", "%d 場・%d/%d/%d" % [sg, int(p.season_stats.get("kills", 0)), int(p.season_stats.get("deaths", 0)), int(p.season_stats.get("assists", 0))]))
	right.add_child(cg)
	cols.add_child(right)
	return v
