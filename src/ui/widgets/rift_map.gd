## 召喚峽谷即時戰況地圖：英雄頭像小棋依比賽紀錄（MatchEngine.frames）每分鐘移動，
## 並標出擊殺、推塔、小龍與巴龍。地圖為程式繪製，頭像來自 ChampionIcons（下載失敗時顯示縮寫）。
class_name RiftMap
extends Control

signal minute_changed(minute: int)

const COL_GROUND := Color("1a3326")
const COL_JUNGLE := Color("12261b")
const COL_LANE := Color(0.62, 0.55, 0.38, 0.55)
const COL_RIVER := Color("24506b")
const COL_BLUE := Color("4f8cff")
const COL_RED := Color("ff5c5c")
const COL_DEAD := Color(0.4, 0.4, 0.45, 0.9)

var frames: Array = []
var champs: Dictionary = {}        ## side -> [champion id × 5]
var champ_db: Dictionary = {}      ## id -> Champion
var head: float = 0.0              ## 目前播放到的格（可為小數，用於平滑移動）
var target: float = 0.0
var sec_per_frame: float = 0.6
var _last_minute: int = -1


func _init() -> void:
	custom_minimum_size = Vector2(460, 460)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	ChampionIcons.instance().icon_ready.connect(func(_id): queue_redraw())


func set_game(f: Array, c: Dictionary, db: Dictionary) -> void:
	frames = f
	champs = c
	champ_db = db
	queue_redraw()


## 動畫播放到第 index 格。
func play_to(index: int) -> void:
	target = clampf(index, 0.0, maxf(frames.size() - 1, 0))
	set_process(true)


func jump_to(index: int) -> void:
	target = clampf(index, 0.0, maxf(frames.size() - 1, 0))
	head = target
	_emit_minute()
	queue_redraw()


func last_index() -> int:
	return maxi(frames.size() - 1, 0)


func current_minute() -> int:
	if frames.is_empty():
		return 0
	return int(frames[clampi(int(head), 0, frames.size() - 1)]["m"])


func _process(delta: float) -> void:
	if head < target:
		head = minf(target, head + delta / maxf(sec_per_frame, 0.02))
		_emit_minute()
		queue_redraw()
	else:
		set_process(false)


func _emit_minute() -> void:
	var m = current_minute()
	if m != _last_minute:
		_last_minute = m
		minute_changed.emit(m)


# ---------------------------------------------------------------- 繪製

func _area() -> Rect2:
	var s = minf(size.x, size.y)
	return Rect2((size.x - s) / 2.0, (size.y - s) / 2.0, s, s)


func _pt(r: Rect2, p) -> Vector2:
	var v: Vector2 = p if p is Vector2 else Vector2(float(p[0]), float(p[1]))
	return r.position + v * r.size.x


