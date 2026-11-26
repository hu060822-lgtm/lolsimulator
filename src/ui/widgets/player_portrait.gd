## 選手面譜：以選手 ID 為種子，從多組部件排列組合出一張平塗風格的大頭照。
##
## 部件（每種都有多個版本，組合數超過百萬）：
##   膚色 7、臉型 4、髮型 10、髮色 8、眉毛 4、眼睛 5、鼻子 3、嘴巴 5、
##   配件（電競耳機／眼鏡／耳環／無）、球衣領口 3（球衣用俱樂部代表色）。
## 國籍會影響膚色與髮色的機率（例如亞洲選手多為黑髮，偶爾染髮）。
## 同一位選手每次畫出來都一樣，換隊時只有球衣顏色會變。
class_name PlayerPortrait
extends RefCounted

const SKINS := [Color("f6d7bf"), Color("eec7a6"), Color("e2b48c"), Color("c99470"), Color("a8744f"), Color("7d5236"), Color("5a3a26")]
const HAIRS := [Color("17151a"), Color("2a1f1b"), Color("4a3222"), Color("7a5534"), Color("d9b46a"), Color("c9ccd6"), Color("b2453a"), Color("3d5bd1")]
const ASIA := ["韓國", "中國", "台灣", "日本", "越南", "香港", "泰國", "菲律賓", "馬來西亞", "新加坡"]


## 依選手決定所有部件。回傳的字典可以直接交給 draw()。
static func traits(p: Player) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("face:" + p.id).hash())
	var asia: bool = p.nationality in ASIA
	var skin := _pick_w(rng, [3, 5, 4, 1, 0, 0, 0] if asia else [3, 3, 2, 2, 2, 1, 1])
	var hair_col := _pick_w(rng, [12, 6, 2, 1, 1, 0, 1, 1] if asia else [3, 3, 3, 3, 3, 1, 1, 1])
	return {
		"skin": skin, "face": rng.randi_range(0, 3), "hair": _pick_w(rng, [4, 4, 3, 3, 3, 1, 3, 2, 1, 2]), "hair_col": hair_col,
		"brow": rng.randi_range(0, 3), "eye": rng.randi_range(0, 4), "nose": rng.randi_range(0, 2), "mouth": rng.randi_range(0, 4),
		"acc": _pick_w(rng, [4, 3, 2, 2]),   # 0 無 1 電競耳機 2 眼鏡 3 耳環
		"collar": rng.randi_range(0, 2),
		"age": p.age(2026),
	}


