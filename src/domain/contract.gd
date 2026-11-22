## 合約（第一階段：基本條款）。
class_name Contract
extends RefCounted

var club_id: String = ""
var salary: int = 0          ## 年薪
var start_year: int = 0
var end_year: int = 0        ## 合約在該年度賽季結束後到期
var role_promise: String = "rotation"  ## starter / rotation / backup / prospect
var signing_bonus: int = 0
var release_clause: int = 0  ## 0 = 無
var win_bonus: int = 0


static func from_dict(d: Dictionary) -> Contract:
	var c := Contract.new()
	c.club_id = d.get("club_id", "")
	c.salary = int(d.get("salary", 0))
	c.start_year = int(d.get("start_year", 0))
	c.end_year = int(d.get("end_year", 0))
	c.role_promise = d.get("role_promise", "rotation")
	c.signing_bonus = int(d.get("signing_bonus", 0))
	c.release_clause = int(d.get("release_clause", 0))
	c.win_bonus = int(d.get("win_bonus", 0))
	return c


func to_dict() -> Dictionary:
	return {"club_id": club_id, "salary": salary, "start_year": start_year, "end_year": end_year,
		"role_promise": role_promise, "signing_bonus": signing_bonus,
		"release_clause": release_clause, "win_bonus": win_bonus}


func years_left(current_year: int) -> int:
	return maxi(end_year - current_year, 0)
