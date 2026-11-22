## 員工（第一階段只實作主教練；其餘職位在第二階段沿用同一結構）。
class_name Staff
extends RefCounted

const STYLES := ["aggressive", "macro", "early_game", "scaling", "flexible", "discipline"]

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
var style: String = "flexible"
var salary: int = 60000
var reputation: float = 30.0


static func from_dict(d: Dictionary) -> Staff:
	var s := Staff.new()
	for k in d:
		if k in s:
			s.set(k, d[k])
	s.birth_year = int(s.birth_year)
	s.salary = int(s.salary)
	return s


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "role": role, "club_id": club_id, "birth_year": birth_year,
		"tactical": tactical, "drafting": drafting, "development": development,
		"man_management": man_management, "adaptability": adaptability, "style": style,
		"salary": salary, "reputation": reputation}
