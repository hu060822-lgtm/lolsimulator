## 圓形徽章：俱樂部縮寫、選手位置、能力值等。用色塊取代文字說明。
class_name Badge
extends Control

var text: String = ""
var color: Color = Color("4f8cff")
var filled: bool = true
var font_scale: float = 0.36
## 盾形（俱樂部隊徽）或圓形（能力值、位置）。
var shield: bool = false


static func make(t: String, c: Color, px: int = 48, is_filled: bool = true) -> Badge:
	var b := Badge.new()
	b.text = t
	b.color = c
	b.filled = is_filled
	b.custom_minimum_size = Vector2(px, px)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	return b


## 俱樂部代表色：由 id 推得，固定不變。
static func club_color(club_id: String) -> Color:
	var h = absi(club_id.hash()) % 360
	return Color.from_hsv(h / 360.0, 0.55, 0.78)


static func club(c, px: int = 48) -> Badge:
	if c == null:
		return make("?", Color("2a2f3a"), px)
	var b = make(c.short_name, club_color(c.id), px)
	b.shield = true
	b.font_scale = 0.3
	b.tooltip_text = UIKit.club_label(c)
	return b


func _draw() -> void:
	var r = minf(size.x, size.y) / 2.0
	var p = size / 2.0
	if shield:
		_draw_shield(p, r)
	elif filled:
		draw_circle(p, r, color.darkened(0.55))
		draw_circle(p, r * 0.82, color.darkened(0.3))
		draw_arc(p, r - 1.5, 0, TAU, 48, color.lightened(0.1), 2.5, true)
		draw_arc(p, r * 0.82, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.18), 1.5, true)
	else:
		draw_arc(p, r - 1.5, 0, TAU, 48, color, 3.0, true)
	var font = get_theme_default_font()
	var fs = maxi(int(r * 2.0 * font_scale * (1.0 if text.length() <= 3 else 0.8)), 8)
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty = p.y + fs * 0.36 - (r * 0.06 if shield else 0.0)
	draw_string(font, Vector2(p.x - w / 2.0 + 1, ty + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(p.x - w / 2.0, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## 盾形隊徽：外框金邊、上淡下深的漸層、中間一道斜光。
func _draw_shield(p: Vector2, r: float) -> void:
	var pts := _shield_points(p, r)
	draw_colored_polygon(pts, UIKit.GOLD_DIM)
	var inner := _shield_points(p, r - 3.0)
	var top := color.darkened(0.05)
	var bot := color.darkened(0.6)
	var cols := PackedColorArray()
	for q in inner:
		cols.append(top.lerp(bot, clampf((q.y - (p.y - r)) / (2.0 * r), 0.0, 1.0)))
	draw_polygon(inner, cols)
	var rim := pts.duplicate()
	rim.append(pts[0])
	draw_polyline(rim, UIKit.GOLD, 1.5, true)
	# 上半部的高光
	var hl := PackedVector2Array([p + Vector2(-r * 0.62, -r * 0.72), p + Vector2(r * 0.62, -r * 0.72), p + Vector2(r * 0.62, -r * 0.5), p + Vector2(-r * 0.62, -r * 0.2)])
	draw_colored_polygon(hl, Color(1, 1, 1, 0.08))


static func _shield_points(p: Vector2, r: float) -> PackedVector2Array:
	var w := r * 0.86
	var out := PackedVector2Array([p + Vector2(-w, -r * 0.82), p + Vector2(0, -r * 0.98), p + Vector2(w, -r * 0.82)])
	var n := 10
	for i in range(n + 1):
		var t := float(i) / n
		# 右側由直邊收成弧形，到底部尖端
		var a := lerpf(0.0, PI / 2.0, t)
		out.append(p + Vector2(w * cos(a), -r * 0.1 + r * 1.08 * sin(a)))
	for i in range(n - 1, -1, -1):
		var t := float(i) / n
		var a := lerpf(0.0, PI / 2.0, t)
		out.append(p + Vector2(-w * cos(a), -r * 0.1 + r * 1.08 * sin(a)))
	return out
