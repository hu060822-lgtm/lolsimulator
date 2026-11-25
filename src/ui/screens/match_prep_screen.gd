## 賽前情報：比賽日先看對手、勝率因素與克制建議，再決定親自 BP 指揮或交給教練團快速模擬。
class_name MatchPrepScreen
extends UIScreen

var body: VBoxContainer
var result_box: VBoxContainer


func build() -> void:
	body = UIKit.vbox(10)
	add_child(body)
	result_box = UIKit.vbox(10)
	add_child(result_box)


func refresh() -> void:
	UIKit.clear(body)
	var b: Dictionary = session.match_briefing()
	if b.is_empty():
		if result_box.get_child_count() == 0:
			body.add_child(UIKit.title("賽前情報"))
			body.add_child(UIKit.muted("明天沒有比賽。"))
		return
	var ww = w()
	var me: Club = session.club()
	var opp: Club = ww.clubs[b["opponent"]]
	var head = UIKit.hbox(10)
	head.add_child(UIKit.title("賽前情報"))
	head.add_child(UIKit.pill(b["competition"], UIKit.GOLD))
	head.add_child(UIKit.pill(UIKit.bo_text(int(b["best_of"])), UIKit.MUTED))
	body.add_child(head)
	body.add_child(_versus(me, opp, b))
	var row = UIKit.hbox(10)
	var left = _factors(b)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right = _scouting(opp, b)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	body.add_child(row)
	body.add_child(_advice(b))
	var actions = UIKit.hbox(10)
	actions.add_child(UIKit.primary("進入 BP（親自指揮）", func(): shell.open_match()))
	actions.add_child(UIKit.button("教練團代打（快速模擬）", _quick_sim))
	var hint = UIKit.muted("快速模擬：BP 與臨場指揮交給教練團，直接看結果與勝負關鍵。")
	actions.add_child(hint)
	body.add_child(actions)


