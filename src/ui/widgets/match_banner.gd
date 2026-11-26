## 對戰橫幅：轉播畫面的開場包裝。兩隊代表色斜切對撞，中間放 VS，兩側是隊徽與大號縮寫。
## 只有一隊時（休賽季、無賽程）畫成單色的俱樂部橫幅。
class_name MatchBanner
extends Control

const CUT := 70.0          ## 斜切的水平位移

var left_club: Club
var right_club: Club
var left_sub: String = ""
var right_sub: String = ""
var center_text: String = "VS"
var center_caption: String = ""   ## VS 牌下方的小字（例：預估勝率）


static func make(a: Club, b: Club, a_sub: String, b_sub: String, h: int = 230) -> MatchBanner:
	var m := MatchBanner.new()
	m.left_club = a
	m.right_club = b
	m.left_sub = a_sub
	m.right_sub = b_sub
	m.custom_minimum_size = Vector2(0, h)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.resized.connect(m.queue_redraw)
	return m


func _draw() -> void:
	var w := size.x
	var h := size.y
	if right_club == null:
		_side(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), Badge.club_color(left_club.id), true)
		_team(left_club, left_sub, Vector2(40, h / 2.0), true)
		return
	var mid := w / 2.0
	var lc := Badge.club_color(left_club.id)
	var rc := Badge.club_color(right_club.id)
	_side(PackedVector2Array([Vector2(0, 0), Vector2(mid + CUT / 2.0 + 6, 0), Vector2(mid - CUT / 2.0 + 6, h), Vector2(0, h)]), lc, true)
	_side(PackedVector2Array([Vector2(mid + CUT / 2.0 - 6, 0), Vector2(w, 0), Vector2(w, h), Vector2(mid - CUT / 2.0 - 6, h)]), rc, false)
	var pad := 40.0 if h >= 150 else 24.0
	_team(left_club, left_sub, Vector2(pad, h / 2.0), true)
	_team(right_club, right_sub, Vector2(w - pad, h / 2.0), false)
	# 中央 VS 牌：夜幕藍的平行四邊形
	var f := UIKit.num_font()
	var fs := int(clampf(h * 0.2, 28.0, 46.0))
	var tw := f.get_string_size(center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pw := tw + 44.0
	var ph := fs * 1.4
	var c := Vector2(mid, h / 2.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-pw / 2 + 12, -ph / 2), c + Vector2(pw / 2 + 12, -ph / 2), c + Vector2(pw / 2 - 12, ph / 2), c + Vector2(-pw / 2 - 12, ph / 2)]), UIKit.BG)
	draw_string(f, Vector2(c.x - tw / 2.0, c.y + fs * 0.36), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.GOLD_LIGHT)
	if center_caption != "":
		var bf := UIKit.head_font()
		var cw := bf.get_string_size(center_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var cy := c.y + ph / 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - cw / 2 - 10, cy), Vector2(c.x + cw / 2 + 4, cy), Vector2(c.x + cw / 2 - 2, cy + 24), Vector2(c.x - cw / 2 - 16, cy + 24)]), UIKit.GOLD)
		draw_string(bf, Vector2(c.x - cw / 2 - 6, cy + 18), center_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIKit.INK)


## 一側的色塊：由深到亮的水平漸層（靠中間較亮）。
func _side(pts: PackedVector2Array, col: Color, left: bool) -> void:
	var cols := PackedColorArray()
	var xs: Array = Array(pts).map(func(p): return p.x)
	var x0: float = xs.min()
	var x1: float = xs.max()
	for p in pts:
		var t := (p.x - x0) / maxf(1.0, x1 - x0)
		if not left:
			t = 1.0 - t
		cols.append(col.darkened(0.55).lerp(col, t))
	draw_polygon(pts, cols)


## 隊徽（白底盾牌、隊色縮寫）＋ 大號縮寫 ＋ 一行說明。
func _team(c: Club, sub: String, anchor: Vector2, left: bool) -> void:
	var col := Badge.club_color(c.id)
	var h := size.y
	var r := clampf(h * 0.235, 22.0, 54.0)
	var crest_x := anchor.x + r * 0.86 if left else anchor.x - r * 0.86
	var cp := Vector2(crest_x, anchor.y - 4)
	draw_colored_polygon(Badge._shield_points(cp, r), Color.WHITE)
	var f := UIKit.num_font()
	var cfs := int(r * 0.56)
	var cw := f.get_string_size(c.short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
	draw_string(f, Vector2(cp.x - cw / 2.0, cp.y + cfs * 0.2), c.short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, col.darkened(0.25))
	var big := int(clampf(h * 0.49, 40.0, 112.0))
	var bw := f.get_string_size(c.short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var tx := cp.x + r + 22.0 if left else cp.x - r - 22.0 - bw
	var base := anchor.y + big * (0.22 if sub != "" else 0.34)
	draw_string(f, Vector2(tx + 3, base + 4), c.short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(0, 0, 0, 0.25))
	draw_string(f, Vector2(tx, base), c.short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, big, UIKit.GOLD_LIGHT)
	var sf := UIKit.body_font()
	var sfs := 16 if h >= 150 else 13
	var sw := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
	var sx := tx if left else tx + bw - sw
	draw_string(sf, Vector2(sx, base + sfs * 2.1), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(1, 1, 1, 0.9))
