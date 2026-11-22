## 教練團與員工：聘用、解約、員工市場、能力加成。
##
## 主教練決定基礎能力；專職員工只在「比主教練更強」時提供加成（不會因為沒請人而變弱），
## 因此小俱樂部不請助理也能運作，但有錢的俱樂部可以用人才堆出優勢。
class_name StaffSystem
extends RefCounted

const ROLE_NAMES := {"head_coach": "主教練", "assistant_coach": "助理教練", "analyst": "數據分析師", "performance_coach": "體能心理教練", "scout": "球探"}
## 能力 -> 對應的專職職位
const SPECIALIST := {"tactical": "assistant_coach", "development": "assistant_coach", "drafting": "analyst",
	"adaptability": "analyst", "man_management": "performance_coach", "fitness": "performance_coach", "scouting": "scout"}
const POOL_PER_ROLE := 8


static func get_staff(w: WorldState, club: Club, role: String) -> Staff:
	if club == null:
		return null
	if role == "head_coach":
		return w.staff.get(club.coach_id)
	return w.staff.get(club.staff.get(role, ""))


## 俱樂部在某項能力上的有效值：主教練 + 專職員工超出部分的一半。
static func rating(w: WorldState, club: Club, attr: String) -> float:
	var head: Staff = get_staff(w, club, "head_coach")
	var base = float(head.get(attr)) if head else 40.0
	var spec_role: String = SPECIALIST.get(attr, "")
	if spec_role != "":
		var spec: Staff = get_staff(w, club, spec_role)
		if spec:
			base += maxf(float(spec.get(attr)) - base, 0.0) * 0.5
	return base


static func wage_bill(w: WorldState, club: Club) -> int:
	var total := 0
	for role in Staff.ROLES:
		var s: Staff = get_staff(w, club, role)
		if s:
			total += s.salary
	return total


## 員工的薪資要求：依能力與聲望。
static func wage_demand(s: Staff) -> int:
	var scale = 1.0 if s.role == "head_coach" else 0.35
	return int((30000.0 + maxf(s.key_rating() - 30.0, 0.0) * 3200.0) * scale)


## 員工是否願意加入：聲望差距太大需要加薪。
static func would_join(club: Club, s: Staff, salary: int) -> bool:
	var need = wage_demand(s) * (1.0 + maxf(s.reputation - club.reputation - 10.0, 0.0) * 0.03)
	return salary >= need


static func hire(w: WorldState, club: Club, s: Staff, salary: int, years: int) -> Dictionary:
	if s.club_id != "":
		return {"ok": false, "note": "%s 已有工作" % s.name}
	if not would_join(club, s, salary):
		return {"ok": false, "note": "%s 認為待遇不足（要求約 %d）" % [s.name, wage_demand(s)]}
	var old: Staff = get_staff(w, club, s.role)
	if old:
		dismiss(w, club, s.role)
	s.club_id = club.id
	s.salary = salary
	s.contract_end = w.year + years
	if s.role == "head_coach":
		club.coach_id = s.id
	else:
		club.staff[s.role] = s.id
	w.log.add("staff_hired", w.day, [club.id, s.id], {"role": s.role, "salary": salary}, [])
	return {"ok": true, "note": "%s 加入擔任%s" % [s.name, ROLE_NAMES[s.role]]}


## 解約：支付剩餘合約的一半作為補償。
static func dismiss(w: WorldState, club: Club, role: String) -> int:
	var s: Staff = get_staff(w, club, role)
	if s == null:
		return 0
	var years_left = maxi(s.contract_end - w.year, 0)
	var comp := int(s.salary * years_left * 0.5)
	Finance.spend(club, "staff_severance", comp)
	s.club_id = ""
	if role == "head_coach":
		club.coach_id = ""
	else:
		club.staff.erase(role)
	w.log.add("staff_dismissed", w.day, [club.id, s.id], {"role": role, "compensation": comp}, [])
	return comp


static func free_staff(w: WorldState, role: String = "") -> Array:
	var out: Array = []
	for s in w.staff.values():
		if s.club_id == "" and (role == "" or s.role == role):
			out.append(s)
	out.sort_custom(func(a, b): return a.key_rating() > b.key_rating())
	return out


## 休賽季：員工合約到期、高齡退休、市場補充新人。
static func offseason(w: WorldState) -> void:
	for s in w.staff.values():
		if s.club_id != "" and s.contract_end == 0:
			s.contract_end = w.year + 2  # 資料模組未指定合約年限
		if s.club_id != "" and s.contract_end <= w.year:
			var club: Club = w.clubs.get(s.club_id)
			var keep = club != null and club.is_human  # 玩家的員工自動續約一年，避免無預警流失
			if keep:
				s.contract_end = w.year + 1
			elif club and w.rng.chance(0.55):
				s.contract_end = w.year + w.rng.range_i(1, 3)
			elif club:
				if s.role == "head_coach":
					club.coach_id = ""
				else:
					club.staff.erase(s.role)
				s.club_id = ""
	# 清理過多的閒置員工，並補充市場
	for id in w.staff.keys():
		var s: Staff = w.staff[id]
		if s.club_id == "" and (s.age(w.year) > 62 or w.rng.chance(0.15)):
			w.staff.erase(id)
	replenish(w)


## 員工市場補充到每個職位至少 POOL_PER_ROLE 人。
static func replenish(w: WorldState) -> void:
	for role in Staff.ROLES:
		var have = free_staff(w, role).size()
		for i in maxi(POOL_PER_ROLE - have, 0):
			var q = clampf(w.rng.normal(0.4, 0.22), 0.0, 1.0)
			var s = PlayerGenerator.generate_staff(w, w.rng, q, role)
			s.contract_end = 0
			w.staff[s.id] = s


## AI：補齊空缺職位，依預算與經營哲學選人。
static func ai_fill(w: WorldState, club: Club) -> void:
	var budget_room = int(club.wage_budget * 0.18) - wage_bill(w, club)
	var order = Staff.ROLES.duplicate()
	if club.philosophy == "develop":
		order = ["head_coach", "assistant_coach", "scout", "performance_coach", "analyst"]
	elif club.philosophy == "win_now":
		order = ["head_coach", "analyst", "performance_coach", "assistant_coach", "scout"]
	for role in order:
		if get_staff(w, club, role) != null:
			continue
		for s in free_staff(w, role):
			var salary = int(wage_demand(s) * (1.0 + maxf(s.reputation - club.reputation - 10.0, 0.0) * 0.03) + 1)
			if role != "head_coach" and salary > budget_room:
				continue
			if hire(w, club, s, salary, w.rng.range_i(1, 3))["ok"]:
				budget_room -= salary
				break
		if role == "head_coach" and get_staff(w, club, role) == null:
			var q = clampf((club.reputation - 25.0) / 70.0, 0.05, 1.0)
			var coach = PlayerGenerator.generate_staff(w, w.rng, q, "head_coach")
			coach.contract_end = 0
			w.staff[coach.id] = coach
			hire(w, club, coach, wage_demand(coach), 2)
