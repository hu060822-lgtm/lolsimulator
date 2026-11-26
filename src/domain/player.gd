## 選手：具有能力、個性、職業目標與自主行為狀態的角色，而不是數值資產。
class_name Player
extends RefCounted

var id: String
var handle: String           ## 遊戲 ID
var real_name: String
var nationality: String
var home_region: String
var birth_year: int
var primary_role: String
var secondary_roles: Array = []

var skills: Dictionary = {}       ## Attr.SKILLS -> 1..100（真實值，玩家不可直接看見）
var ceilings: Dictionary = {}     ## 每項能力的隱藏上限（潛力在能力層級的展開）
var personality: Dictionary = {}  ## Attr.PERSONALITY -> 1..100
var potential: float = 60.0       ## Potential Ability（隱藏）
var development_rate: float = 1.0 ## 0.5..1.6
var peak_age: int = 22
var decline_rate: float = 1.0

var champion_pool: Dictionary = {} ## champion_id -> mastery 0..100

## 動態狀態（0..100，form 為 -1..1）
var morale: float = 60.0
var confidence: float = 60.0
var stress: float = 25.0
var fatigue: float = 15.0
var motivation: float = 70.0

## 生涯與自主行為
var club_id: String = ""
var contract: Contract = null
var squad_status: String = "rotation"
var goals: Array = []                 ## 例如 ["WIN_TITLES", "PLAYING_TIME"]
var happiness: float = 0.2            ## -1..1，指數移動平均
var satisfaction: Dictionary = {}     ## 各面向 -1..1（最近一次評估）
var trust_in_management: float = 50.0
var weeks_unhappy: int = 0
var transfer_requested: bool = false
var refuses_renewal: bool = false
var promises: Array = []              ## [{type, made_day, due_day, kept}]
var retired: bool = false
var suspended_until: int = -1        ## 禁賽／簽證等因素無法出賽到這一天（含）
var retired_year: int = 0

## 數據
var season_stats: Dictionary = {}
var career: Dictionary = {"games": 0, "wins": 0, "kills": 0, "deaths": 0, "assists": 0, "titles": 0, "mvps": 0, "rating_sum": 0.0}
var history: Array = []               ## [{year, club_id, games, wins, avg_rating}]
var loan: Dictionary = {}             ## 租借中：{from, to, until, wage_share, fee}
var reputation: float = 20.0          ## 知名度 0..100
var hot: float = 0.0                  ## 手感 -1..1（連續好表現變熱、連續低迷變冷，見 FormStreak）


func age(current_year: int) -> int:
	return current_year - birth_year


func skill(s: String) -> float:
	return float(skills.get(s, 40.0))


func trait_value(t: String) -> float:
	return float(personality.get(t, 50.0))


func mastery(champ_id: String) -> float:
	return float(champion_pool.get(champ_id, 0.0))


## 目前能力（Current Ability）：位置加權平均。只供估值與 AI 評估，不決定比賽勝負。
func current_ability(role: String = "") -> float:
	var r = role if role != "" else primary_role
	var weights: Dictionary = Attr.ROLE_WEIGHTS.get(r, {})
	var total := 0.0
	var wsum := 0.0
	for s in Attr.SKILLS:
		var w: float = weights.get(s, 0.4)
		total += skill(s) * w
		wsum += w
	var role_penalty = 1.0 if r == primary_role else (0.9 if r in secondary_roles else 0.7)
	return total / wsum * role_penalty


func top_champions(n: int = 5) -> Array:
	var ids = champion_pool.keys()
	ids.sort_custom(func(a, b): return champion_pool[a] > champion_pool[b])
	return ids.slice(0, n)


func reset_season_stats() -> void:
	season_stats = {"games": 0, "wins": 0, "kills": 0, "deaths": 0, "assists": 0, "rating_sum": 0.0, "starts": 0, "team_games": 0}


func is_available(day: int) -> bool:
	return not retired and suspended_until < day


func avg_season_rating() -> float:
	var g: int = season_stats.get("games", 0)
	return season_stats.get("rating_sum", 0.0) / g if g > 0 else 0.0


func to_dict() -> Dictionary:
	return {
		"id": id, "handle": handle, "real_name": real_name, "nationality": nationality,
		"home_region": home_region, "birth_year": birth_year, "primary_role": primary_role,
		"secondary_roles": secondary_roles, "skills": skills, "ceilings": ceilings,
		"personality": personality, "potential": potential, "development_rate": development_rate,
		"peak_age": peak_age, "decline_rate": decline_rate, "champion_pool": champion_pool,
		"morale": morale, "confidence": confidence, "stress": stress, "fatigue": fatigue,
		"motivation": motivation, "suspended_until": suspended_until, "club_id": club_id,
		"contract": contract.to_dict() if contract else null,
		"squad_status": squad_status, "goals": goals, "happiness": happiness,
		"satisfaction": satisfaction, "trust_in_management": trust_in_management,
		"weeks_unhappy": weeks_unhappy, "transfer_requested": transfer_requested,
		"refuses_renewal": refuses_renewal, "promises": promises, "retired": retired,
		"retired_year": retired_year, "season_stats": season_stats, "career": career,
		"history": history, "reputation": reputation, "loan": loan, "hot": hot,
	}


static func from_dict(d: Dictionary) -> Player:
	var p := Player.new()
	for k in d:
		if k == "contract":
			p.contract = Contract.from_dict(d[k]) if d[k] is Dictionary else null
		elif k in p:
			p.set(k, d[k])
	# JSON 只有 float，修正整數欄位
	p.birth_year = int(p.birth_year)
	p.peak_age = int(p.peak_age)
	p.weeks_unhappy = int(p.weeks_unhappy)
	p.retired_year = int(p.retired_year)
	p.suspended_until = int(p.suspended_until)
	return p
