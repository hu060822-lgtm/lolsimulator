## 原型 UI：證明「UI 只透過 GameSession 與模擬核心溝通」。
## 正式 UI（Dashboard / Roster / Match Center…）會取代這個畫面。
extends Control

const MODULE := "res://data/modules/fictional_base"
const HUMAN_CLUB := "harbor_lights"

var session := GameSession.new()
var info: RichTextLabel
var feed: RichTextLabel


func _ready() -> void:
	var errors = session.new_game(MODULE, 2027, HUMAN_CLUB)
	_build_layout()
	if not errors.is_empty():
		info.text = "資料模組錯誤：\n" + "\n".join(errors)
		return
	session.match_played.connect(_on_match)
	_refresh()


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("111317")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	var bar := HBoxContainer.new()
	left.add_child(bar)
	for spec in [["推進一天", _on_day], ["推進到下一場比賽", _on_next], ["推進一週", _on_week]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		bar.add_child(b)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(info)
	feed = RichTextLabel.new()
	feed.bbcode_enabled = true
	feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed.text = "[b]比賽文字直播[/b]\n（推進到下一場比賽後顯示）"
	root.add_child(feed)


func _on_day() -> void:
	session.advance_day()
	_refresh()


func _on_week() -> void:
	for i in 7:
		session.advance_day()
	_refresh()


func _on_next() -> void:
	session.advance_to_next_match()
	_refresh()


func _on_match(r: Dictionary) -> void:
	var w := session.world
	var s: Dictionary = r["series"]
	var lines: Array = ["[b]%s %d - %d %s[/b]" % [w.clubs[r["fixture"]["home"]].name, s["score"][r["fixture"]["home"]], s["score"][r["fixture"]["away"]], w.clubs[r["fixture"]["away"]].name]]
	for gi in s["games"].size():
		var g: Dictionary = s["games"][gi]
		lines.append("\n[color=#8ab4f8]第 %d 局（%d 分鐘）[/color]" % [gi + 1, g["duration"]])
		for e in g["events"]:
			lines.append("[%02d'] %s [color=#777]← %s[/color]" % [e["minute"], e["text"], "、".join(e["causes"])])
	feed.text = "\n".join(lines)


func _refresh() -> void:
	var w := session.world
	var c := session.club()
	var lg: League = w.leagues[c.league_id]
	var t: Array = ["[b]%s[/b]  %d 年  第 %d 天  階段：%s" % [c.name, w.year, w.day, w.phase],
		"現金 %d  聲望 %.0f  默契 %.0f" % [c.cash, c.reputation, c.chemistry], "", "[b]先發[/b]"]
	for role in Attr.ROLES:
		var p: Player = w.players.get(c.lineup.get(role, ""))
		if p:
			t.append("  %-8s %-12s 年齡 %d  士氣 %.0f  疲勞 %.0f  滿意度 %+.2f" % [role, p.handle, p.age(w.year), p.morale, p.fatigue, p.happiness])
	t.append("\n[b]%s 排名[/b]" % lg.name)
	var i := 1
	for cid in LeagueEngine.sorted_standings(lg):
		var st: Dictionary = lg.standings[cid]
		t.append("  %d. %-20s %d-%d" % [i, w.clubs[cid].name, st["w"], st["l"]])
		i += 1
	var open := w.inbox.filter(func(m): return not m.get("resolved", false))
	t.append("\n[b]收件匣（%d）[/b]" % open.size())
	for m in open.slice(0, 5):
		t.append("  • " + m["text"])
	info.text = "\n".join(t)
