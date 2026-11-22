## 圓形徽章：俱樂部縮寫、選手位置、能力值等。用色塊取代文字說明。
class_name Badge
extends Control

var text: String = ""
var color: Color = Color("4f8cff")
var filled: bool = true
var font_scale: float = 0.36


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
	b.tooltip_text = UIKit.club_label(c)
	return b


func _draw() -> void:
	var r = minf(size.x, size.y) / 2.0
	var p = size / 2.0
	if filled:
		draw_circle(p, r, color.darkened(0.35))
		draw_arc(p, r - 1.5, 0, TAU, 48, color, 3.0, true)
	else:
		draw_arc(p, r - 1.5, 0, TAU, 48, color, 3.0, true)
	var font = get_theme_default_font()
	var fs = maxi(int(r * 2.0 * font_scale * (1.0 if text.length() <= 3 else 0.8)), 8)
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, p + Vector2(-w / 2.0, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
