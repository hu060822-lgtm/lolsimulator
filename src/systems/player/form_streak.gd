## 選手手感：連續好表現會「打出手感」，連續低迷會「手感冰冷」。
##
## - Player.hot（-1..1）：每打完一個系列賽依平均評分更新，舊手感保留 60%。每週再往 0 回歸一點。
## - 比賽中每局狀態加上 hot × HOT_WEIGHT（最多約 ±6%）。賽前情報與選手卡看得到誰手感火燙、誰低迷。
## - 系列賽氣勢：贏下一局的一方下一局全員狀態 +MOMENTUM（輸的一方原本就有心態下滑）。
## - 讓「要不要把低迷的先發換下來」成為真正的決定，也讓手感正熱的弱隊有機會爆冷。
class_name FormStreak
extends RefCounted

const HOT_WEIGHT := 0.06
const MOMENTUM := 0.02
const KEEP := 0.6
const PER_POINT := 0.25   ## 平均評分每高於 6.5 一分，手感 +0.25
const WEEKLY_DECAY := 0.9
const LABEL_AT := 0.4


static func after_series(w: WorldState, series: Dictionary) -> void:
	var sums := {}
	var counts := {}
	for g in series["games"]:
		for pid in g["players"]:
			sums[pid] = float(sums.get(pid, 0.0)) + float(g["players"][pid]["rating"])
			counts[pid] = int(counts.get(pid, 0)) + 1
	for pid in sums:
		var p: Player = w.players.get(pid)
		if p == null:
			continue
		var avg: float = sums[pid] / counts[pid]
		var before := p.hot
		p.hot = clampf(p.hot * KEEP + (avg - 6.5) * PER_POINT, -1.0, 1.0)
		var club: Club = w.clubs.get(p.club_id)
		if club == null or not club.lineup.values().has(pid):
			continue
		if before < 0.6 and p.hot >= 0.6 and (club.is_human or p.reputation >= 60.0):
			Media.post(w, "streak", "%s 手感火燙，最近幾場表現無人能擋" % p.handle, [p.id, club.id], 0.5)
		elif before > -0.6 and p.hot <= -0.6 and (club.is_human or p.reputation >= 60.0):
			Media.post(w, "slump", "%s 陷入低潮，%s 該不該讓他先休息？" % [p.handle, club.short_name], [p.id, club.id], -0.4)


static func weekly(p: Player) -> void:
	p.hot *= WEEKLY_DECAY


## 給介面：手感文字（沒有明顯手感時回傳空字串）。
static func label(p: Player) -> String:
	if p.hot >= 0.7:
		return "手感火燙"
	if p.hot >= LABEL_AT:
		return "手感不錯"
	if p.hot <= -0.7:
		return "手感冰冷"
	if p.hot <= -LABEL_AT:
		return "低迷"
	return ""


static func color_good(p: Player) -> bool:
	return p.hot > 0.0
