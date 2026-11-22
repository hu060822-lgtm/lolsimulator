## 比賽轉播畫面：上方計分板、左側召喚峽谷戰況地圖、右側雙方陣容與重點事件。
## 一般觀戰與即時指揮共用：load() 載入資料（保留播放進度），play_to_end() 播到目前最後一分鐘。
class_name MatchCenter
extends VBoxContainer

signal reached_end

const SPEEDS := {"1x": 2.4, "2x": 1.2, "4x": 0.6}  ## 每遊戲分鐘的秒數
const BIG := ["teamfight", "baron", "elder", "end", "steal", "dragon", "order", "adapt", "split", "force_4v5"]
const TAGS := {"teamfight": "團戰", "baron": "巴龍", "elder": "遠古龍", "dragon": "小龍", "grubs": "幼蟲", "herald": "預示者", "end": "勝利",
	"steal": "搶龍", "structure": "推塔", "solo_kill": "單殺", "gank": "Gank", "lane_kill": "擊殺", "pick": "抓單", "counter_gank": "反蹲",
	"punished_mistake": "失誤", "mistake": "失誤", "gank_fail": "Gank", "invade": "反野", "invade_kill": "反野", "invade_punished": "反野",
	"order": "指令", "adapt": "調整", "split": "分推", "force_4v5": "團戰", "split_caught": "抓分推", "trade": "交換", "gank_punished": "反打"}

var session: GameSession
var data: Dictionary = {}
var ally: String = "blue"
var map: RiftMap
var score: Dictionary = {}       ## 計分板 Label
var gold_bar: ProgressBar
var rows: Dictionary = {}        ## side -> [[token, name_label, kda_label] × 5]
var feed: RichTextLabel
var action: VBoxContainer        ## 右側操作區（即時指揮的戰術按鈕）
var speed_btns: Dictionary = {}
var _at_end_emitted: bool = false


func setup(s: GameSession, ally_side: String) -> MatchCenter:
	session = s
	ally = ally_side
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scoreboard())
	var body := UIKit.hbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	map = RiftMap.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.size_flags_stretch_ratio = 1.3
	map.minute_changed.connect(_on_minute)
	var mp = UIKit.panel(map)
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp.size_flags_stretch_ratio = 1.3
	body.add_child(mp)
	var right := UIKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(330, 0)
	body.add_child(right)
	var teams := UIKit.hbox(6)
	teams.add_child(_team_rows("blue"))
	teams.add_child(_team_rows("red"))
	right.add_child(teams)
	action = UIKit.vbox(6)
	right.add_child(action)
	feed = UIKit.rich()
	feed.fit_content = true
	var fp = UIKit.panel(feed)
	fp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fp)
	var ctl := UIKit.hbox(6)
	ctl.add_child(UIKit.muted("播放速度"))
	for k in SPEEDS:
		var b := UIKit.chip(k, _set_speed.bind(k))
		speed_btns[k] = b
		ctl.add_child(b)
	right.add_child(ctl)
	_set_speed("1x")
	return self


