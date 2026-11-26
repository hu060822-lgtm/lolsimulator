## 選手風格標籤：看選手「相對自己最突出」的能力，給一個好記的稱號（操作怪物、地圖大師…）。
## 只是解讀既有能力，不改變數值；讓同樣 75 分的兩名選手一眼看出差在哪裡。
class_name PlayerArchetype
extends RefCounted

## 能力 -> [稱號, 說明]
const BY_SKILL := {
	"mechanics": ["操作怪物", "手速與操作是招牌，能打出別人打不出的細節"],
	"laning": ["對線殺手", "前期對線壓制力強，常常幫隊伍打開局面"],
	"map_awareness": ["地圖大師", "總是知道對手在哪，支援與反蹲時機精準"],
	"positioning": ["站位專家", "團戰中很少被抓到，輸出環境穩定"],
	"teamfighting": ["團戰核心", "大型團戰的表現比平常更好"],
	"decision_making": ["決策大腦", "判斷什麼時候該打、什麼時候該退"],
	"adaptability": ["版本變色龍", "改版之後適應得比誰都快"],
	"consistency": ["穩定器", "不常爆發，但幾乎不會失常"],
	"clutch": ["大賽型", "比分越緊張，表現越好"],
	"wave_management": ["運營大師", "兵線處理細膩，靠運營慢慢拉開差距"],
	"resource_trading": ["資源交換家", "擅長用一條龍換一座塔的交易"],
	"vision": ["視野之眼", "視野布置與排眼讓隊友安心"],
	"shotcalling": ["指揮官", "比賽中的聲音，帶著隊伍做決定"],
	"draft_iq": ["BP 智囊", "懂版本、懂克制，是 BP 時的好幫手"],
}
const DEEP_POOL := ["英雄池深", "能玩的英雄很多，對手很難靠 Ban 針對他"]
const ALL_ROUND := ["全能型", "沒有明顯弱點，也沒有特別突出的一項"]


## 回傳 {name, desc, skill}。
static func of(p: Player) -> Dictionary:
	var avg := 0.0
	for s in Attr.SKILLS:
		avg += p.skill(s)
	avg /= Attr.SKILLS.size()
	var best := ""
	var best_d := -INF
	for s in Attr.SKILLS:
		var d := p.skill(s) - avg
		if d > best_d:
			best_d = d
			best = s
	var deep := 0
	for c in p.champion_pool:
		if float(p.champion_pool[c]) >= 70.0:
			deep += 1
	if deep >= 10 and best_d < 10.0:
		return {"name": DEEP_POOL[0], "desc": DEEP_POOL[1], "skill": ""}
	if best_d < 5.0:
		return {"name": ALL_ROUND[0], "desc": ALL_ROUND[1], "skill": ""}
	var e: Array = BY_SKILL[best]
	return {"name": e[0], "desc": e[1], "skill": best}
