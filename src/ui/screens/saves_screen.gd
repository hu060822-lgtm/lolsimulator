## 存檔槽位。
class_name SavesScreen
extends UIScreen

var box: VBoxContainer


func build() -> void:
	add_child(UIKit.title("存檔與設定"))
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
	var am = GameSession.slot_info(GameSession.AUTOSAVE_SLOT)
	var arow := UIKit.hbox()
	arow.add_child(UIKit.label("自動存檔：%s" % (("%s・%d 年第 %d 天・%s" % [am["club"], int(am["year"]), int(am["day"]), am.get("saved_at", "")]) if not am.is_empty() else "（尚未存檔）")))
	var al := UIKit.button("讀取", _load.bind(GameSession.AUTOSAVE_SLOT))
	al.disabled = am.is_empty()
	arow.add_child(al)
	box.add_child(UIKit.panel(arow))
	# 設定
	var c: Club = session.club()
	box.add_child(UIKit.bold("設定", 18))
	box.add_child(_toggle("每週自動存檔", "autosave", true, "推進時間時，每隔一週自動存到「自動存檔」槽"))
	box.add_child(_toggle("比賽日自動交給教練團", "auto_sim", false, "按「繼續」遇到比賽日時直接快速模擬，不進賽前情報"))
	box.add_child(_toggle("例行事項自動交給助理", "delegate", false, "通知、記者會、隊友小請求由助理處理"))
	var sp := UIKit.hbox(6)
	sp.add_child(UIKit.label("比賽預設播放速度", 15))
	for k in MatchCenter.SPEEDS:
		var b := UIKit.chip(k, _set_speed.bind(k))
		b.button_pressed = str(c.settings.get("match_speed", "1x")) == k
		sp.add_child(b)
	box.add_child(UIKit.panel(sp))
	box.add_child(UIKit.muted(GuideOverlay.SHORTCUTS))
	box.add_child(UIKit.button("重新看新手引導", func(): GuideOverlay.open(shell, "dashboard", true)))
	box.add_child(UIKit.button("回到主選單", func(): shell.app.show_new_game()))


func _toggle(text: String, key: String, default: bool, hint: String) -> Control:
	var row := UIKit.hbox(10)
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = bool(session.club().settings.get(key, default))
	cb.toggled.connect(func(on): session.club().settings[key] = on)
	row.add_child(cb)
	row.add_child(UIKit.label(hint, 13, UIKit.MUTED))
	return UIKit.panel(row)


func _set_speed(k: String) -> void:
	session.club().settings["match_speed"] = k
	refresh()


func _save(slot: int) -> void:
	var err = session.save_slot(slot)
	toast("已儲存到存檔 %d" % slot if err == OK else "儲存失敗（%d）" % err)
	refresh()


func _load(slot: int) -> void:
	if session.load_slot(slot):
		shell.app.start_game()
