## 員工：主教練、助理教練、數據分析師、體能/心理教練、球探。所有職位共用同一結構，
## 各職位只看與自己相關的能力值（見 StaffSystem）。
class_name Staff
extends RefCounted

const STYLES := ["aggressive", "macro", "early_game", "scaling", "flexible", "discipline"]
const ROLES := ["head_coach", "assistant_coach", "analyst", "performance_coach", "scout"]

var id: String
var name: String
var role: String = "head_coach"
var club_id: String = ""
var birth_year: int = 1990
var tactical: float = 50.0      ## 戰術設計
var drafting: float = 50.0      ## BP
var development: float = 50.0   ## 選手培養
var man_management: float = 50.0
var adaptability: float = 50.0  ## 臨場/系列賽中的調整
var scouting: float = 40.0     ## 看人眼光（球探）
var fitness: float = 40.0      ## 體能與心理照護
var style: String = "flexible"
var contract_end: int = 0
var salary: int = 60000
var reputation: float = 30.0


static func from_dict(d: Dictionary) -> Staff:
	var s := Staff.new()
	for k in d:
		if k in s:
			s.set(k, d[k])
	s.birth_year = int(s.birth_year)
	s.salary = int(s.salary)
	s.contract_end = int(s.contract_end)
	return s


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "role": role, "club_id": club_id, "birth_year": birth_year,
		"tactical": tactical, "drafting": drafting, "development": development,
		"man_management": man_management, "adaptability": adaptability, "scouting": scouting,
		"fitness": fitness, "style": style, "salary": salary, "reputation": reputation, "contract_end": contract_end}


func age(year: int) -> int:
	return year - birth_year


## 該職位的主要能力（用於排序與介面顯示）
func key_rating() -> float:
	match role:
		"head_coach":
			return (tactical + drafting + development + man_management + adaptability) / 5.0
		"assistant_coach":
			return (tactical + development) / 2.0
		"analyst":
			return (drafting + adaptability) / 2.0
		"performance_coach":
			return (fitness + man_management) / 2.0
		"scout":
			return scouting
	return 40.0
