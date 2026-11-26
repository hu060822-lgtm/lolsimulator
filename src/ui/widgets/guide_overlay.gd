## 新手引導與說明：半透明遮罩上的一張說明卡。第一次開局自動出現；之後按「?」或 F1 打開，內容依目前頁面而定。
class_name GuideOverlay
extends CanvasLayer

const WELCOME := [
	["你是總教練", "每一季董事會會開出三個目標（總覽頁下方）。達成越多，董事會越信任你；信心太低會被開除。"],
	["推進時間", "右上角「繼續」會一路推進到下一場比賽；「推進一週」只走七天。比賽日會先進入賽前情報。"],
	["賽前情報", "看對手的招牌打法、手感與版本答案，挑一個剋制對手的打法。可以親自 BP 指揮，也可以交給教練團快速模擬。"],
	["版本研究", "每隔幾週就會改版。在「訓練」排「版本研究」時段，比對手更快吃透版本答案。"],
	["名單與轉會", "選手卡上有能力、風格與手感。好選手會有 AI 球隊來搶，收件匣會讓你決定要不要加價。"],
]
const SHORTCUTS := "快捷鍵：空白鍵 繼續・W 推進一週・1～9 切換頁面・F1 或 ? 說明・Esc 關閉"
const PAGE_TIPS := {
	"dashboard": ["總覽", "上方是下一場比賽，中間是先發收藏卡（格數是士氣、▲▼是手感），下方是收件匣、媒體、本季目標與宿敵。"],
	"roster": ["名單", "卡片牆可以切換成表格。點選手看詳細資料；合約快到期的選手記得續約，低迷的先發可以考慮換人。"],
	"tactics": ["戰術與陣容", "打法會互相剋制。打「版本答案」打法，且版本研究越深，戰力加成越大。"],
	"training": ["訓練", "每週 12 個時段。負荷太高會累積疲勞；「版本研究」讓你更快吃透新版本；休息不足會影響比賽狀態。"],
	"transfers": ["轉會中心", "選手只在休賽季轉會窗口簽約。被拒絕時看經紀人回價；好選手可能引來搶人大戰。"],
	"staff": ["教練團", "分析師影響 BP 品質與版本研究速度，球探影響看人的準確度（包括青訓試訓的潛力估計）。"],
	"finance": ["財務", "薪資不要超過預算。贊助合約每年續約，品牌越好報價越高。"],
	"competition": ["賽事", "積分榜、賽程與季後賽對戰表。國際賽名額看例行賽與季後賽成績。"],
	"inbox": ["收件匣", "需要你決定的事會標成「需決策」。例行事項可以勾選交給助理自動處理。"],
	"news": ["媒體", "外界對球隊的評價會影響品牌與選手心情。"],
	"history": ["歷史", "歷屆冠軍、名人堂與俱樂部傳奇。"],
	"saves": ["存檔與設定", "三個手動存檔槽，另有每週自動存檔；也可以設定比賽日自動交給教練團。"],
	"prep": ["賽前情報", "勝率因素告訴你優勢在哪。照分析師建議改打剋制打法、改打版本答案，或把低迷的選手換下。"],
	"draft": ["BP 與比賽", "BP 時注意被研究過的英雄與秘密武器。比賽中會出現關鍵抉擇卡，每個選項的風險不同。"],
}

var card: PanelContainer


static func open(parent: Node, page_id: String, welcome: bool) -> GuideOverlay:
	var g := GuideOverlay.new()
	g.layer = 50
	parent.add_child(g)
	g._build(page_id, welcome)
	return g


func _build(page_id: String, welcome: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	card = PanelContainer.new()
	var sb := UIKit._card(UIKit.PANEL, 0)
	sb.border_width_top = 4
	sb.border_color = UIKit.GOLD
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(680, 0)
	center.add_child(card)
	var v := UIKit.vbox(12)
	card.add_child(v)
	if welcome:
		v.add_child(UIKit.bold("歡迎上任", 30, UIKit.GOLD))
		var i := 0
		for step in WELCOME:
			i += 1
			var row := UIKit.hbox(14)
			var n := UIKit.big_num(str(i), 30, UIKit.GOLD)
			n.custom_minimum_size = Vector2(26, 0)
			n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(n)
			row.add_child(_tip(step[0], step[1]))
			v.add_child(row)
	else:
		var t: Array = PAGE_TIPS.get(page_id, PAGE_TIPS["dashboard"])
		v.add_child(UIKit.bold("說明", 28, UIKit.GOLD))
		v.add_child(_tip(t[0], t[1]))
	var sc := UIKit.label(SHORTCUTS, 13, UIKit.MUTED)
	sc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sc)
	var ok := UIKit.primary("開始" if welcome else "知道了", close)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(ok)


func _tip(head: String, text: String) -> Control:
	var tv := UIKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.bold(head, 17))
	var l := UIKit.label(text, 15, UIKit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	tv.add_child(l)
	return tv


func close() -> void:
	queue_free()
