## 英雄小棋：圓形頭像 + 陣營色外框；沒有頭像時顯示英文名縮寫。
## 可直接當 Control 使用（BP 畫面、陣容列），也提供靜態 draw() 給地圖使用。
class_name ChampToken
extends Control

var champ: Champion
var ring: Color = Color("4f8cff")
var alive: bool = true


static func make(c: Champion, ring_color: Color, px: int = 40) -> ChampToken:
	var t := ChampToken.new()
	t.champ = c
	t.ring = ring_color
	t.custom_minimum_size = Vector2(px, px)
	if c:
		t.tooltip_text = UIKit.champion_info(c)
	return t


func _ready() -> void:
	ChampionIcons.instance().icon_ready.connect(func(id): if champ and id == champ.id: queue_redraw())


func _draw() -> void:
	var r = minf(size.x, size.y) / 2.0 - 1.0
	draw(self, size / 2.0, r, champ, ring, alive, get_theme_default_font())


static func initials(c: Champion) -> String:
	if c == null:
		return "?"
	var n = c.name_en if c.name_en != "" else c.id
	var parts = n.replace("'", "").replace(".", " ").replace("&", " ").split(" ", false)
	if parts.size() >= 2:
		return (parts[0].substr(0, 1) + parts[1].substr(0, 1)).to_upper()
	return n.substr(0, 2).capitalize()


static func draw(ci: CanvasItem, pos: Vector2, radius: float, c: Champion, ring_color: Color, is_alive: bool, font: Font) -> void:
	var tex: Texture2D = ChampionIcons.get_icon(c)
	ci.draw_circle(pos + Vector2(0, radius * 0.12), radius + 2.0, Color(0, 0, 0, 0.45))
	ci.draw_circle(pos, radius + 2.0, ring_color if is_alive else Color(0.35, 0.35, 0.4))
	if tex:
		var mod = Color.WHITE if is_alive else Color(0.35, 0.35, 0.35, 0.8)
		ci.draw_texture_rect(tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, mod)
	else:
		ci.draw_circle(pos, radius - 0.5, Color("1e222b") if is_alive else Color("15171c"))
		var fs = maxi(int(radius * 0.85), 8)
		var txt = initials(c)
		var w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, pos + Vector2(-w / 2.0, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if is_alive else Color(0.6, 0.6, 0.6))


## BP 用英雄卡：頭像 + 名稱 + 一行補充（熟練度、版本強弱）。
static func card(c: Champion, sub: String, ring_color: Color, cb: Callable, disabled: bool = false, w: int = 86) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, 96)
	b.disabled = disabled
	b.pressed.connect(cb)
	b.tooltip_text = UIKit.champion_info(c)
	var v := UIKit.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tok := make(c, ring_color if not disabled else Color(0.3, 0.3, 0.35), 46)
	tok.alive = not disabled
	tok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tok)
	for l in [UIKit.label(c.name, 13, UIKit.TEXT if not disabled else UIKit.MUTED), UIKit.label(sub, 11, UIKit.MUTED)]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	b.add_child(v)
	return b
