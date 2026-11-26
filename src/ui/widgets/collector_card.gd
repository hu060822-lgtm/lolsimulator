## 選手收藏卡：依能力分卡框等級（銀、金、紫、青），卡面有能力值、位置、剪影、ID 與四項關鍵能力。
## 整張卡是按鈕；選取時外圈亮黃。對手選手的能力未知時顯示「?」與球探估計值。
class_name CollectorCard
extends Button

const TIERS := [
	# [最低能力, 名稱, 卡框亮色, 卡框暗色, 卡面底色]
	[82.0, "王牌", Color("7fe8d0"), Color("0c5e4e"), Color("1f3430")],
	[75.0, "菁英", Color("bba6ff"), Color("3e2a8c"), Color("2a2440")],
	[65.0, "主力", Color("f2c94c"), Color("8c6a1c"), Color("2e2a20")],
	[0.0, "新秀", Color("d5dbe6"), Color("5f6672"), Color("2b2e35")],
]
## 各位置卡面上的四項能力
const KEY_SKILLS := {
	"TOP": ["mechanics", "laning", "teamfighting", "wave_management"],
	"JUNGLE": ["mechanics", "map_awareness", "decision_making", "teamfighting"],
	"MID": ["mechanics", "laning", "teamfighting", "map_awareness"],
	"ADC": ["mechanics", "laning", "positioning", "teamfighting"],
	"SUPPORT": ["vision", "shotcalling", "map_awareness", "teamfighting"],
}
const SHORT := {"mechanics": "操作", "laning": "對線", "teamfighting": "團戰", "wave_management": "兵線", "map_awareness": "地圖", "decision_making": "決策",
	"positioning": "站位", "vision": "視野", "shotcalling": "指揮"}

var player: Player
var role: String = ""
var ovr: float = 0.0
var known: bool = true
var stats: Array = []          ## [[名稱, 數值], …]
var club_color: Color = UIKit.MUTED
var tag_text: String = ""      ## 右上角小標籤（先發、要求離隊…）
var tag_color: Color = UIKit.GOLD
var morale: float = -1.0       ## >= 0 時在卡底畫士氣格
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()


static func make(session: GameSession, p: Player, w: int = 168, r: String = "") -> CollectorCard:
	var c := CollectorCard.new()
	var ww := session.world
	c.player = p
	c.role = r if r != "" else p.primary_role
	c.known = p.club_id == ww.human_club_id
	c.ovr = p.current_ability(c.role)
	var club: Club = ww.clubs.get(p.club_id)
	c.club_color = Badge.club_color(club.id) if club else UIKit.MUTED
	for s in KEY_SKILLS.get(c.role, KEY_SKILLS["MID"]):
		var v: float = p.skill(s)
		if not c.known:
			var rg = Scouting.range_of(ww, p, s)
			v = (rg[0] + rg[1]) / 2.0
		c.stats.append([SHORT[s], v])
	if not c.known:
		var lo := 0.0
		for st in c.stats:
			lo += st[1]
		c.ovr = lo / c.stats.size()
	c.custom_minimum_size = Vector2(w, roundi(w * 1.4))
	c.focus_mode = Control.FOCUS_NONE
	c.tooltip_text = "%s・%s・%d 歲" % [p.handle, UIKit.ROLE_NAMES.get(c.role, c.role), p.age(ww.year)]
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		c.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	c.mouse_entered.connect(c.queue_redraw)
	c.mouse_exited.connect(c.queue_redraw)
	c.resized.connect(c.queue_redraw)
	return c


static func tier_of(v: float) -> Array:
	for t in TIERS:
		if v >= t[0]:
			return t
	return TIERS[-1]


