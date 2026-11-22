## 召喚峽谷即時戰況地圖：英雄頭像小棋依比賽紀錄（MatchEngine.frames）每分鐘移動，
## 並標出擊殺、推塔、小龍與巴龍。底圖為峽谷地圖圖片（assets/maps/summoners_rift.jpg，
## 可用 user://rift_map.png／.jpg 替換），找不到圖片時改用程式繪製。頭像來自 ChampionIcons。
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
var sec_per_frame: float = 2.4
var _paths: Dictionary = {}       ## "格:方:人" -> 沿路網的折線（快取）
var _last_minute: int = -1

const MAP_IMAGE := "res://assets/maps/summoners_rift.jpg"
static var _bg: Texture2D = null
static var _bg_tried := false


## 峽谷底圖：先找玩家自訂的 user://rift_map.*，再用內建圖片。環境變數 LOLSIM_MAP=off 可關閉。
static func background() -> Texture2D:
	if _bg_tried:
		return _bg
	_bg_tried = true
	if OS.get_environment("LOLSIM_MAP") == "off":
		return null
	for path in ["user://rift_map.png", "user://rift_map.jpg", "user://rift_map.webp"]:
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img and not img.is_empty():
				_bg = ImageTexture.create_from_image(img)
				return _bg
	if ResourceLoader.exists(MAP_IMAGE):
		_bg = load(MAP_IMAGE)
	elif FileAccess.file_exists(MAP_IMAGE):
		var img2 := Image.load_from_file(MAP_IMAGE)
		if img2 and not img2.is_empty():
			_bg = ImageTexture.create_from_image(img2)
	return _bg


func _init() -> void:
	custom_minimum_size = Vector2(460, 460)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	ChampionIcons.instance().icon_ready.connect(func(_id): queue_redraw())


func set_game(f: Array, c: Dictionary, db: Dictionary) -> void:
	frames = f
	champs = c
	champ_db = db
	_paths.clear()
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
	var bg = background()
	if bg:
		draw_texture_rect(bg, r, false)
		draw_rect(r, Color(0, 0, 0, 0.18))
	else:
		_draw_procedural(r)
	draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
	var font = get_theme_default_font()
	if not bg:
		_center_text(font, _pt(r, RiftGeometry.DRAGON_PIT), "龍", int(s * 0.03), Color("f5b83d"))
		_center_text(font, _pt(r, RiftGeometry.BARON_PIT), "巴", int(s * 0.03), Color("b48cff"))
	if frames.is_empty():
		return
	var i0 = clampi(int(floor(head)), 0, frames.size() - 1)
	var i1 = clampi(i0 + 1, 0, frames.size() - 1)
	var t = clampf(head - i0, 0.0, 1.0)
	var f0: Dictionary = frames[i0]
	var f1: Dictionary = frames[i1]
	_draw_structures(r, f1 if t >= 0.5 else f0, bg != null, _fallen_nexus(i1 if t >= 0.5 else i0))
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
			if int(a[2]) == 1 and int(b[2]) == 1 and i1 != i0:
				pos = _pt(r, RiftGeometry.along(_path(i0, side, k, a, b), _ease(t)))
			else:
				pos = _pt(r, b if t >= 0.5 else a)
			var cid: String = champs.get(side, [])[k] if k < champs.get(side, []).size() else ""
			ChampToken.draw(self, pos, s * 0.033, champ_db.get(cid), col, alive_now, font)


func _draw_procedural(r: Rect2) -> void:
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


## 兩格之間沿路網走的路徑；同一段路只計算一次。
func _path(i0: int, side: String, k: int, a: Array, b: Array) -> PackedVector2Array:
	var key = "%d:%s:%d" % [i0, side, k]
	if not _paths.has(key):
		_paths[key] = RiftGeometry.nav_path(Vector2(float(a[0]), float(a[1])), Vector2(float(b[0]), float(b[1])))
	return _paths[key]


## 起步與停下稍微放慢，中段等速前進。
func _ease(t: float) -> float:
	return lerpf(t, t * t * (3.0 - 2.0 * t), 0.5)


## 到第 idx 格為止主堡被摧毀的一方（沒有則為空字串）。
func _fallen_nexus(idx: int) -> String:
	for i in range(0, mini(idx, frames.size() - 1) + 1):
		for mk in frames[i]["marks"]:
			if mk["t"] == "nexus":
				return "red" if mk["side"] == "blue" else "blue"
	return ""


func _draw_structures(r: Rect2, f: Dictionary, on_image: bool = false, fallen: String = "") -> void:
	var s = r.size.x
	if on_image:
		_draw_structures_on_image(r, f, fallen)
		return
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


## 圖片底圖已畫出所有建築：存活的加上隊伍色圈，被摧毀的蓋上暗色與叉號。
func _draw_structures_on_image(r: Rect2, f: Dictionary, fallen: String) -> void:
	var s = r.size.x
	for side in ["blue", "red"]:
		var col = COL_BLUE if side == "blue" else COL_RED
		var st: Dictionary = f["st"][side]
		var spots: Array = []
		for lane in ["top", "mid", "bot"]:
			var lost := int(st.get(lane, 0))
			for i in 4:
				spots.append([RiftGeometry.tower_point(side, lane, i), i >= lost, s * (0.02 if i < 3 else 0.024)])
		var nt := int(st.get("nexus_towers", 0))
		for i in 2:
			spots.append([RiftGeometry.NEXUS_TOWERS[side][i], i >= nt, s * 0.018])
		spots.append([RiftGeometry.NEXUS[side], fallen != side, s * 0.036])
		for sp in spots:
			var p = _pt(r, sp[0])
			var rad: float = sp[2]
			if sp[1]:
				draw_arc(p, rad, 0, TAU, 24, Color(col, 0.95), 2.5)
			else:
				draw_circle(p, rad, Color(0.08, 0.08, 0.1, 0.78))
				var d = rad * 0.6
				draw_line(p - Vector2(d, d), p + Vector2(d, d), COL_DEAD, 2.5)
				draw_line(p - Vector2(d, -d), p + Vector2(d, -d), COL_DEAD, 2.5)


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
