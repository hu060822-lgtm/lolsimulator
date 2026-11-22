## News / Inbox：選手要求、轉會報價、合約到期等需要決策的事項。
class_name InboxScreen
extends UIScreen

var list: VBoxContainer


func build() -> void:
	add_child(UIKit.title("收件匣"))
	add_child(UIKit.muted("選手的反應取決於他的個性、目標與對你的信任——同一句話對不同人效果不同。"))
	list = UIKit.vbox(10)
	add_child(list)


func refresh() -> void:
	UIKit.clear(list)
	var msgs = session.open_messages()
	if msgs.is_empty():
		list.add_child(UIKit.muted("沒有待處理事項。"))
	for m in msgs:
		var v := UIKit.vbox(6)
		v.add_child(UIKit.label("第 %d 天　%s" % [int(m["day"]), m["text"]], 16))
		if m.has("causes") and m["causes"].size() > 0:
			v.add_child(UIKit.muted("原因：" + "、".join(m["causes"])))
		var pid: String = m.get("player_id", "")
		if pid != "" and w().players.has(pid):
			var p: Player = w().players[pid]
			v.add_child(UIKit.muted("%s：%s・%d 歲・目標 %s・滿意度 %+.2f・信任 %d" % [p.handle, UIKit.ROLE_NAMES[p.primary_role], p.age(w().year),
				"、".join(p.goals.map(func(g): return UIKit.GOAL_NAMES.get(g, g))), p.happiness, int(p.trust_in_management)]))
		var row := UIKit.hbox()
		for opt in m.get("options", ["acknowledge"]):
			row.add_child(UIKit.button(m.get("option_labels", {}).get(opt, UIKit.RESPONSE_NAMES.get(opt, opt)), _respond.bind(m["id"], opt)))
		v.add_child(row)
		list.add_child(UIKit.accent_panel(v))
	var log := UIKit.vbox(2)
	log.add_child(UIKit.label("最近的回應紀錄", 16))
	for e in w().log.entries.filter(func(x): return x["type"] in ["player_talk", "promise_kept", "promise_broken", "transfer", "offer_rejected"]).slice(-8):
		log.add_child(UIKit.muted("第 %d 天　%s　%s" % [int(e["day"]), e["type"], "、".join(e["causes"])]))
	list.add_child(UIKit.panel(log))


func _respond(msg_id: String, option: String) -> void:
	var r = session.respond_to_message(msg_id, option)
	toast(str(r.get("note", r.get("reason", "已處理"))) if r.has("note") or r.has("reason") else "已處理")
	refresh()
	shell.refresh_status()
