## 選手成長與衰退（每週）。
## - 每項能力朝隱藏上限成長，速度受年齡、成長速度、訓練重點、教練、職業態度、士氣影響。
## - 操作型能力較早衰退；理解型能力巔峰較晚（GDD：老將以經驗與決策維持水準）。
## - 版本變動會讓選手調整英雄池。
class_name Development
extends RefCounted


static func weekly(w: WorldState, p: Player, focus: Dictionary, coach: Staff) -> void:
	var a = p.age(w.year)
	var dev_rating = coach.development if coach else 40.0
	if p.club_id != "" and w.clubs.has(p.club_id):
		dev_rating = StaffSystem.rating(w, w.clubs[p.club_id], "development")
	var coach_f = 0.7 + dev_rating / 100.0 * 0.6
	var pro_f = 0.6 + p.trait_value("professionalism") / 100.0 * 0.6
	var morale_f = 0.8 + p.morale / 250.0
	for s in Attr.SKILLS:
		var v = p.skill(s)
		var ceil_v := float(p.ceilings.get(s, 70.0))
		var peak = p.peak_age + (3 if s in Attr.COGNITIVE else 0)
		if a <= peak:
			var room = maxf(ceil_v - v, 0.0) / maxf(ceil_v - 20.0, 1.0)
			var age_f = clampf(1.0 + (peak - a) * 0.08, 0.6, 1.6)
			var g = Tuning.f("growth_base_per_week") * p.development_rate * float(focus.get(s, 0.5)) * coach_f * pro_f * morale_f * age_f * room * 3.0
			p.skills[s] = minf(v + g, ceil_v)
		elif a > peak + 1:
			var mech_f = 1.3 if s in Attr.MECHANICAL else 0.45
			var d = Tuning.f("decline_base_per_week") * p.decline_rate * (a - peak - 1) / 3.0 * mech_f * (1.15 - p.trait_value("professionalism") / 200.0)
			p.skills[s] = maxf(v - d, 10.0)
	# 英雄池：未練習的英雄熟練度緩慢下降
	for cid in p.champion_pool.keys():
		p.champion_pool[cid] = maxf(p.mastery(cid) - Tuning.f("mastery_decay_per_week") * 0.5, 10.0)


## 新版本：適應力高的選手會主動學習版本強勢英雄。
static func adapt_to_patch(w: WorldState, p: Player, rng: SimRng) -> void:
	for c in w.champions.values():
		if p.primary_role in c.roles and w.patch.meta(c.id) >= 2.0 and not p.champion_pool.has(c.id):
			if rng.chance(p.skill("adaptability") / 100.0 * 0.6):
				p.champion_pool[c.id] = 35.0 + p.skill("adaptability") * 0.3
