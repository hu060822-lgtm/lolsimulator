## 經濟差曲線：以玩家隊伍為正，領先時藍色、落後時紅色，0 軸為中線。
class_name GoldChart
extends Control

var curve: Array = []
var ours_blue: bool = true


func _draw() -> void:
	var r := Rect2(Vector2(36, 6), size - Vector2(44, 22))
	var font := get_theme_default_font()
	draw_rect(r, Color(1, 1, 1, 0.025))
	if curve.size() < 2:
		draw_string(font, r.position + Vector2(8, r.size.y / 2), "沒有經濟紀錄", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.MUTED)
		return
	var vals: Array = curve.map(func(g): return float(g) if ours_blue else -float(g))
	var peak := 2000.0
	for v in vals:
		peak = maxf(peak, absf(v))
	peak = ceilf(peak / 2000.0) * 2000.0
	var mid_y := r.position.y + r.size.y / 2.0
	# 格線與刻度
	for k in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		var y: float = mid_y - k * r.size.y / 2.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.16 if k == 0.0 else 0.06), 1.0)
		var txt: String = "%+dk" % int(k * peak / 1000.0) if k != 0.0 else "0"
		draw_string(font, Vector2(2, y + 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIKit.MUTED)
	var n := vals.size()
	var step := r.size.x / float(n - 1)
	for m in range(0, n, 5):
		var x: float = r.position.x + m * step
		draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 3), UIKit.MUTED, 1.0)
		draw_string(font, Vector2(x - 6, r.end.y + 14), str(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIKit.MUTED)
	# 面積：每一段依正負上色
	for i in range(n - 1):
		var x0 := r.position.x + i * step
		var x1 := x0 + step
		var y0: float = mid_y - vals[i] / peak * r.size.y / 2.0
		var y1: float = mid_y - vals[i + 1] / peak * r.size.y / 2.0
		var a: float = vals[i]
		var b: float = vals[i + 1]
		if (a > 0 and b < 0) or (a < 0 and b > 0):
			# 跨過 0 軸：拆成兩個三角形，各自上色
			var xc: float = x0 + step * a / (a - b)
			_fill([Vector2(x0, mid_y), Vector2(x0, y0), Vector2(xc, mid_y)], a)
			_fill([Vector2(xc, mid_y), Vector2(x1, y1), Vector2(x1, mid_y)], b)
		else:
			_fill([Vector2(x0, mid_y), Vector2(x0, y0), Vector2(x1, y1), Vector2(x1, mid_y)], a + b)
		draw_line(Vector2(x0, y0), Vector2(x1, y1), UIKit.BLUE_SIDE if a + b >= 0 else UIKit.RED_SIDE, 2.0, true)
	var last: float = vals[-1]
	var lp := Vector2(r.end.x, mid_y - last / peak * r.size.y / 2.0)
	draw_circle(lp, 3.5, UIKit.GOLD_LIGHT)


func _fill(pts: Array, sign_v: float) -> void:
	var poly := PackedVector2Array(pts)
	# 面積太小（兩點都貼著 0 軸）時跳過，避免三角化失敗
	var area := 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		area += p.x * q.y - q.x * p.y
	if absf(area) < 1.0:
		return
	var col: Color = UIKit.BLUE_SIDE if sign_v >= 0 else UIKit.RED_SIDE
	draw_colored_polygon(poly, Color(col, 0.22))
