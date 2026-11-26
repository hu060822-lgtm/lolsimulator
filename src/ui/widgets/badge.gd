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
	return Color.from_hsv(h / 360.0, 0.72, 0.8)


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
		# 平面色塊：外圈主色、內圈加深，不加描邊與高光
		draw_circle(p, r, color.darkened(0.15))
		draw_circle(p, r * 0.84, color.darkened(0.45))
	else:
		draw_arc(p, r - 1.5, 0, TAU, 48, color, 3.0, true)
	var font: Font = UIKit.num_font()
	var fs = maxi(int(r * 2.0 * (font_scale + 0.1) * (1.0 if text.length() <= 3 else 0.8)), 8)
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty = p.y + fs * 0.34 - (r * 0.1 if shield else 0.0)
	draw_string(font, Vector2(p.x - w / 2.0, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## 盾形隊徽：方肩、尖底的五邊形，平塗俱樂部代表色。
func _draw_shield(p: Vector2, r: float) -> void:
	draw_colored_polygon(_shield_points(p, r), color)
	draw_colored_polygon(_shield_points(p, r * 0.8), color.darkened(0.12))


static func _shield_points(p: Vector2, r: float) -> PackedVector2Array:
	var w := r * 0.86
	return PackedVector2Array([p + Vector2(-w, -r * 0.92), p + Vector2(w, -r * 0.92), p + Vector2(w, r * 0.35), p + Vector2(0, r), p + Vector2(-w, r * 0.35)])
