## Club Dashboard：俱樂部整體狀況。
class_name DashboardScreen
extends UIScreen

var body: VBoxContainer


func build() -> void:
	body = UIKit.vbox(12)
	add_child(body)


func refresh() -> void:
	UIKit.clear(body)
	var c = session.club()
	var ww = w()
	var lg: League = ww.leagues[c.league_id]
	# 標題列：隊徽 + 名稱 + 標籤
	var head := UIKit.hbox(14)
	head.add_child(Badge.club(c, 64))
	var hv := UIKit.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.title(UIKit.club_label(c)))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_child(UIKit.pill(lg.name + ("・次級聯賽" if lg.tier >= 2 else ""), UIKit.ACCENT))
	tags.add_child(UIKit.pill("聲望 %.0f" % c.reputation, UIKit.WARN))
	tags.add_child(UIKit.pill("粉絲 %s" % _short_num(c.fanbase), UIKit.MUTED))
	tags.add_child(UIKit.pill(UIKit.philosophy_name(c.philosophy), UIKit.MUTED))
	tags.add_child(UIKit.pill("外界：" + Media.label(c.opinion), UIKit.GOOD if c.opinion > 15 else (UIKit.BAD if c.opinion < -15 else UIKit.MUTED)))
	hv.add_child(tags)
	head.add_child(hv)
	body.add_child(head)
	# 第一列：下一場、排名、資金、董事會
	var row := UIKit.hbox(10)
	body.add_child(row)
	row.add_child(_next_match_card(c))
	var st: Dictionary = lg.standings.get(c.id, {"w": 0, "l": 0})
	var pos = LeagueEngine.sorted_standings(lg).find(c.id) + 1
	row.add_child(UIKit.stat_card("聯賽排名", "#%d" % pos, "%d 勝 %d 敗・%s" % [int(st["w"]), int(st["l"]), _streak(c)], UIKit.ACCENT))
	var bill = TransferMarket.wage_bill(ww, c)
	row.add_child(UIKit.stat_card("資金", UIKit.money(c.cash), "薪資 %s / %s" % [_short_money(bill), _short_money(c.wage_budget)], UIKit.GOOD if c.cash > 0 else UIKit.BAD))
	var org := UIKit.vbox(4)
	org.add_child(UIKit.label("組織", 12, UIKit.MUTED))
	org.add_child(UIKit.stat_bar("董事會", c.board_confidence, 100.0, 90, Color(0, 0, 0, 0), 56))
	org.add_child(UIKit.stat_bar("品牌", c.brand, 100.0, 90, UIKit.WARN, 56))
	org.add_child(UIKit.stat_bar("默契", c.chemistry, 100.0, 90, UIKit.ACCENT, 56))
	org.add_child(UIKit.stat_bar("BP 熟悉", c.draft_familiarity, 100.0, 90, UIKit.ACCENT, 56))
	var op = UIKit.panel(org)
	op.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(op)
	# 先發陣容卡
	body.add_child(UIKit.label("先發陣容", 17))
	var starters := UIKit.hbox(10)
	for role in Attr.ROLES:
		starters.add_child(_starter_card(ww.players.get(c.lineup.get(role, "")), role))
	body.add_child(starters)
	# 最近戰績 + 收件匣 + 媒體
	var row2 := UIKit.hbox(10)
	body.add_child(row2)
	var recent := UIKit.vbox(6)
	recent.add_child(UIKit.label("最近戰績", 15))
	var form := UIKit.hbox(4)
	var lines := UIKit.vbox(2)
	var shown := 0
	for e in ww.log.of_type("match").filter(func(x): return c.id in x["actors"]).slice(-5):
		var other: String = e["actors"][1] if e["actors"][0] == c.id else e["actors"][0]
		var won: bool = e["data"]["winner"] == c.id
		var b := Badge.make("W" if won else "L", UIKit.GOOD if won else UIKit.BAD, 30)
		b.tooltip_text = "對 %s　%s" % [UIKit.club_label(ww.clubs[other]), e["data"]["score"]]
		form.add_child(b)
		lines.add_child(UIKit.label("%s　%s" % [ww.clubs[other].short_name, e["data"]["score"]], 13, UIKit.GOOD if won else UIKit.BAD))
		shown += 1
	if shown == 0:
		recent.add_child(UIKit.muted("尚未出賽"))
	else:
		recent.add_child(form)
		recent.add_child(lines)
	row2.add_child(UIKit.panel(recent))
	var inbox := UIKit.vbox(6)
	var msgs = session.open_messages()
	var ih := UIKit.hbox(8)
	ih.add_child(UIKit.label("收件匣", 15))
	if msgs.size() > 0:
		ih.add_child(UIKit.pill("%d 件待處理" % msgs.size(), UIKit.WARN))
	inbox.add_child(ih)
	for m in msgs.slice(0, 3):
		var ml = UIKit.label(m["text"], 13, UIKit.TEXT)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ml.max_lines_visible = 2
		inbox.add_child(ml)
	if msgs.is_empty():
		inbox.add_child(UIKit.muted("沒有待處理事項"))
	else:
		inbox.add_child(UIKit.button("前往收件匣  »", func(): shell.open("inbox")))
	row2.add_child(UIKit.panel(inbox))
	var news := UIKit.vbox(6)
	news.add_child(UIKit.label("媒體報導", 15))
	var items = Media.club_news(ww, c.id, 4)
	for n in items:
		var tone = float(n["tone"])
		var nh := UIKit.hbox(6)
		var dot := Badge.make("", UIKit.GOOD if tone > 0.3 else (UIKit.BAD if tone < -0.3 else UIKit.MUTED), 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nh.add_child(dot)
		var nl = UIKit.label(n["text"], 13)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nh.add_child(nl)
		news.add_child(nh)
	if items.is_empty():
		news.add_child(UIKit.muted("還沒有關於球隊的報導"))
	row2.add_child(UIKit.panel(news))
	for ch in row2.get_children():
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _next_match_card(c: Club) -> PanelContainer:
	var ww = w()
	var v := UIKit.vbox(4)
	v.add_child(UIKit.label("下一場比賽", 12, UIKit.MUTED))
	var next_day = LeagueEngine.next_match_day(ww, c.id)
	var f = LeagueEngine.find_fixture(ww, c.id, next_day) if next_day != -1 else {}
	if f.is_empty():
		v.add_child(UIKit.label("本季已無賽程", 16))
	else:
		var fx: Dictionary = f["fixture"]
		var opp: Club = ww.clubs[fx["away"] if fx["home"] == c.id else fx["home"]]
		var comp: League = f["league"]
		var stage = {"regular": "例行賽", "playoffs": "季後賽", "final": "決賽"}.get(fx["stage"], fx["stage"])
		if comp.tier == 0:
			stage = comp.name + ("小組賽" if fx["stage"] == "regular" else ("決賽" if fx["stage"] == "final" else "淘汰賽"))
		if fx.has("label"):
			stage = (comp.short_name if comp.short_name != "" else comp.name) + " " + str(fx["label"])
		var vs := UIKit.hbox(8)
		vs.add_child(Badge.club(c, 40))
		vs.add_child(UIKit.label("VS", 16, UIKit.MUTED))
		vs.add_child(Badge.club(opp, 40))
		var info := UIKit.vbox(0)
		info.add_child(UIKit.label(opp.short_name, 17))
		info.add_child(UIKit.label("第 %d 天・%s・%s" % [next_day, UIKit.bo_text(int(fx["best_of"])), stage], 12, UIKit.MUTED))
		vs.add_child(info)
		v.add_child(vs)
	var p = UIKit.panel(v)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _starter_card(p: Player, role: String) -> PanelContainer:
	var ww = w()
	var v := UIKit.vbox(4)
	var h := UIKit.hbox(8)
	if p == null:
		h.add_child(Badge.make(UIKit.ROLE_SHORT[role], UIKit.BORDER, 40))
		h.add_child(UIKit.label("空缺", 15, UIKit.BAD))
		v.add_child(h)
	else:
		var ca = p.current_ability(role)
		var ovr := Badge.make(str(int(ca)), UIKit.skill_color(ca), 40)
		ovr.tooltip_text = "目前能力"
		h.add_child(ovr)
		var nv := UIKit.vbox(0)
		nv.add_child(UIKit.label(UIKit.ROLE_SHORT[role], 11, UIKit.ACCENT))
		nv.add_child(UIKit.label(p.handle, 15))
		nv.add_child(UIKit.label("%d 歲" % p.age(ww.year), 11, UIKit.MUTED))
		h.add_child(nv)
		v.add_child(h)
		v.add_child(UIKit.stat_bar("士氣", p.morale, 100.0, 60, Color(0, 0, 0, 0), 34))
		v.add_child(UIKit.stat_bar("自信", p.confidence, 100.0, 60, Color(0, 0, 0, 0), 34))
		v.add_child(UIKit.stat_bar("疲勞", p.fatigue, 100.0, 60, UIKit.BAD if p.fatigue > 70 else UIKit.MUTED, 34))
		v.add_child(UIKit.stat_bar("壓力", p.stress, 100.0, 60, UIKit.BAD if p.stress > 60 else UIKit.MUTED, 34))
	var pc = UIKit.panel(v)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	if p:
		pc.tooltip_text = "滿意度 %+.2f" % p.happiness
	return pc


func _streak(c: Club) -> String:
	return ("%d 連勝" % c.streak) if c.streak > 0 else (("%d 連敗" % -c.streak) if c.streak < 0 else "無連勝紀錄")


static func _short_num(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%dk" % int(n / 1000)
	return str(n)


static func _short_money(n: int) -> String:
	return "$" + _short_num(n)
