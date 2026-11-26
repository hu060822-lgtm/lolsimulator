## Club Dashboard：俱樂部整體狀況。
class_name DashboardScreen
extends UIScreen

var body: VBoxContainer


func build() -> void:
	body = UIKit.vbox(16)
	add_child(body)


func refresh() -> void:
	UIKit.clear(body)
	var c = session.club()
	var ww = w()
	var lg: League = ww.leagues[c.league_id]
	var st: Dictionary = lg.standings.get(c.id, {"w": 0, "l": 0})
	var pos = LeagueEngine.sorted_standings(lg).find(c.id) + 1
	var my_sub := "%s 第 %d・%d 勝 %d 敗" % [lg.short_name if lg.short_name != "" else lg.name, pos, int(st["w"]), int(st["l"])]
	# 主視覺：下一場比賽的對戰橫幅；沒有賽程時是俱樂部橫幅
	var next_day = LeagueEngine.next_match_day(ww, c.id)
	var f = LeagueEngine.find_fixture(ww, c.id, next_day) if next_day != -1 else {}
	if f.is_empty():
		body.add_child(MatchBanner.make(c, null, "%s・粉絲 %s・外界%s" % [my_sub, _short_num(c.fanbase), Media.label(c.opinion)], "", 170))
		body.add_child(UIKit.label("本季已無賽程", 15, UIKit.MUTED))
	else:
		var fx: Dictionary = f["fixture"]
		var opp: Club = ww.clubs[fx["away"] if fx["home"] == c.id else fx["home"]]
		var olg: League = ww.leagues.get(opp.league_id)
		var opos := LeagueEngine.sorted_standings(olg).find(opp.id) + 1 if olg else 0
		var form := MatchBriefing.recent_form(ww, opp.id, 3)
		var form_txt := "".join(form.map(func(x): return "▲" if x == "W" else "▼"))
		var opp_sub := ("聯賽第 %d" % opos) + (("・近況 " + form_txt) if form_txt != "" else "")
		var mb := MatchBanner.make(c, opp, my_sub, opp_sub)
		if Rivalry.is_rival(ww, opp.id):
			mb.center_caption = "宿敵戰"
		body.add_child(mb)
		var strip := UIKit.hbox(8)
		var left := UIKit.hbox(6)
		left.add_child(UIKit.bold("下一場", 16))
		left.add_child(UIKit.bold("第 %d 天" % next_day, 16, UIKit.GOLD))
		left.add_child(UIKit.bold("%s %s" % [UIKit.bo_text(int(fx["best_of"])), _stage(f)], 16))
		strip.add_child(left)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.add_child(sp)
		var br = MatchBriefing.build(ww, fx, c.id)
		if not br.is_empty():
			strip.add_child(UIKit.label("預估勝率", 15, UIKit.MUTED))
			strip.add_child(UIKit.bold("%d%%" % clampi(roundi(float(br["win_series"]) * 100.0), 1, 99), 16))
			strip.add_child(UIKit.label("對手打法", 15, UIKit.MUTED))
			strip.add_child(UIKit.bold(UIKit.PLAN_NAMES.get(br["opp_plan"], br["opp_plan"]), 16))
		body.add_child(strip)
	# 數字列：一條橫向分隔的資訊帶
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var bill = TransferMarket.wage_bill(ww, c)
	var mgr: Dictionary = ManagerCareer.data(ww)
	row.add_child(_figure("聯賽排名", "#%d" % pos, _streak(c), UIKit.GOLD_LIGHT))
	row.add_child(_figure("資金", _short_money(c.cash), "薪資 %s / 預算 %s" % [_short_money(bill), _short_money(c.wage_budget)], UIKit.GOOD if c.cash > 0 else UIKit.BAD))
	var rep = _figure("經理聲望", str(roundi(float(mgr["reputation"]))), "董事會信心 %d" % roundi(c.board_confidence), UIKit.GOLD_LIGHT)
	rep.tooltip_text = "依名次與外界預期的差距、冠軍與國際賽變動。聲望高會有更大的俱樂部來挖你；董事會信心低於 %d 時，賽季結束會被開除。" % int(ManagerCareer.FIRE_CONFIDENCE)
	row.add_child(rep)
	var org := UIKit.vbox(4)
	org.add_child(UIKit.stat_bar("品牌", c.brand, 100.0, 150, UIKit.GOLD, 64))
	org.add_child(UIKit.stat_bar("默契", c.chemistry, 100.0, 150, UIKit.GOLD, 64))
	org.add_child(UIKit.stat_bar("BP 熟悉", c.draft_familiarity, 100.0, 150, UIKit.GOLD, 64))
	org.add_child(UIKit.stat_bar("粉絲", minf(100.0, c.fanbase / 20000.0), 100.0, 150, UIKit.HEX, 64, _short_num(c.fanbase)))
	row.add_child(_cell(org, false))
	body.add_child(_ruled(row))
	# 先發陣容
	var sh := UIKit.hbox(12)
	sh.add_child(UIKit.bold("先發陣容", 21))
	var hint := UIKit.label("格數代表士氣", 13, UIKit.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	sh.add_child(hint)
	body.add_child(sh)
	var starters := UIKit.hbox(14)
	for role in Attr.ROLES:
		var sp: Player = ww.players.get(c.lineup.get(role, ""))
		if sp == null:
			starters.add_child(_starter_card(null, role))
			continue
		var cc := CollectorCard.make(session, sp, 176, role)
		cc.morale = sp.morale
		if sp.fatigue > 70:
			cc.tag_text = "疲勞 %d" % int(sp.fatigue)
			cc.tag_color = UIKit.WARN
		elif sp.stress > 60:
			cc.tag_text = "壓力 %d" % int(sp.stress)
			cc.tag_color = UIKit.WARN
		cc.tooltip_text = "士氣 %d・自信 %d・疲勞 %d・壓力 %d・滿意度 %+.2f" % [int(sp.morale), int(sp.confidence), int(sp.fatigue), int(sp.stress), sp.happiness]
		cc.pressed.connect(_open_player.bind(sp.id))
		starters.add_child(cc)
	body.add_child(starters)
	# 動態：收件匣、媒體、最近戰績
	var row2 := UIKit.hbox(10)
	body.add_child(row2)
	var msgs = session.open_messages()
	if msgs.is_empty():
		row2.add_child(_feed_card("收件匣", "沒有待處理事項", "", func(): shell.open("inbox")))
	else:
		row2.add_child(_feed_card("收件匣　%d 件待處理" % msgs.size(), str(msgs[0]["text"]), "第 %d 天" % int(msgs[0].get("day", ww.day)), func(): shell.open("inbox"), UIKit.GOLD))
	var items = Media.club_news(ww, c.id, 1)
	if items.is_empty():
		row2.add_child(_feed_card("媒體", "還沒有關於球隊的報導", "", func(): shell.open("news")))
	else:
		var tone := float(items[0]["tone"])
		row2.add_child(_feed_card("媒體", str(items[0]["text"]), "第 %d 天" % int(items[0].get("day", ww.day)), func(): shell.open("news"), UIKit.GOOD if tone > 0.3 else (UIKit.BAD if tone < -0.3 else UIKit.MUTED)))
	row2.add_child(_recent_card(c))
	for ch in row2.get_children():
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 本季目標與宿敵
	var row3 := UIKit.hbox(10)
	body.add_child(row3)
	var gc := _goals_card()
	gc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gc.size_flags_stretch_ratio = 2.0
	row3.add_child(gc)
	var rc := _rival_card()
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(rc)


## 董事會開的本季目標：每項一行，右側是進度。
func _goals_card() -> PanelContainer:
	var ww = w()
	var v := UIKit.vbox(8)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.bold("本季目標", 18))
	var hint := UIKit.label("每達成一項董事會信心 +%d，失敗 -%d" % [int(SeasonGoals.BOARD_PER_GOAL), int(SeasonGoals.BOARD_PER_GOAL)], 13, UIKit.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(hint)
	v.add_child(head)
	var g := SeasonGoals.current(ww)
	for goal in g.get("list", []):
		var pr := SeasonGoals.progress(ww, goal)
		var line := UIKit.hbox(10)
		var done = pr["done"]
		var mark := UIKit.big_num("✓" if done == true else "•", 18, UIKit.GOOD if done == true else UIKit.GOLD)
		mark.custom_minimum_size = Vector2(18, 0)
		line.add_child(mark)
		var t := UIKit.bold(str(goal["text"]), 16)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(t)
		line.add_child(UIKit.label(str(pr["progress"]), 15, UIKit.MUTED))
		v.add_child(line)
	var p := UIKit.panel(v)
	var sb := UIKit._card(UIKit.PANEL, 0)
	sb.border_width_top = 3
	sb.border_color = UIKit.GOLD
	p.add_theme_stylebox_override("panel", sb)
	return p


## 本季宿敵：隊徽、為什麼是他、本季對戰紀錄。
func _rival_card() -> PanelContainer:
	var ww = w()
	var v := UIKit.vbox(6)
	v.add_child(UIKit.label("本季宿敵", 14, UIKit.MUTED))
	var r := Rivalry.current(ww)
	var rc: Club = ww.clubs.get(r.get("club_id", "")) if not r.is_empty() else null
	var col := UIKit.BAD
	if rc == null:
		v.add_child(UIKit.bold("尚未決定", 16))
	else:
		col = Badge.club_color(rc.id)
		var h := UIKit.hbox(10)
		h.add_child(Badge.club(rc, 44))
		var nv := UIKit.vbox(0)
		nv.add_child(UIKit.big_num(rc.short_name, 30, UIKit.GOLD_LIGHT))
		nv.add_child(UIKit.label(str(r.get("reason", "")), 13, UIKit.MUTED))
		h.add_child(nv)
		v.add_child(h)
		v.add_child(UIKit.bold("本季對戰 %d 勝 %d 敗" % [int(r.get("w", 0)), int(r.get("l", 0))], 16))
		var tip := UIKit.label("宿敵戰勝負影響加倍：士氣、粉絲、品牌、董事會", 13, UIKit.MUTED)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tip)
	var p := UIKit.panel(v)
	var sb := UIKit._card(UIKit.PANEL, 0)
	sb.border_width_top = 3
	sb.border_color = col
	p.add_theme_stylebox_override("panel", sb)
	return p


