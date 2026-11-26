## 每週訓練：決定能力成長方向、英雄熟練度、疲勞、默契與 BP 熟悉度。
## 計畫以「每週 12 個時段」分配到各訓練類型。
class_name TrainingEngine
extends RefCounted

const SLOTS := 12
const TYPES := {
	"solo_queue": {"skills": ["mechanics", "laning"], "load": 1.0},
	"champion_practice": {"skills": [], "load": 0.9},
	"scrims": {"skills": ["teamfighting", "shotcalling", "positioning"], "load": 1.2},
	"tactical_review": {"skills": ["decision_making", "wave_management", "resource_trading"], "load": 0.6},
	"vod_review": {"skills": ["map_awareness", "vision", "adaptability"], "load": 0.5},
	"draft_practice": {"skills": ["draft_iq"], "load": 0.4},
	"meta_study": {"skills": ["adaptability"], "load": 0.4},
	"team_building": {"skills": [], "load": 0.3},
	"mental_coaching": {"skills": ["consistency", "clutch"], "load": 0.2},
	"physical": {"skills": [], "load": 0.4},
	"rest": {"skills": [], "load": 0.0},
}


static func default_plan() -> Dictionary:
	return {"solo_queue": 2, "champion_practice": 2, "scrims": 3, "tactical_review": 1, "vod_review": 1, "draft_practice": 1, "team_building": 0, "mental_coaching": 0, "physical": 0, "rest": 2}


static func validate(plan: Dictionary) -> bool:
	var total := 0
	for k in plan:
		if not TYPES.has(k):
			return false
		total += int(plan[k])
	return total <= SLOTS


## 回傳 player_id -> {skill: 成長倍率}，並直接套用疲勞、心理、默契效果。
static func weekly(w: WorldState, club: Club) -> Dictionary:
	var plan: Dictionary = club.training_plan if not club.training_plan.is_empty() else default_plan()
	var drafting = StaffSystem.rating(w, club, "drafting")
	var fitness = StaffSystem.rating(w, club, "fitness")
	var load := 0.0
	for k in plan:
		load += TYPES[k]["load"] * int(plan[k])
	var rest := int(plan.get("rest", 0)) + int(plan.get("physical", 0)) * 0.5
	var focus_all := {}
	for pid in club.roster:
		var p: Player = w.players[pid]
		# 疲勞：負荷 - 恢復；職業態度高者自我管理較好
		p.fatigue = clampf(p.fatigue + load * 1.1 - rest * 4.0 - 5.0 - maxf(fitness - 40.0, 0.0) / 30.0, 0.0, 100.0)
		var eff := 1.0
		if p.fatigue > 70.0:
			eff = 0.5
			p.stress = clampf(p.stress + 3.0, 0.0, 100.0)
			p.morale = clampf(p.morale - 2.0, 0.0, 100.0)
		p.stress = clampf(p.stress - int(plan.get("mental_coaching", 0)) * 2.5 - int(plan.get("rest", 0)) * 0.8 - 1.0 - maxf(fitness - 40.0, 0.0) / 40.0, 0.0, 100.0)
		p.confidence = lerpf(p.confidence, 60.0, 0.03)
		p.morale = clampf(p.morale + int(plan.get("team_building", 0)) * 1.0, 0.0, 100.0)
		var focus := {}
		for s in Attr.SKILLS:
			focus[s] = 0.5
		for k in plan:
			for s in TYPES[k]["skills"]:
				focus[s] += 0.35 * int(plan[k])
		for s in focus:
			focus[s] *= eff
		focus_all[pid] = focus
		# 英雄練習：提升前幾名英雄熟練度
		var cp := int(plan.get("champion_practice", 0))
		if cp > 0:
			for cid in p.top_champions(4):
				p.champion_pool[cid] = minf(p.mastery(cid) + 0.35 * cp * eff, 100.0)
	club.chemistry = clampf(club.chemistry + int(plan.get("scrims", 0)) * 0.25 + int(plan.get("team_building", 0)) * 0.6 - 0.6, 0.0, 100.0)
	club.draft_familiarity = clampf(club.draft_familiarity + int(plan.get("draft_practice", 0)) * 0.5 * (drafting / 60.0) - 0.4, 0.0, 100.0)
	return focus_all