static func _pick_w(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0
	for x in weights:
		total += x
	var r := rng.randi_range(1, total)
	for i in weights.size():
		r -= weights[i]
		if r <= 0:
			return i
	return weights.size() - 1


## 在 rect 內畫出面譜（以 100×120 的單位座標設計，等比縮放、底部對齊）。
static func draw(ci: CanvasItem, rect: Rect2, t: Dictionary, team: Color) -> void:
	var s := minf(rect.size.x / 100.0, rect.size.y / 120.0)
	var o := rect.position + Vector2((rect.size.x - 100.0 * s) / 2.0, rect.size.y - 120.0 * s)
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var skin: Color = SKINS[t["skin"]]
	var shade := skin.darkened(0.16)
	var hair: Color = HAIRS[t["hair_col"]]
	var ink := Color("1d1a22")
	var hs: int = t["hair"]
	# 長髮的後半部畫在臉後面
	if hs in [5, 8]:
		_poly(ci, P, [[24, 40], [76, 40], [80, 92], [62, 98], [38, 98], [20, 92]], hair.darkened(0.12))
	# 球衣與肩膀
	_poly(ci, P, [[2, 120], [6, 104], [18, 94], [36, 88], [64, 88], [82, 94], [94, 104], [98, 120]], team)
	_poly(ci, P, [[2, 120], [6, 104], [18, 94], [24, 92], [16, 120]], team.darkened(0.25))
	_poly(ci, P, [[98, 120], [94, 104], [82, 94], [76, 92], [84, 120]], team.darkened(0.25))
	_poly(ci, P, [[30, 120], [36, 106], [64, 106], [70, 120]], team.lightened(0.12))
	# 脖子與領口
	_poly(ci, P, [[41, 74], [59, 74], [60, 92], [40, 92]], shade)
	match int(t["collar"]):
		0:
			_poly(ci, P, [[36, 88], [50, 104], [64, 88], [60, 88], [50, 98], [40, 88]], team.darkened(0.45))
		1:
			_poly(ci, P, [[36, 88], [42, 95], [58, 95], [64, 88], [60, 88], [56, 92], [44, 92], [40, 88]], team.darkened(0.45))
		_:
			_poly(ci, P, [[34, 86], [40, 96], [50, 90], [60, 96], [66, 86], [50, 84]], Color.WHITE.darkened(0.08))
	# 耳朵
	for ex: float in [27.0, 73.0]:
		_ell(ci, P, Vector2(ex, 55), 4.5, 7.0, shade)
	# 臉
	_ell(ci, P, Vector2(50, 50), 22.0, 25.0, skin)
	var jaw: Array = [[[30, 56], [70, 56], [64, 72], [50, 80], [36, 72]], [[29, 55], [71, 55], [67, 70], [50, 77], [33, 70]],
		[[29, 54], [71, 54], [70, 70], [58, 78], [42, 78], [30, 70]], [[30, 56], [70, 56], [65, 76], [50, 83], [35, 76]]][t["face"]]
	_poly(ci, P, jaw, skin)
	# 臉頰陰影（年紀大一點的比較明顯）
	var age_shade := clampf((float(t["age"]) - 22.0) / 10.0, 0.0, 1.0)
	if age_shade > 0.2:
		_poly(ci, P, [[34, 70], [38, 74], [50, 79], [62, 74], [66, 70], [50, 76]], Color(shade, 0.5 * age_shade))
	# 眉毛
	var by := 45.0
	for side: float in [-1.0, 1.0]:
		var cx := 50.0 + side * 9.5
		match int(t["brow"]):
			0:
				_poly(ci, P, [[cx - 5 * side, by + 1], [cx + 5 * side, by - 1], [cx + 5 * side, by + 1], [cx - 5 * side, by + 2.5]], hair.darkened(0.2))
			1:
				_poly(ci, P, [[cx - 5, by], [cx + 5, by], [cx + 5, by + 1.5], [cx - 5, by + 1.5]], hair.darkened(0.2))
			2:
				_poly(ci, P, [[cx - 5 * side, by + 2], [cx, by - 0.5], [cx + 5 * side, by + 0.5], [cx + 5 * side, by + 2], [cx, by + 1], [cx - 5 * side, by + 3.2]], hair.darkened(0.2))
			_:
				_poly(ci, P, [[cx - 5.5, by - 0.5], [cx + 5.5, by - 0.5], [cx + 5.5, by + 2.5], [cx - 5.5, by + 2.5]], hair.darkened(0.3))
	# 眼睛
	var ey := 54.0
	for side: float in [-1.0, 1.0]:
		var cx := 50.0 + side * 9.5
		match int(t["eye"]):
			0:
				_ell(ci, P, Vector2(cx, ey), 2.6, 2.6, ink)
			1:
				_ell(ci, P, Vector2(cx, ey), 3.4, 1.8, ink)
			2:
				_poly(ci, P, [[cx - 4, ey + 0.5], [cx, ey - 1.8], [cx + 4, ey + 0.5], [cx, ey + 1.2]], ink)
			3:
				_ell(ci, P, Vector2(cx, ey), 3.6, 2.4, Color.WHITE)
				_ell(ci, P, Vector2(cx + side * 0.4, ey), 1.9, 2.1, ink)
			_:
				_poly(ci, P, [[cx - 3.8, ey], [cx + 3.8, ey], [cx + 3.4, ey + 1.6], [cx - 3.4, ey + 1.6]], ink)
	# 鼻子
	match int(t["nose"]):
		0:
			_poly(ci, P, [[50, 57], [52.5, 65], [48.5, 65.5]], shade)
		1:
			_ell(ci, P, Vector2(50, 64), 3.0, 1.6, shade)
		_:
			_poly(ci, P, [[49, 58], [51, 58], [53, 65], [47, 65]], Color(shade, 0.8))
	# 嘴巴
	var mc := skin.darkened(0.45)
	match int(t["mouth"]):
		0:
			_poly(ci, P, [[44, 71], [56, 71], [56, 72.4], [44, 72.4]], mc)
		1:
			_arc(ci, P, Vector2(50, 67), 7.0, 0.35, PI - 0.35, mc, 1.6 * s)
		2:
			_poly(ci, P, [[44, 70.5], [56, 70.5], [53, 74.5], [47, 74.5]], Color("7a2e2e"))
			_poly(ci, P, [[45.5, 70.5], [54.5, 70.5], [54, 71.8], [46, 71.8]], Color.WHITE)
		3:
			_poly(ci, P, [[45, 72], [53, 70.5], [56, 71], [53, 72], [45, 73.2]], mc)
		_:
			_poly(ci, P, [[46, 71], [54, 71], [54, 72.2], [46, 72.2]], mc)
	# 前髮與高光
	_hair(ci, P, hs, hair)
	if hs in [1, 2, 3, 4, 5, 8, 9]:
		_poly(ci, P, [[38, 29], [48, 25], [56, 25.5], [46, 29.5]], Color(hair.lightened(0.35), 0.45))
	# 配件
	match int(t["acc"]):
		1:  # 電競耳機：頭帶 + 耳罩 + 麥克風
			_arc(ci, P, Vector2(50, 50), 27.0, PI + 0.25, TAU - 0.25, Color("26262e"), 4.0 * s)
			for ex: float in [25.0, 75.0]:
				_ell(ci, P, Vector2(ex, 56), 5.5, 9.0, Color("26262e"))
				_ell(ci, P, Vector2(ex, 56), 2.5, 5.0, team)
			ci.draw_line(P.call(26, 62), P.call(38, 74), Color("26262e"), 1.8 * s, true)
			_ell(ci, P, Vector2(39, 74.5), 2.2, 2.2, Color("26262e"))
		2:  # 眼鏡
			for side: float in [-1.0, 1.0]:
				var cx := 50.0 + side * 9.5
				var r := Rect2(P.call(cx - 6, 50), Vector2(12, 8) * s)
				ci.draw_rect(r, Color("2b2b33"), false, 1.4 * s)
			ci.draw_line(P.call(43.5, 53), P.call(56.5, 53), Color("2b2b33"), 1.2 * s)
		3:  # 耳環
			_ell(ci, P, Vector2(27, 63), 1.4, 1.4, Color("e9e2c8"))


static func _hair(ci: CanvasItem, P: Callable, style: int, c: Color) -> void:
	var d := c.darkened(0.18)
	match style:
		0:  # 短髮平頭
			_poly(ci, P, [[27, 46], [28, 34], [36, 26], [50, 23], [64, 26], [72, 34], [73, 46], [70, 38], [60, 34], [40, 34], [30, 38]], c)
		1:  # 韓系瀏海
			_poly(ci, P, [[26, 52], [26, 36], [34, 26], [50, 21], [66, 26], [74, 36], [74, 52], [70, 44], [66, 47], [60, 42], [54, 47], [48, 42], [42, 47], [36, 43], [30, 48]], c)
			_poly(ci, P, [[34, 26], [50, 21], [66, 26], [56, 25], [44, 25]], d)
		2:  # 旁分
			_poly(ci, P, [[26, 50], [26, 34], [36, 24], [52, 21], [66, 25], [74, 34], [74, 48], [70, 38], [56, 34], [44, 40], [34, 40], [30, 46]], c)
			_poly(ci, P, [[56, 34], [58, 24], [60, 34]], d)
		3:  # 蓬亂
			_poly(ci, P, [[25, 50], [24, 36], [30, 24], [38, 22], [42, 16], [50, 20], [58, 15], [62, 22], [70, 23], [76, 34], [75, 50], [70, 40], [64, 44], [60, 37], [52, 42], [46, 36], [40, 42], [34, 38], [30, 46]], c)
		4:  # 側剃（undercut）
			_poly(ci, P, [[28, 44], [28, 38], [72, 38], [72, 44], [70, 40], [30, 40]], d.darkened(0.2))
			_poly(ci, P, [[28, 38], [30, 26], [42, 18], [58, 17], [70, 24], [74, 36], [60, 32], [44, 34], [30, 38]], c)
		5:  # 長髮中分
			_poly(ci, P, [[24, 64], [24, 36], [34, 24], [50, 21], [66, 24], [76, 36], [76, 64], [70, 50], [64, 36], [52, 30], [50, 34], [48, 30], [36, 36], [30, 50]], c)
		6:  # 寸頭
			_poly(ci, P, [[28, 42], [29, 32], [38, 26], [50, 25], [62, 26], [71, 32], [72, 42], [66, 35], [50, 33], [34, 35]], Color(c, 0.85))
		7:  # 捲髮
			for i in 9:
				var a := PI + PI * i / 8.0
				_ell(ci, P, Vector2(50 + cos(a) * 22, 40 + sin(a) * 18), 6.5, 6.5, c)
			_poly(ci, P, [[30, 40], [70, 40], [66, 36], [34, 36]], c)
		8:  # 綁髮
			_poly(ci, P, [[26, 48], [26, 34], [36, 25], [50, 22], [64, 25], [74, 34], [74, 48], [68, 37], [50, 33], [32, 37]], c)
			_ell(ci, P, Vector2(50, 18), 6.0, 5.0, c)
		_:  # 刺蝟頭
			_poly(ci, P, [[27, 46], [26, 30], [32, 28], [30, 18], [40, 24], [44, 12], [50, 22], [58, 11], [61, 23], [70, 17], [69, 28], [75, 30], [73, 46], [68, 36], [50, 32], [32, 36]], c)


static func _poly(ci: CanvasItem, P: Callable, pts: Array, c: Color) -> void:
	var arr := PackedVector2Array()
	for q in pts:
		arr.append(P.call(float(q[0]), float(q[1])))
	ci.draw_colored_polygon(arr, c)


static func _ell(ci: CanvasItem, P: Callable, cpos: Vector2, rx: float, ry: float, c: Color) -> void:
	var arr := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		arr.append(P.call(cpos.x + cos(a) * rx, cpos.y + sin(a) * ry))
	ci.draw_colored_polygon(arr, c)


static func _arc(ci: CanvasItem, P: Callable, cpos: Vector2, r: float, a0: float, a1: float, c: Color, wdt: float) -> void:
	var arr := PackedVector2Array()
	for i in 17:
		var a := lerpf(a0, a1, i / 16.0)
		arr.append(P.call(cpos.x + cos(a) * r, cpos.y + sin(a) * r))
	ci.draw_polyline(arr, c, wdt, true)