func _scoreboard() -> PanelContainer:
	var h := UIKit.hbox(14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for side in ["blue", "red"]:
		var col = UIKit.BLUE_SIDE if side == "blue" else UIKit.RED_SIDE
		var team := UIKit.label("", 20, col)
		var kills := UIKit.label("0", 30, Color.WHITE)
		var stats := UIKit.label("", 14, UIKit.MUTED)
		score[side] = {"team": team, "kills": kills, "stats": stats}
	var clock := UIKit.label("00:00", 22, UIKit.WARN)
	score["clock"] = clock
	h.add_child(score["blue"]["stats"])
	h.add_child(score["blue"]["team"])
	h.add_child(score["blue"]["kills"])
	var mid := UIKit.vbox(2)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(clock)
	gold_bar = ProgressBar.new()
	gold_bar.custom_minimum_size = Vector2(180, 8)
	gold_bar.show_percentage = false
	gold_bar.min_value = 0
	gold_bar.max_value = 100
	gold_bar.value = 50
	var bg = UIKit._box(UIKit.RED_SIDE.darkened(0.2), UIKit.BORDER, 3)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	gold_bar.add_theme_stylebox_override("background", bg)
	var fill = UIKit._box(UIKit.BLUE_SIDE, UIKit.BLUE_SIDE, 3)
	gold_bar.add_theme_stylebox_override("fill", fill)
	gold_bar.tooltip_text = "經濟比例（藍 / 紅）"
	mid.add_child(gold_bar)
	score["gold"] = UIKit.label("", 13, UIKit.MUTED)
	score["gold"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(score["gold"])
	h.add_child(mid)
	h.add_child(score["red"]["kills"])
	h.add_child(score["red"]["team"])
	h.add_child(score["red"]["stats"])
	return UIKit.panel(h)


func _team_rows(side: String) -> PanelContainer:
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows[side] = []
	for i in 5:
		var r := UIKit.hbox(6)
		var tok := ChampToken.make(null, UIKit.BLUE_SIDE if side == "blue" else UIKit.RED_SIDE, 34)
		r.add_child(tok)
		var info := UIKit.vbox(0)
		var nm := UIKit.label("", 13)
		var kda := UIKit.label("", 12, UIKit.MUTED)
		info.add_child(nm)
		info.add_child(kda)
		r.add_child(info)
		v.add_child(r)
		rows[side].append([tok, nm, kda])
	var p = UIKit.panel(v)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _set_speed(k: String) -> void:
	for b in speed_btns:
		speed_btns[b].button_pressed = b == k
	if map:
		map.sec_per_frame = SPEEDS[k]


## 載入比賽資料（MatchEngine.snapshot() 或比賽結果）；播放進度保留。
func load(d: Dictionary) -> void:
	data = d
	_at_end_emitted = false
	var ww = session.world
	var champs: Dictionary = d.get("champs", {})
	map.set_game(d.get("frames", []), champs, ww.champions)
	var clubs = {"blue": d.get("blue_club", ""), "red": d.get("red_club", "")}
	for side in ["blue", "red"]:
		var c: Club = ww.clubs.get(clubs[side])
		score[side]["team"].text = c.short_name if c else side
		var players = _players_by_role(side)
		for i in 5:
			var cid: String = champs.get(side, [])[i] if i < champs.get(side, []).size() else ""
			var tok: ChampToken = rows[side][i][0]
			tok.champ = ww.champions.get(cid)
			tok.tooltip_text = UIKit.champion_info(tok.champ) if tok.champ else ""
			tok.queue_redraw()
			var p: Player = players[i]
			rows[side][i][1].text = "%s %s" % [UIKit.ROLE_SHORT[Attr.ROLES[i]], p.handle if p else "?"]
	_on_minute(map.current_minute())


func _players_by_role(side: String) -> Array:
	var out: Array = [null, null, null, null, null]
	var ww = session.world
	var club_id: String = data.get("blue_club" if side == "blue" else "red_club", "")
	# 比賽結果帶有 players；snapshot 則由 lineup 推得
	if data.has("players"):
		for pid in data["players"]:
			var s: Dictionary = data["players"][pid]
			if s["side"] == side:
				out[Attr.ROLES.find(s["role"])] = ww.players.get(pid)
		return out
	var club: Club = ww.clubs.get(club_id)
	if club:
		for i in 5:
			out[i] = ww.players.get(club.lineup.get(Attr.ROLES[i], ""))
	return out


func play_to_end() -> void:
	_at_end_emitted = false
	map.play_to(map.last_index())
	if map.head >= map.last_index():
		_check_end()


func skip_to_end() -> void:
	map.jump_to(map.last_index())
	_check_end()


func at_end() -> bool:
	return map.head >= map.last_index()


func _process(_d: float) -> void:
	_check_end()


func _check_end() -> void:
	if not _at_end_emitted and not data.is_empty() and map.head >= map.last_index():
		_at_end_emitted = true
		reached_end.emit()


func _on_minute(minute: int) -> void:
	var frames: Array = data.get("frames", [])
	if frames.is_empty():
		return
	var idx = clampi(map.current_index(), 0, frames.size() - 1)
	var f: Dictionary = frames[idx]
	score["clock"].text = "%02d:00" % minute
	var drag = {"blue": 0, "red": 0}
	var bar = {"blue": 0, "red": 0}
	for i in idx + 1:
		for mk in frames[i]["marks"]:
			if mk["t"] == "dragon":
				drag[mk["side"]] += 1
			elif mk["t"] == "baron":
				bar[mk["side"]] += 1
	for side in ["blue", "red"]:
		var enemy = "red" if side == "blue" else "blue"
		var st: Dictionary = f["st"][enemy]
		var towers = int(st["top"]) + int(st["mid"]) + int(st["bot"]) + int(st["nexus_towers"])
		var kda: Array = f.get("kda", {}).get(side, [])
		var k := 0
		for i in kda.size():
			k += int(kda[i][0])
			rows[side][i][2].text = "%d / %d / %d" % [int(kda[i][0]), int(kda[i][1]), int(kda[i][2])]
			var alive = int(f["pos"][side][i][2]) == 1
			rows[side][i][0].alive = alive
			rows[side][i][0].queue_redraw()
			rows[side][i][1].modulate = Color.WHITE if alive else Color(1, 1, 1, 0.45)
		score[side]["kills"].text = str(k)
		score[side]["stats"].text = "塔 %d　龍 %d　巴 %d" % [towers, drag[side], bar[side]]
	var gd := int(f.get("gd", 0))
	var share = clampf(0.5 + gd / 20000.0, 0.05, 0.95)
	gold_bar.value = share * 100.0
	var ours = gd if ally == "blue" else -gd
	score["gold"].text = "經濟 %s%.1fk" % ["+" if ours >= 0 else "", ours / 1000.0]
	score["gold"].add_theme_color_override("font_color", UIKit.GOOD if ours > 1500 else (UIKit.BAD if ours < -1500 else UIKit.MUTED))
	_render_feed(minute)


func _render_feed(minute: int) -> void:
	var lines: Array = []
	var evs: Array = data.get("events", [])
	var shown: Array = evs.filter(func(e): return int(e["minute"]) <= minute and e["type"] != "mistake" and e["type"] != "gank_fail")
	for e in shown.slice(maxi(shown.size() - 9, 0)):
		lines.append(event_line(e))
	lines.reverse()
	feed.text = "\n".join(lines)


## 精簡事件列：[時間] 標籤 文字；原因收進滑鼠提示。
func event_line(e: Dictionary) -> String:
	var side: String = e["sides"][0] if e["sides"].size() > 0 else ""
	var col = "#3d9bff" if side == "blue" else ("#ff5a6a" if side == "red" else "#8c95a4")
	var tag: String = TAGS.get(e["type"], "")
	var big = e["type"] in BIG
	var txt = "[color=#6b7280]%02d'[/color] [bgcolor=%s33][color=%s] %s [/color][/bgcolor] %s%s%s" % [int(e["minute"]), col, col, tag, "[b]" if big else "", e["text"], "[/b]" if big else ""]
	if e["causes"].size() > 0:
		txt = "[hint=%s]%s[/hint]" % ["、".join(e["causes"]).replace("]", ")").replace("[", "("), txt]
	return txt
