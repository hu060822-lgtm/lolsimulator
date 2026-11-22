## 球探與資訊不確定性（GDD 3.2）：玩家看到的是「估計區間」，不是真實值。
## 了解程度（0..1）隨同聯賽觀察、交手、球探工作而提升；估計中心本身也可能有偏差。
class_name Scouting
extends RefCounted


static func knowledge(w: WorldState, p: Player) -> float:
	if p.club_id != "" and p.club_id == w.human_club_id:
		return 1.0
	var c: Club = w.human_club()
	if c == null:
		return 1.0
	return float(c.scout_knowledge.get(p.id, base_knowledge(w, c, p)))


static func base_knowledge(w: WorldState, c: Club, p: Player) -> float:
	var k = 0.1 + p.reputation / 250.0
	if p.club_id != "" and w.clubs.has(p.club_id) and w.clubs[p.club_id].league_id == c.league_id:
		k += 0.15
	return clampf(k, 0.05, 0.6)


## 回傳 [low, high]。偏差由選手與能力決定（固定），了解越多偏差越小。
static func range_of(w: WorldState, p: Player, skill: String) -> Array:
	var k = knowledge(w, p)
	var v = p.skill(skill)
	if k >= 0.999:
		return [int(v), int(v)]
	var bias = (float(hash(p.id + skill) % 1000) / 1000.0 - 0.5) * 2.0  # -1..1
	var center = v + bias * (1.0 - k) * 9.0
	var half = (1.0 - k) * 14.0 + 1.0
	return [int(clampf(center - half, 1, 99)), int(clampf(center + half, 1, 99))]


## 每週：同聯賽選手緩慢累積了解；交手對象在 MatchEffects 中另外提升。
static func weekly(w: WorldState) -> void:
	var c: Club = w.human_club()
	if c == null:
		return
	var scouts_bonus := 0.0
	var coach: Staff = w.staff.get(c.coach_id)
	if coach:
		scouts_bonus = coach.tactical / 100.0 * 0.01
	for p in w.active_players():
		if p.club_id == c.id:
			continue
		var k := float(c.scout_knowledge.get(p.id, base_knowledge(w, c, p)))
		var same_league = p.club_id != "" and w.clubs[p.club_id].league_id == c.league_id
		k += (0.012 if same_league else 0.003) + scouts_bonus
		c.scout_knowledge[p.id] = minf(k, 0.95)


## 交手或指派球探：大幅提升對某名選手的了解。
static func observe(w: WorldState, player_id: String, amount: float) -> void:
	var c: Club = w.human_club()
	if c == null or not w.players.has(player_id):
		return
	var p: Player = w.players[player_id]
	var k := float(c.scout_knowledge.get(player_id, base_knowledge(w, c, p)))
	c.scout_knowledge[player_id] = minf(k + amount, 0.95)