func _draw() -> void:
	var r = _area()
	var s = r.size.x
	draw_rect(r, COL_GROUND)
	# 野區（四塊較暗的林地）
	for poly in [
		[Vector2(0.17, 0.30), Vector2(0.40, 0.42), Vector2(0.30, 0.62), Vector2(0.15, 0.70)],
		[Vector2(0.38, 0.66), Vector2(0.62, 0.62), Vector2(0.70, 0.84), Vector2(0.30, 0.84)],
		[Vector2(0.83, 0.70), Vector2(0.60, 0.58), Vector2(0.70, 0.38), Vector2(0.85, 0.30)],
		[Vector2(0.62, 0.34), Vector2(0.38, 0.38), Vector2(0.30, 0.16), Vector2(0.70, 0.16)],
	]:
		draw_colored_polygon(PackedVector2Array(poly.map(func(p): return _pt(r, p))), COL_JUNGLE)
	# 河道
	var river := PackedVector2Array(RiftGeometry.RIVER.map(func(p): return _pt(r, p)))
	draw_polyline(river, COL_RIVER, s * 0.07, true)
	# 兵線
	for lane in RiftGeometry.LANE_PATHS:
		var pts := PackedVector2Array(RiftGeometry.LANE_PATHS[lane].map(func(p): return _pt(r, p)))
		draw_polyline(pts, COL_LANE, s * 0.034, true)
	# 主堡平台
	for side in ["blue", "red"]:
		var col = COL_BLUE if side == "blue" else COL_RED
		draw_circle(_pt(r, RiftGeometry.NEXUS[side]), s * 0.09, Color(col, 0.12))
		draw_circle(_pt(r, RiftGeometry.FOUNTAIN[side]), s * 0.03, Color(col, 0.35))
	# 小龍／巴龍坑
	draw_circle(_pt(r, RiftGeometry.DRAGON_PIT), s * 0.04, Color("3b2a1a"))
	draw_circle(_pt(r, RiftGeometry.BARON_PIT), s * 0.045, Color("2c1f3a"))
	var font = get_theme_default_font()
	_center_text(font, _pt(r, RiftGeometry.DRAGON_PIT), "龍", int(s * 0.03), Color("f5b83d"))
	_center_text(font, _pt(r, RiftGeometry.BARON_PIT), "巴", int(s * 0.03), Color("b48cff"))
	if frames.is_empty():
		return
	var i0 = clampi(int(floor(head)), 0, frames.size() - 1)
	var i1 = clampi(i0 + 1, 0, frames.size() - 1)
	var t = clampf(head - i0, 0.0, 1.0)
	var f0: Dictionary = frames[i0]
	var f1: Dictionary = frames[i1] if t > 0.0 else f0
	_draw_structures(r, f1 if t >= 0.5 else f0)
	_draw_marks(r, font)
	# 英雄小棋
	for side in ["blue", "red"]:
		var col = COL_BLUE if side == "blue" else COL_RED
		var p0: Array = f0["pos"][side]
		var p1: Array = f1["pos"][side]
		for k in p0.size():
			var a: Array = p0[k]
			var b: Array = p1[k] if k < p1.size() else a
			var alive_now: bool = int(b[2]) == 1 if t >= 0.5 else int(a[2]) == 1
			var pos: Vector2
			if int(a[2]) == 1 and int(b[2]) == 1:
				pos = _pt(r, a).lerp(_pt(r, b), _ease(t))
			else:
				pos = _pt(r, b if t >= 0.5 else a)
			var cid: String = champs.get(side, [])[k] if k < champs.get(side, []).size() else ""
			ChampToken.draw(self, pos, s * 0.033, champ_db.get(cid), col, alive_now, font)


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _draw_structures(r: Rect2, f: Dictionary) -> void:
	var s = r.size.x
	for side in ["blue", "red"]:
		var col = COL_BLUE if side == "blue" else COL_RED
		var st: Dictionary = f["st"][side]
		for lane in ["top", "mid", "bot"]:
			var lost := int(st.get(lane, 0))
			for i in 4:
				var p = _pt(r, RiftGeometry.tower_point(side, lane, i))
				var standing = i >= lost
				var sz = s * (0.016 if i < 3 else 0.022)
				if i == 3:  # 兵營
					draw_circle(p, sz, Color(col, 0.9) if standing else COL_DEAD.darkened(0.3))
				else:
					var rect = Rect2(p - Vector2(sz, sz), Vector2(sz, sz) * 2.0)
					draw_rect(rect, Color(col, 0.95) if standing else Color(0.25, 0.25, 0.28, 0.9))
					draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)
		var nt := int(st.get("nexus_towers", 0))
		for i in 2:
			var p = _pt(r, RiftGeometry.NEXUS_TOWERS[side][i])
			var sz = s * 0.014
			draw_rect(Rect2(p - Vector2(sz, sz), Vector2(sz, sz) * 2.0), Color(col, 0.95) if i >= nt else Color(0.25, 0.25, 0.28, 0.9))
		draw_circle(_pt(r, RiftGeometry.NEXUS[side]), s * 0.03, col.darkened(0.2))


## 最近 1.5 分鐘內的事件標記，越舊越淡。
func _draw_marks(r: Rect2, font: Font) -> void:
	var s = r.size.x
	var lo = maxi(int(floor(head - 1.5)), 0)
	var hi = mini(int(floor(head + 0.999)), frames.size() - 1)
	for i in range(lo, hi + 1):
		var age = head - i
		if age < -0.5:
			continue
		var alpha = clampf(1.0 - maxf(age, 0.0) / 1.5, 0.0, 1.0)
		for mk in frames[i]["marks"]:
			var col = COL_BLUE if mk["side"] == "blue" else COL_RED
			var p = _pt(r, mk["p"])
			match mk["t"]:
				"kill":
					var d = s * 0.018
					draw_line(p - Vector2(d, d), p + Vector2(d, d), Color(col, alpha), 3.0)
					draw_line(p - Vector2(d, -d), p + Vector2(d, -d), Color(col, alpha), 3.0)
				"tower", "nexus":
					draw_arc(p, s * (0.03 + (1.0 - alpha) * 0.03), 0, TAU, 24, Color(col, alpha), 3.0)
				_:
					draw_arc(p, s * (0.05 + (1.0 - alpha) * 0.04), 0, TAU, 32, Color(col, alpha), 4.0)
					var names = {"dragon": "小龍", "elder": "遠古龍", "baron": "巴龍", "grubs": "幼蟲", "herald": "預示者"}
					_center_text(font, p + Vector2(0, -s * 0.075), names.get(mk["t"], ""), int(s * 0.028), Color(col.lightened(0.3), alpha))


func _center_text(font: Font, p: Vector2, txt: String, fs: int, col: Color) -> void:
	if txt == "":
		return
	var w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, p + Vector2(-w / 2.0, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
