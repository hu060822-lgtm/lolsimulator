## 存檔槽位。
class_name SavesScreen
extends UIScreen

var box: VBoxContainer


func build() -> void:
	add_child(UIKit.title("存檔"))
	box = UIKit.vbox(8)
	add_child(box)


func refresh() -> void:
	UIKit.clear(box)
	for slot in range(1, 4):
		var meta = GameSession.slot_info(slot)
		var row := UIKit.hbox()
		row.add_child(UIKit.label("存檔 %d：%s" % [slot, ("%s・%d 年第 %d 天・%s" % [meta["club"], int(meta["year"]), int(meta["day"]), meta.get("saved_at", "")]) if not meta.is_empty() else "（空）"]))
		row.add_child(UIKit.button("儲存", _save.bind(slot)))
		var l := UIKit.button("讀取", _load.bind(slot))
		l.disabled = meta.is_empty()
		row.add_child(l)
		box.add_child(UIKit.panel(row))
	box.add_child(UIKit.button("回到主選單", func(): shell.app.show_new_game()))


func _save(slot: int) -> void:
	var err = session.save_slot(slot)
	toast("已儲存到存檔 %d" % slot if err == OK else "儲存失敗（%d）" % err)
	refresh()


func _load(slot: int) -> void:
	if session.load_slot(slot):
		shell.app.start_game()
