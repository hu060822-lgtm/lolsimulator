## 一場比賽中一支隊伍的完整「賽前狀態」快照。
## 比賽引擎只讀取 TeamContext，不直接碰 WorldState，因此可以獨立測試。
class_name TeamContext
extends RefCounted

var club_id: String = ""
var name: String = ""
var short_name: String = ""  ## 比賽文字使用縮寫
var staff_ratings: Dictionary = {}  ## 教練團綜合能力（主教練 + 專職員工）
var players: Dictionary = {}   ## role -> Player
var coach: Staff = null
var plan: String = "flexible"  ## 戰術方向（Tactics）
var aggression: float = 0.5    ## 0..1
var chemistry: float = 50.0
var draft_familiarity: float = 40.0
## 給 BP：強制選擇/禁用（玩家手動 BP 或測試用）
var forced_picks: Dictionary = {}  ## role -> champion_id
var forced_bans: Array = []
## 即時戰術模式（第四階段）掛鉤：分鐘 -> 姿態
var orders: Dictionary = {}


static func from_club(w: WorldState, club: Club) -> TeamContext:
	var t := TeamContext.new()
	t.club_id = club.id
	t.name = club.name
	t.short_name = club.short_name if club.short_name != "" else club.name
	for role in Attr.ROLES:
		var pid: String = club.lineup.get(role, "")
		if pid != "" and w.players.has(pid):
			t.players[role] = w.players[pid]
	t.coach = w.staff.get(club.coach_id)
	for k in ["tactical", "drafting", "adaptability", "man_management"]:
		t.staff_ratings[k] = StaffSystem.rating(w, club, k)
	t.plan = club.tactics.get("plan", "flexible")
	t.aggression = float(club.tactics.get("aggression", 0.5))
	t.chemistry = club.chemistry
	t.draft_familiarity = club.draft_familiarity
	return t


func coach_stat(s: String) -> float:
	if staff_ratings.has(s):
		return float(staff_ratings[s])
	return float(coach.get(s)) if coach else 40.0


func avg_skill(s: String) -> float:
	var vals = players.values().map(func(p): return p.skill(s))
	return MathX.mean(vals)


func avg_trait(t: String) -> float:
	var vals = players.values().map(func(p): return p.trait_value(t))
	return MathX.mean(vals)


## 禁選品質 0..1：教練 BP 能力、選手 禁選理解、隊伍 禁選演練熟悉度。
func draft_quality() -> float:
	return (coach_stat("drafting") * 0.55 + avg_skill("draft_iq") * 0.25 + draft_familiarity * 0.20) / 100.0


## 指揮品質 0..1：決定比賽中「看清局勢」的準確度。
func shotcall_quality() -> float:
	var best_caller := 0.0
	for p in players.values():
		best_caller = maxf(best_caller, p.skill("shotcalling") * 0.6 + p.skill("decision_making") * 0.4)
	return (best_caller * 0.55 + avg_skill("decision_making") * 0.25 + coach_stat("tactical") * 0.20) / 100.0


## 執行力 0..1：默契、溝通、團隊合作、教練戰術能力。
func execution() -> float:
	return (chemistry * 0.35 + avg_trait("communication") * 0.2 + avg_trait("teamwork") * 0.2 + coach_stat("tactical") * 0.25) / 100.0