func _draw() -> void:
	var w := size.x
	var h := size.y
	var k := w / 168.0
	var t: Array = tier_of(ovr) if known else TIERS[-1]
	var hi: Color = t[2]
	var lo: Color = t[3]
	var face: Color = t[4]
	# 外框：選取時黃、滑過時亮
	if selected:
		draw_rect(Rect2(Vector2(-4, -4), size + Vector2(8, 8)), UIKit.GOLD)
	var frame := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h - 16 * k), Vector2(w - 16 * k, h), Vector2(0, h)])
	draw_polygon(frame, PackedColorArray([hi, hi.lerp(lo, 0.5), lo, lo, hi.lerp(lo, 0.7)]))
	var m := 3.0 * k
	var inner := PackedVector2Array([Vector2(m, m), Vector2(w - m, m), Vector2(w - m, h - 16 * k - m * 0.4), Vector2(w - 16 * k - m * 0.4, h - m), Vector2(m, h - m)])
	var face_top := face.lightened(0.06 if is_hovered() else 0.0)
	draw_polygon(inner, PackedColorArray([face_top, face_top, face.darkened(0.35), face.darkened(0.4), face.darkened(0.35)]))
	# 剪影（俱樂部代表色淡淡打底）
	var sil_c := Color(club_color.lerp(Color("4a4f5c"), 0.55), 0.95)
	var cx := w * 0.66
	draw_circle(Vector2(cx, 66 * k), 22 * k, sil_c)
	var body := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		body.append(Vector2(cx + cos(a) * 48 * k, 132 * k + sin(a) * 42 * k))
	draw_colored_polygon(body, sil_c)
	draw_rect(Rect2(Vector2(m, 132 * k), Vector2(w - 2 * m, 4 * k)), Color(face.darkened(0.2), 1.0))
	# 能力值與位置
	var nf := UIKit.num_font()
	var big := int(46 * k)
	draw_string(nf, Vector2(12 * k, 50 * k), str(int(round(ovr))) if known else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, big, UIKit.GOLD_LIGHT)
	var cf := UIKit.cond_font()
	draw_string(cf, Vector2(13 * k, 72 * k), UIKit.ROLE_SHORT.get(role, role), HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * k), hi)
	draw_string(cf, Vector2(13 * k, 90 * k), t[1] if known else "未知", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), Color(hi, 0.75))
	# 右上小標籤
	if tag_text != "":
		var bf := UIKit.head_font()
		var fs := int(11 * k)
		var tw := bf.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(Vector2(w - tw - 16 * k, 8 * k), Vector2(tw + 10 * k, 18 * k))
		draw_rect(r, tag_color)
		draw_string(bf, r.position + Vector2(5 * k, 13.5 * k), tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.INK)
	# ID
	var name_y := 158 * k
	var nfs := int(26 * k)
	var name := player.handle
	while name.length() > 3 and nf.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > w - 24 * k:
		nfs -= 1
	draw_string(nf, Vector2(12 * k, name_y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, UIKit.GOLD_LIGHT)
	draw_line(Vector2(12 * k, name_y + 8 * k), Vector2(w - 12 * k, name_y + 8 * k), Color(1, 1, 1, 0.14), 1.0)
	# 四項能力：兩欄
	var bf2 := UIKit.body_font()
	for i in stats.size():
		var col := i % 2
		var row := i / 2
		var x := 12 * k + col * (w - 24 * k) / 2.0
		var y := name_y + 28 * k + row * 22 * k
		var val: float = stats[i][1]
		var vt := ("%d" % roundi(val)) if known else ("~%d" % roundi(val))
		draw_string(cf, Vector2(x, y), vt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * k), UIKit.GOLD_LIGHT if known else UIKit.MUTED)
		var vw := cf.get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * k)).x
		draw_string(bf2, Vector2(x + vw + 6 * k, y - 1), stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), UIKit.MUTED)
	# 士氣格
	if morale >= 0.0:
		var lit := clampi(roundi(morale / 20.0), 0, 5)
		var seg := (w - 24 * k - 4 * 4 * k) / 5.0
		for i in 5:
			draw_rect(Rect2(Vector2(12 * k + i * (seg + 4 * k), h - 15 * k), Vector2(seg, 4 * k)), UIKit.GOLD if i < lit else Color(1, 1, 1, 0.12))
