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
	body.add_child(UIKit.title(UIKit.club_label(c)))
	body.add_child(UIKit.muted("%s・聲望 %.0f・粉絲 %d・經營方向 %s" % [lg.name, c.reputation, c.fanbase, UIKit.philosophy_name(c.philosophy)]))
	var row := UIKit.hbox(12)
	body.add_child(row)
	# 卡片：下一場比賽
	var next_day = LeagueEngine.next_match_day(ww, c.id)
	var nm := "本季已無賽程"
	if next_day != -1:
		var f = LeagueEngine.find_fixture(ww, c.id, next_day)
		if not f.is_empty():
			var fx: Dictionary = f["fixture"]
			var opp: String = fx["away"] if fx["home"] == c.id else fx["home"]
			nm = "第 %d 天 對 %s\n%s・%s" % [next_day, UIKit.club_label(ww.clubs[opp]), UIKit.bo_text(int(fx["best_of"])), "例行賽" if fx["stage"] == "regular" else "季後賽"]
	row.add_child(_card("下一場比賽", nm))
	var st: Dictionary = lg.standings.get(c.id, {"w": 0, "l": 0})
	var pos = LeagueEngine.sorted_standings(lg).find(c.id) + 1
	row.add_child(_card("聯賽排名", "第 %d 名（%d 勝 %d 敗）" % [pos, int(st["w"]), int(st["l"])]))
	var bill = TransferMarket.wage_bill(ww, c)
	row.add_child(_card("財務", "資金 %s\n薪資 %s / 預算 %s" % [UIKit.money(c.cash), UIKit.money(bill), UIKit.money(c.wage_budget)]))
	var mood = Relationships.team_average(ww, c)
	var streak_txt = ("%d 連勝" % c.streak) if c.streak > 0 else (("%d 連敗" % -c.streak) if c.streak < 0 else "—")
	row.add_child(_card("團隊", "默契 %.0f・BP 熟悉度 %.0f\n隊內氣氛 %s（%+d）・%s" % [c.chemistry, c.draft_familiarity, Relationships.label(mood), int(mood), streak_txt]))
	for ch in row.get_children():
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 先發狀態
	body.add_child(UIKit.label("先發陣容狀態", 17))
	var t := UIKit.table(["選手", "位置", "年齡", "士氣", "自信", "壓力", "疲勞", "滿意度"], 210)
	for role in Attr.ROLES:
		var p: Player = ww.players.get(c.lineup.get(role, ""))
		if p:
			var it := UIKit.add_row(t, [p.handle, UIKit.ROLE_NAMES[role], p.age(ww.year), int(p.morale), int(p.confidence), int(p.stress), int(p.fatigue), "%+.2f" % p.happiness])
			it.set_custom_color(7, UIKit.GOOD if p.happiness > 0.1 else (UIKit.BAD if p.happiness < -0.2 else UIKit.WARN))
			it.set_custom_color(6, UIKit.BAD if p.fatigue > 70 else UIKit.TEXT)
	body.add_child(t)
	# 最近比賽 + 收件匣
	var row2 := UIKit.hbox(12)
	body.add_child(row2)
	var recent := UIKit.vbox(4)
	recent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recent.add_child(UIKit.label("最近比賽", 17))
	var shown := 0
	for e in ww.log.of_type("match").filter(func(x): return c.id in x["actors"]).slice(-5):
		var other: String = e["actors"][1] if e["actors"][0] == c.id else e["actors"][0]
		var won: bool = e["data"]["winner"] == c.id
		recent.add_child(UIKit.label("%s　對 %s　%s" % ["勝" if won else "敗", UIKit.club_label(ww.clubs[other]), e["data"]["score"]], 14, UIKit.GOOD if won else UIKit.BAD))
		shown += 1
	if shown == 0:
		recent.add_child(UIKit.muted("尚未出賽"))
	row2.add_child(UIKit.panel(recent))
	var inbox := UIKit.vbox(4)
	inbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inbox.add_child(UIKit.label("收件匣", 17))
	var msgs = session.open_messages()
	for m in msgs.slice(0, 5):
		inbox.add_child(UIKit.label("• " + m["text"], 14, UIKit.WARN))
	if msgs.is_empty():
		inbox.add_child(UIKit.muted("沒有待處理事項"))
	else:
		inbox.add_child(UIKit.button("前往收件匣", func(): shell.open("inbox")))
	row2.add_child(UIKit.panel(inbox))
	for ch in row2.get_children():
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _card(title: String, text: String) -> PanelContainer:
	var v := UIKit.vbox(4)
	v.add_child(UIKit.muted(title))
	v.add_child(UIKit.label(text, 16))
	return UIKit.panel(v)