func _versus(me: Club, opp: Club, b: Dictionary) -> PanelContainer:
	var row = UIKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var a = UIKit.label(me.name, 20, UIKit.BLUE_SIDE.lightened(0.25))
	a.add_theme_font_override("font", UIKit.head_font())
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	row.add_child(Badge.club(me, 52))
	var mid = UIKit.vbox(0)
	var pct = float(b["win_series"]) * 100.0
	var big = UIKit.label("%d%%" % clampi(roundi(pct), 1, 99), 34, UIKit.GOOD if pct >= 55 else (UIKit.BAD if pct <= 45 else UIKit.GOLD_LIGHT))
	big.add_theme_font_override("font", UIKit.head_font())
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(big)
	var cap = UIKit.label("預估勝率", 12, UIKit.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(cap)
	mid.custom_minimum_size = Vector2(130, 0)
	row.add_child(mid)
	row.add_child(Badge.club(opp, 52))
	var o = UIKit.label(opp.name, 20, UIKit.RED_SIDE.lightened(0.25))
	o.add_theme_font_override("font", UIKit.head_font())
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(o)
	return UIKit.panel(row)


func _factors(b: Dictionary) -> PanelContainer:
	var v = UIKit.vbox(6)
	v.add_child(UIKit.label("勝率因素", 16, UIKit.GOLD))
	v.add_child(UIKit.muted("正值對我方有利。實力以外的因素都能靠準備改變。"))
	for f in b["factors"]:
		var pts = float(f["points"])
		var col = UIKit.GOOD if pts > 0.3 else (UIKit.BAD if pts < -0.3 else UIKit.MUTED)
		var bar = UIKit.stat_bar(f["label"], clampf(50.0 + pts * 6.0, 2.0, 100.0), 100.0, 150, col, 170, "%+.1f" % pts)
		bar.tooltip_text = f["detail"]
		v.add_child(bar)
		var d = UIKit.label(f["detail"], 12, UIKit.MUTED)
		v.add_child(d)
	return UIKit.panel(v)


func _scouting(opp: Club, b: Dictionary) -> PanelContainer:
	var ww = w()
	var v = UIKit.vbox(6)
	v.add_child(UIKit.label("對手情報：%s" % opp.short_name, 16, UIKit.GOLD))
	var style = UIKit.hbox(6)
	style.add_child(UIKit.label("招牌打法", 13, UIKit.MUTED))
	style.add_child(UIKit.pill(UIKit.PLAN_NAMES.get(b["opp_plan"], b["opp_plan"]).split("（")[0], UIKit.RED_SIDE))
	if b["opp_plan_set"] == "flexible":
		style.add_child(UIKit.label("（依陣容調整，推測）", 12, UIKit.MUTED))
	v.add_child(style)
	var form = UIKit.hbox(4)
	form.add_child(UIKit.label("近況", 13, UIKit.MUTED))
	if b["opp_form"].is_empty():
		form.add_child(UIKit.label("本季尚未出賽", 12, UIKit.MUTED))
	for r in b["opp_form"]:
		form.add_child(UIKit.pill(r, UIKit.GOOD if r == "W" else UIKit.BAD))
	var streak = int(b["opp_streak"])
	if absi(streak) >= 3:
		form.add_child(UIKit.label("　%d %s" % [absi(streak), "連勝" if streak > 0 else "連敗"], 13, UIKit.WARN))
	v.add_child(form)
	var star: Dictionary = b["opp_star"]
	if not star.is_empty():
		var sr = UIKit.hbox(6)
		sr.add_child(UIKit.label("王牌", 13, UIKit.MUTED))
		sr.add_child(UIKit.label("%s %s" % [UIKit.ROLE_SHORT.get(star["role"], ""), star["handle"]], 15, UIKit.GOLD_LIGHT))
		for cid in star["champions"]:
			var tok = ChampToken.make(ww.champions.get(cid), UIKit.RED_SIDE, 28)
			tok.tooltip_text = ww.champions[cid].name if ww.champions.has(cid) else cid
			sr.add_child(tok)
		v.add_child(sr)
	var cr = UIKit.hbox(6)
	cr.add_child(UIKit.label("拿手英雄", 13, UIKit.MUTED))
	for e in b["opp_champs"]:
		var ch: Champion = ww.champions.get(e["champion"])
		var tok = ChampToken.make(ch, UIKit.WARN, 28)
		tok.tooltip_text = "%s %s（可考慮禁用）" % [UIKit.ROLE_SHORT.get(e["role"], ""), ch.name if ch else e["champion"]]
		cr.add_child(tok)
	v.add_child(cr)
	return UIKit.panel(v)


func _advice(b: Dictionary) -> PanelContainer:
	var v = UIKit.vbox(6)
	v.add_child(UIKit.label("戰術準備", 16, UIKit.GOLD))
	var cur = UIKit.hbox(6)
	cur.add_child(UIKit.label("目前打法", 13, UIKit.MUTED))
	var name: String = UIKit.PLAN_NAMES.get(b["my_plan"], b["my_plan"]).split("（")[0]
	if b["my_plan_set"] == "flexible":
		name += "（彈性）"
	var rel = int(b["relation"])
	cur.add_child(UIKit.pill(name, UIKit.GOOD if rel > 0 else (UIKit.BAD if rel < 0 else UIKit.BLUE_SIDE)))
	var rtxt = "剋制對手：" + b["relation_reason"] if rel > 0 else ("被對手剋制：" + b["relation_reason"] if rel < 0 else "與對手打法沒有明顯相剋")
	cur.add_child(UIKit.label(rtxt, 13, UIKit.GOOD if rel > 0 else (UIKit.BAD if rel < 0 else UIKit.MUTED)))
	v.add_child(cur)
	var rec: String = b["recommended"]
	if rec != "" and rec != b["my_plan_set"]:
		var rr = UIKit.hbox(8)
		rr.add_child(UIKit.label("分析師建議", 13, UIKit.MUTED))
		rr.add_child(UIKit.button("改打「%s」" % UIKit.PLAN_NAMES.get(rec, rec), _set_plan.bind(rec)))
		rr.add_child(UIKit.label(b["recommended_reason"], 13, UIKit.TEXT))
		v.add_child(rr)
	var ww = w()
	if not b["my_exposed"].is_empty():
		var er := UIKit.hbox(6)
		er.add_child(UIKit.label("對手研究過", 13, UIKit.MUTED))
		for cid in b["my_exposed"]:
			var tok = ChampToken.make(ww.champions.get(cid), UIKit.BAD, 28)
			tok.tooltip_text = "%s：你最近正式賽常用，很可能被禁" % ww.champions[cid].name
			er.add_child(tok)
		er.add_child(UIKit.label("最近常用，很可能被禁或被針對", 12, UIKit.MUTED))
		v.add_child(er)
	if not b["my_pockets"].is_empty():
		var pr := UIKit.hbox(6)
		pr.add_child(UIKit.label("秘密武器", 13, UIKit.MUTED))
		for e in b["my_pockets"]:
			var tok2 = ChampToken.make(ww.champions.get(e["champion"]), UIKit.GOOD, 28)
			tok2.tooltip_text = "%s 的%s（熟練度 %d），對手沒看過" % [e["player"], ww.champions[e["champion"]].name, int(e["mastery"])]
			pr.add_child(tok2)
		pr.add_child(UIKit.label("沒在正式賽亮過的拿手英雄，拿出來時狀態 +4%", 12, UIKit.MUTED))
		v.add_child(pr)
	var avoid: Array = b["avoid"].map(func(p): return UIKit.PLAN_NAMES.get(p, p))
	if not avoid.is_empty():
		v.add_child(UIKit.muted("避免：%s（會被對手的打法剋制）。" % "、".join(avoid)))
	return UIKit.panel(v)


func _set_plan(plan: String) -> void:
	session.set_tactics(plan, float(session.club().tactics.get("aggression", 0.5)))
	toast("戰術已改為「%s」" % UIKit.PLAN_NAMES.get(plan, plan))
	refresh()


func _quick_sim() -> void:
	var ww = w()
	var r: Dictionary = session.auto_play_match()
	UIKit.clear(body)
	UIKit.clear(result_box)
	var s: Dictionary = r.get("series", {})
	var fx: Dictionary = r.get("fixture", {})
	var me_id: String = ww.human_club_id
	var opp_id: String = fx.get("away", "") if fx.get("home", "") == me_id else fx.get("home", "")
	var won: bool = s.get("winner", "") == me_id
	result_box.add_child(UIKit.title("比賽結果"))
	var sc = UIKit.hbox(12)
	sc.alignment = BoxContainer.ALIGNMENT_CENTER
	sc.add_child(Badge.club(ww.clubs.get(me_id), 46))
	var score = UIKit.label("%d : %d" % [int(s["score"].get(me_id, 0)), int(s["score"].get(opp_id, 0))], 34, UIKit.GOOD if won else UIKit.BAD)
	score.add_theme_font_override("font", UIKit.head_font())
	sc.add_child(score)
	sc.add_child(Badge.club(ww.clubs.get(opp_id), 46))
	sc.add_child(UIKit.label("勝利" if won else "落敗", 22, UIKit.GOOD if won else UIKit.BAD))
	result_box.add_child(UIKit.panel(sc))
	var i = 0
	for g in s.get("games", []):
		i += 1
		var v = UIKit.vbox(4)
		var my_side = "blue" if g.get("blue_club", "") == me_id else "red"
		var gw: bool = g.get("winner", "") == my_side
		var mvp: Player = ww.players.get(g.get("mvp", ""))
		v.add_child(UIKit.label("第 %d 局　%s　%d 分鐘　MVP %s" % [i, "勝" if gw else "負", int(g.get("duration", 0)), mvp.handle if mvp else "-"], 15, UIKit.GOOD if gw else UIKit.BAD))
		var kp = PostGame.key_panel(session, g)
		if kp:
			v.add_child(kp)
		result_box.add_child(UIKit.panel(v))
	result_box.add_child(UIKit.primary("查看賽程", func(): shell.after_match()))
	shell.refresh_status()
