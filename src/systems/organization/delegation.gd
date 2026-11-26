## 委派：把重複的例行事項交給助理（經理助理）依預設方式處理。
##
## 只處理「例行」訊息：通知（知道了）、隨機事件（依事件的預設處理）、記者會（低調回應）、
## 隊友之間的小請求（加練、聚餐、帶新人）。轉會報價、選手不滿、加薪、衝突、董事會與財務危機
## 一定留給玩家決定。
class_name Delegation
extends RefCounted

const ROUTINE := ["event", "press", "duo_practice", "team_bonding", "mentor_talk"]


static func enabled(club: Club) -> bool:
	return club != null and bool(club.settings.get("delegate", false))


static func is_routine(m: Dictionary) -> bool:
	if m.get("resolved", false):
		return false
	var opts: Array = m.get("options", ["acknowledge"])
	if opts == ["acknowledge"]:
		return not (m.get("kind", "") in ["crisis", "board_warning", "board_takeover"])
	return m.get("kind", "") in ROUTINE


## 助理會選的選項。
static func choice(w: WorldState, m: Dictionary) -> String:
	var opts: Array = m.get("options", ["acknowledge"])
	match m.get("kind", ""):
		"event":
			var ev = RandomEvents.find_def(w, m.get("event_id", ""))
			var ai: String = "ev:" + str(ev.get("ai", ""))
			return ai if ai in opts else opts[0]
		"press":
			return "press:calm"
		"duo_practice":
			return "duo:approve"
		"mentor_talk":
			return "mentor:approve"
		"team_bonding":
			return "bond:fund" if w.human_club().cash > 0 else "bond:decline"
	return opts[0]


## 待委派的訊息（min_age：訊息至少放了幾天，給玩家先看的時間）。
static func pending(w: WorldState, min_age: int = 0) -> Array:
	return w.inbox.filter(func(m): return is_routine(m) and w.day - int(m.get("day", w.day)) >= min_age)
