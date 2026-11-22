## 財務：本季收支、預估收入、贊助合約與贊助報價、歷年帳本。
class_name FinanceScreen
extends UIScreen

var offers_box: VBoxContainer


func build() -> void:
	var f = session.finance_summary()
	var c = session.club()
	add_child(UIKit.title("財務"))
	var top := UIKit.hbox(12)
	add_child(top)
	var t = f["totals"]
	top.add_child(_card("資金", UIKit.money(c.cash), "本季淨收支 %s" % _signed(t["net"])))
	top.add_child(_card("預估年收入", UIKit.money(f["projected_income"]), "不含獎金與轉會"))
	top.add_child(_card("選手薪資", "%s / %s" % [UIKit.money(f["player_wages"]), UIKit.money(f["wage_budget"])], "年薪 / 薪資預算"))
	top.add_child(_card("員工薪資", UIKit.money(f["staff_wages"]), "教練團年薪合計"))

	var cols := UIKit.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)
	var left := UIKit.vbox()
	var lp = UIKit.panel(left)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(lp)
	left.add_child(UIKit.label("本季帳本", 17))
	var led := UIKit.table(["項目", "收入", "支出"], 330)
	for k in Finance.INCOME_NAMES:
		var v = int(f["ledger"].get("income", {}).get(k, 0))
		if v != 0:
			UIKit.add_row(led, [Finance.INCOME_NAMES[k], UIKit.money(v), ""])
	for k in Finance.EXPENSE_NAMES:
		var v = int(f["ledger"].get("expense", {}).get(k, 0))
		if v != 0:
			UIKit.add_row(led, [Finance.EXPENSE_NAMES[k], "", UIKit.money(v)])
	UIKit.add_row(led, ["合計", UIKit.money(t["income"]), UIKit.money(t["expense"])])
	left.add_child(led)
	left.add_child(UIKit.label("歷年", 17))
	var hist := UIKit.table(["年份", "收入", "支出", "淨額", "年末資金"], 140, [0, 1, 2, 3, 4])
	var h: Array = f["history"].duplicate()
	h.reverse()
	for e in h:
		var tt = Finance.totals(e)
		UIKit.add_row(hist, [int(e["year"]), UIKit.money(tt["income"]), UIKit.money(tt["expense"]), _signed(tt["net"]), UIKit.money(int(e["cash_end"]))])
	left.add_child(hist)

	var right := UIKit.vbox()
	var rp = UIKit.panel(right)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(rp)
	right.add_child(UIKit.label("董事會與品牌", 17))
	right.add_child(UIKit.label("董事會信心 %d（%s）　品牌價值 %d（收入 ×%.2f）" % [int(c.board_confidence), Organization.label(c.board_confidence),
		int(c.brand), Organization.brand_multiplier(c)], 14, UIKit.BAD if c.board_confidence < 30 else UIKit.TEXT))
	var camp := HFlowContainer.new()
	for k in Organization.BRAND_CAMPAIGNS:
		var info: Dictionary = Organization.BRAND_CAMPAIGNS[k]
		camp.add_child(UIKit.button("%s（%s）" % [info["name"], UIKit.money(int(info["cost"]))], func():
			var r = session.run_brand_campaign(k)
			toast(r["note"])
			refresh()))
	right.add_child(camp)
	right.add_child(UIKit.muted("品牌活動提升品牌價值與粉絲；品牌越強，贊助與周邊收入越高，但邊際效益遞減。"))
	right.add_child(UIKit.label("贊助合約", 17))
	if c.sponsors.is_empty():
		right.add_child(UIKit.muted("目前沒有贊助"))
	for s in c.sponsors:
		right.add_child(UIKit.label("%s　%s　每年 %s　至 %d 年" % [Finance.SPONSOR_KINDS.get(s["kind"], s["kind"]), s["name"], UIKit.money(int(s["yearly"])), int(s["end_year"])], 14))
		var b = _bonus_text(s)
		if b != "":
			right.add_child(UIKit.muted("　" + b))
	right.add_child(UIKit.label("待選擇的贊助報價", 17))
	offers_box = UIKit.vbox(6)
	right.add_child(offers_box)
	_fill_offers()


func _fill_offers() -> void:
	UIKit.clear(offers_box)
	var offers: Array = session.sponsor_offers()
	if offers.is_empty():
		offers_box.add_child(UIKit.muted("休賽季開始時，到期的贊助位置會收到新報價。"))
		return
	for i in offers.size():
		var o = offers[i]
		var row := UIKit.hbox()
		var txt = "%s・%s　%s　每年 %s × %d 年" % [Finance.SPONSOR_KINDS[o["kind"]], Finance.style_name(o["style"]), o["name"], UIKit.money(int(o["yearly"])), int(o["years"])]
		var b = _bonus_text(o)
		var l := UIKit.label(txt + ("\n　" + b if b != "" else ""), 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.button("簽約", _sign.bind(i)))
		offers_box.add_child(row)


func _sign(i: int) -> void:
	var r = session.sign_sponsor(i)
	toast(r["note"])
	UIKit.clear(self)
	build()


func _bonus_text(s: Dictionary) -> String:
	var parts: Array = []
	if int(s.get("bonus_title", 0)) > 0:
		parts.append("奪冠獎金 %s" % UIKit.money(int(s["bonus_title"])))
	if int(s.get("bonus_playoffs", 0)) > 0:
		parts.append("進季後賽或前 %d 名獎金 %s" % [int(s.get("target", 0)), UIKit.money(int(s["bonus_playoffs"]))])
	return "、".join(parts)


func _signed(v: int) -> String:
	return ("+" if v >= 0 else "-") + UIKit.money(absi(v))


func _card(t: String, big: String, small: String) -> PanelContainer:
	var v := UIKit.vbox(2)
	v.add_child(UIKit.muted(t))
	v.add_child(UIKit.label(big, 17))
	v.add_child(UIKit.muted(small))
	var p = UIKit.panel(v)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p