func _open_player(pid: String) -> void:
	shell.open("roster")
	if shell.page is RosterScreen:
		shell.page._pick(pid)


func _stage(f: Dictionary) -> String:
	var fx: Dictionary = f["fixture"]
	var comp: League = f["league"]
	var stage = {"regular": "例行賽", "playoffs": "季後賽", "final": "決賽"}.get(fx["stage"], fx["stage"])
	if comp.tier == 0:
		stage = comp.name + ("小組賽" if fx["stage"] == "regular" else ("決賽" if fx["stage"] == "final" else "淘汰賽"))
	if fx.has("label"):
		stage = (comp.short_name if comp.short_name != "" else comp.name) + " " + str(fx["label"])
	return stage


## 數字列的一格：灰色小標、窄體大數字、一行補充。
func _figure(cap: String, big: String, small: String, col: Color) -> Control:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(cap, 14, UIKit.MUTED))
	v.add_child(UIKit.big_num(big, 48, col))
	v.add_child(UIKit.label(small, 14, UIKit.MUTED))
	return _cell(v, true)


func _cell(child: Control, divider: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UIKit.BORDER
	sb.border_width_right = 1 if divider else 0
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(child)
	return p


## 上下兩條粗分隔線包住的資訊帶。
func _ruled(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UIKit.BORDER
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(child)
	return p


func _starter_card(p: Player, role: String) -> PanelContainer:
	var ww = w()
	var v := UIKit.vbox(2)
	var top := UIKit.hbox(4)
	var left := UIKit.vbox(0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rl := UIKit.label(UIKit.ROLE_SHORT[role], 16, UIKit.MUTED)
	rl.add_theme_font_override("font", UIKit.cond_font())
	left.add_child(rl)
	top.add_child(left)
	v.add_child(top)
	if p == null:
		left.add_child(UIKit.big_num("空缺", 30, UIKit.BAD))
	else:
		var ca = p.current_ability(role)
		var nm := UIKit.big_num(p.handle, 30, UIKit.GOLD_LIGHT)
		nm.clip_text = true
		nm.custom_minimum_size = Vector2(60, 0)
		left.add_child(nm)
		var ovr := UIKit.big_num(str(int(ca)), 54, UIKit.GOLD)
		ovr.tooltip_text = "目前能力"
		ovr.mouse_filter = Control.MOUSE_FILTER_PASS
		top.add_child(ovr)
		var segs := UIKit.hbox(5)
		var lit := clampi(roundi(p.morale / 20.0), 0, 5)
		for i in 5:
			var r := ColorRect.new()
			r.custom_minimum_size = Vector2(0, 5)
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.color = UIKit.GOLD if i < lit else Color("2b3270")
			segs.add_child(r)
		segs.tooltip_text = "士氣 %d" % int(p.morale)
		segs.mouse_filter = Control.MOUSE_FILTER_PASS
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6)
		v.add_child(gap)
		v.add_child(segs)
		var warn := p.fatigue > 70 or p.stress > 60
		v.add_child(UIKit.label("%d 歲・疲勞 %d%s" % [p.age(ww.year), int(p.fatigue), ("・壓力 %d" % int(p.stress)) if p.stress > 40 else ""], 13, UIKit.WARN if warn else UIKit.MUTED))
	var pc = UIKit.panel(v)
	var sb = UIKit._card(UIKit.PANEL, 0)
	sb.content_margin_top = 10
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	if p:
		pc.tooltip_text = "士氣 %d・自信 %d・疲勞 %d・壓力 %d・滿意度 %+.2f" % [int(p.morale), int(p.confidence), int(p.fatigue), int(p.stress), p.happiness]
	return pc


## 動態卡：小標、一行粗體重點、補充；整張可點。
func _feed_card(cap: String, text: String, small: String, cb: Callable, col: Color = UIKit.MUTED) -> Button:
	var b := Button.new()
	b.pressed.connect(cb)
	b.custom_minimum_size = Vector2(0, 96)
	var n := UIKit._card(UIKit.PANEL, 0)
	n.border_width_left = 4
	n.border_color = col
	var h = n.duplicate()
	h.bg_color = UIKit.PANEL_2
	for k in ["normal", "focus"]:
		b.add_theme_stylebox_override(k, n)
	for k in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(k, h)
	var v := UIKit.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	v.offset_left = 18
	v.offset_right = -14
	v.offset_top = 12
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := UIKit.label(cap, 14, UIKit.MUTED)
	var tl := UIKit.bold(text, 16)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.max_lines_visible = 2
	for l in [cl, tl, UIKit.label(small, 13, UIKit.MUTED)]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	b.add_child(v)
	return b


## 最近五場：W／L 方塊。
func _recent_card(c: Club) -> PanelContainer:
	var ww = w()
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label("最近戰績", 14, UIKit.MUTED))
	var form := UIKit.hbox(6)
	for e in ww.log.of_type("match").filter(func(x): return c.id in x["actors"]).slice(-5):
		var other: String = e["actors"][1] if e["actors"][0] == c.id else e["actors"][0]
		var won: bool = e["data"]["winner"] == c.id
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIKit.GOOD if won else UIKit.BAD
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		box.add_theme_stylebox_override("panel", sb)
		box.add_child(UIKit.big_num("W" if won else "L", 22, UIKit.INK))
		box.tooltip_text = "對 %s　%s" % [UIKit.club_label(ww.clubs[other]), e["data"]["score"]]
		form.add_child(box)
	if form.get_child_count() == 0:
		v.add_child(UIKit.bold("尚未出賽", 16))
	else:
		v.add_child(form)
	var p := UIKit.panel(v)
	p.add_theme_stylebox_override("panel", UIKit._card(UIKit.PANEL, 0))
	return p


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
